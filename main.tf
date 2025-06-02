terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.8.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "argocd" {
  server_addr = "127.0.0.1:38417"
  username    = "admin"
  password    = "rtArDhpp2upL-JqD"
  insecure    = true
}

# 1. MetalLB 설치
resource "helm_release" "metallb" {
  name             = "metallb"
  chart            = "metallb/metallb"
  namespace        = "mymetallb"
  create_namespace = true
}

# 2. IPAddressPool 설정
resource "kubernetes_manifest" "ipaddresspool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "my-metallb-config"
      namespace = "mymetallb"
    }
    spec = {
      addresses = ["10.0.2.20-10.0.2.40"]
    }
  }

  depends_on = [helm_release.metallb]
}

# 3. L2Advertisement 설정
resource "kubernetes_manifest" "l2advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "my-metallb-config"
      namespace = "mymetallb"
    }
    spec = {
      ipAddressPools = ["my-metallb-config"]
    }
  }

  depends_on = [helm_release.metallb]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  chart            = "argo/argo-cd"
  namespace        = "myargocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}

resource "argocd_application" "myapp" {
  metadata {
    name = "nginx-test"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://github.com/Ch-iron/argocd-practice.git"
      path            = "."
      target_revision = "master"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "nginx-argocd-test"
    }

    sync_policy {
      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }
  depends_on = [helm_release.argocd, kubernetes_manifest.ipaddresspool, kubernetes_manifest.l2advertisement]
}


