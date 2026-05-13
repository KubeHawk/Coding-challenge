terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ─── Kind Cluster ─────────────────────────────────────────────────────────────
resource "kind_cluster" "crewmeister" {
  name            = var.cluster_name
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Map host port 30080 → NodePort 30080 inside the cluster
      extra_port_mappings {
        container_port = 30080
        host_port      = 30080
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
    }
  }
}

# ─── Providers wired to the new cluster ───────────────────────────────────────
provider "kubernetes" {
  host                   = kind_cluster.crewmeister.endpoint
  cluster_ca_certificate = base64decode(kind_cluster.crewmeister.cluster_ca_certificate)
  client_certificate     = base64decode(kind_cluster.crewmeister.client_certificate)
  client_key             = base64decode(kind_cluster.crewmeister.client_key)
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.crewmeister.endpoint
    cluster_ca_certificate = base64decode(kind_cluster.crewmeister.cluster_ca_certificate)
    client_certificate     = base64decode(kind_cluster.crewmeister.client_certificate)
    client_key             = base64decode(kind_cluster.crewmeister.client_key)
  }
}

# ─── Load local Docker image into kind ────────────────────────────────────────
# kind clusters can't pull local images directly — this loads it in
resource "null_resource" "load_image" {
  depends_on = [kind_cluster.crewmeister]

  triggers = {
    image_tag    = var.app_image_tag
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = "kind load docker-image ${var.app_image_repo}:${var.app_image_tag} --name ${var.cluster_name}"
  }
}

# ─── Namespace ────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "crewmeister" {
  depends_on = [kind_cluster.crewmeister]

  metadata {
    name = var.namespace
  }
}

# ─── Helm Release ─────────────────────────────────────────────────────────────
resource "helm_release" "crewmeister" {
  depends_on = [
    kubernetes_namespace.crewmeister,
    null_resource.load_image,
  ]

  name       = "crewmeister"
  chart      = "${path.module}/../helm/crewmeister"
  namespace  = var.namespace
  timeout    = 300
  atomic     = true   # rolls back automatically on failure
  wait       = true

  set {
    name  = "image.repository"
    value = var.app_image_repo
  }

  set {
    name  = "image.tag"
    value = var.app_image_tag
  }

  set {
    name  = "image.pullPolicy"
    value = "Never"   # image is already loaded into kind, never pull
  }
}
