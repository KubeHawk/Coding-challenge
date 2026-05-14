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
  default     = "crewmeister"
}

variable "machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "node_count" {
  description = "Number of GKE nodes"
  type        = number
  default     = 1
}

variable "db_password" {
  description = "Cloud SQL MySQL password"
  type        = string
  sensitive   = true
}