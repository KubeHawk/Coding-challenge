locals {
  chart_versions = {
    kube_prometheus_stack = var.prometheus_stack_version
    elasticsearch         = var.elasticsearch_version
    kibana                = var.kibana_version
    logstash              = var.logstash_version
  }
}

# ─── Monitoring Namespace ─────────────────────────────────────────────────────
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name   = var.namespace
    labels = var.labels
  }
}

# ─── Prometheus + Grafana ─────────────────────────────────────────────────────
resource "helm_release" "kube_prometheus_stack" {
  depends_on = [kubernetes_namespace.monitoring]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = var.namespace
  version    = local.chart_versions.kube_prometheus_stack
  timeout    = var.prometheus_timeout
  atomic     = true
  wait       = true

  values = [file(var.prometheus_stack_values_file)]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}

# ─── Elasticsearch ────────────────────────────────────────────────────────────
resource "helm_release" "elasticsearch" {
  depends_on = [kubernetes_namespace.monitoring]

  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  namespace  = var.namespace
  version    = local.chart_versions.elasticsearch
  timeout    = var.elasticsearch_timeout
  atomic     = true
  wait       = true

  values = [file(var.elasticsearch_values_file)]
}

# ─── Logstash ─────────────────────────────────────────────────────────────────
resource "helm_release" "logstash" {
  depends_on = [helm_release.elasticsearch]

  name       = "logstash"
  repository = "https://helm.elastic.co"
  chart      = "logstash"
  namespace  = var.namespace
  version    = local.chart_versions.logstash
  timeout    = var.logstash_timeout
  atomic     = true
  wait       = true

  values = [file(var.logstash_values_file)]
}

# ─── Kibana ───────────────────────────────────────────────────────────────────
resource "helm_release" "kibana" {
  depends_on = [helm_release.elasticsearch]

  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  namespace  = var.namespace
  version    = local.chart_versions.kibana
  timeout    = var.kibana_timeout
  atomic     = true
  wait       = true
  cleanup_on_fail = true

  values = [file(var.kibana_values_file)]
}