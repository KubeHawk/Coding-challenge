variable "gcp_credentials" {
  description = "GCP service account credentials JSON"
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "crewmeister-496312"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west1-b"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "crewmeister-cluster"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "crewmeister"
}

variable "machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-small"
}

variable "node_count" {
  description = "Number of GKE nodes"
  type        = number
  default     = 1
}

variable "app_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "db_password" {
  description = "Cloud SQL MySQL password"
  type        = string
  sensitive   = true
}
