variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "crewmeister"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "crewmeister"
}

variable "app_image_repo" {
  description = "Docker image name for the Spring Boot app"
  type        = string
  default     = "crewmeister-app"
}

variable "app_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
