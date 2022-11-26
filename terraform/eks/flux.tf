terraform {
  required_version = ">= 0.13"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    flux = {
      source  = "fluxcd/flux"
    }

  }
}

provider "flux" {}

provider "kubectl" {}

provider "github" {
  owner = var.github_owner
  token = var.flux_token
}

# Data
data "flux_install" "main" {
  target_path = var.target_path
}

data "aws_caller_identity" "current" {}

data "flux_sync" "main" {
  target_path = var.target_path
  url         = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
  branch      = var.branch
}

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}


# Kubernetes
locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  envs = ["dev", "homol", "prod"]
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

resource "tls_private_key" "main" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

resource "kubernetes_namespace" "envs" {
  for_each = toset(local.envs)
  metadata {
    name = each.key
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

resource "kubectl_manifest" "install" {
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}


# Github

resource "github_repository_deploy_key" "main" {
  title      = "flux-deploy-key"
  repository = var.repository_name
  key        = tls_private_key.main.public_key_openssh
  read_only  = false
}

resource "github_repository_file" "install" {
  repository = var.repository_name
  file       = "${var.target_path}gotk-components.yaml"
  content    = data.flux_install.main.content
  branch     = var.branch
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      file,content
    ]
  }
}

resource "github_repository_file" "sync" {
  repository = var.repository_name
  file       = "${var.target_path}gotk-sync.yaml"
  content    = data.flux_sync.main.content
  branch     = var.branch
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      file,content
    ]
  }
}

resource "github_repository_file" "kustomize" {
  repository = var.repository_name
  file       = "${var.target_path}kustomization.yaml"
  content    = data.flux_sync.main.kustomize_content
  branch     = var.branch
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      file,content
    ]
  }
}
