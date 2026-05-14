variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "db_password" {
  description = "Cloud SQL MySQL password"
  type        = string
  sensitive   = true
}