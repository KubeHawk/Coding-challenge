variable "location" {
  description = "Artifact Registry location"
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID"
  type        = string
}

variable "description" {
  description = "Artifact Registry description"
  type        = string
  default     = ""
}

variable "format" {
  description = "Artifact Registry format"
  type        = string
  default     = "DOCKER"
}

variable "labels" {
  description = "Labels to apply to the repository"
  type        = map(string)
  default     = {}
}

variable "mode" {
  description = "Artifact Registry mode"
  type        = string
  default     = "STANDARD_REPOSITORY"
}

variable "project" {
  description = "GCP project ID"
  type        = string
}