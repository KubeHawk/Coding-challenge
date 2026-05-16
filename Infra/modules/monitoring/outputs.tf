output "namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_release_name" {
  description = "Prometheus Helm release name"
  value       = helm_release.kube_prometheus_stack.name
}

output "elasticsearch_release_name" {
  description = "Elasticsearch Helm release name"
  value       = helm_release.elasticsearch.name
}

output "logstash_release_name" {
  description = "Logstash Helm release name"
  value       = helm_release.logstash.name
}

output "kibana_release_name" {
  description = "Kibana Helm release name"
  value       = helm_release.kibana.name
}

output "chart_versions" {
  description = "Deployed chart versions"
  value       = local.chart_versions
}