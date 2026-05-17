variable "namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "58.2.2"
}

variable "elasticsearch_version" {
  description = "Elasticsearch Helm chart version"
  type        = string
  default     = "8.5.1"
}

variable "kibana_version" {
  description = "Kibana Helm chart version"
  type        = string
  default     = "8.5.1"
}

variable "logstash_version" {
  description = "Logstash Helm chart version"
  type        = string
  default     = "8.5.1"
}

variable "prometheus_stack_values_file" {
  description = "Path to kube-prometheus-stack Helm values file"
  type        = string
}

variable "elasticsearch_values_file" {
  description = "Path to Elasticsearch Helm values file"
  type        = string
}

variable "kibana_values_file" {
  description = "Path to Kibana Helm values file"
  type        = string
}

variable "logstash_values_file" {
  description = "Path to Logstash Helm values file"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "prometheus_timeout" {
  description = "Timeout for kube-prometheus-stack deployment in seconds"
  type        = number
  default     = 600
}

variable "elasticsearch_timeout" {
  description = "Timeout for Elasticsearch deployment in seconds"
  type        = number
  default     = 600
}

variable "kibana_timeout" {
  description = "Timeout for Kibana deployment in seconds"
  type        = number
  default     = 300
}

variable "logstash_timeout" {
  description = "Timeout for Logstash deployment in seconds"
  type        = number
  default     = 300
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}