variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "network" {
  description = "VPC network name"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork name"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
}

variable "master_cidr" {
  description = "Master node CIDR block"
  type        = string
  default     = "192.168.0.0/28"
}

variable "enable_private_endpoint" {
  description = "Whether the cluster master endpoint is private"
  type        = bool
  default     = false
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

variable "node_pool_name" {
  description = "Node pool name"
  type        = string
}

variable "machine_type" {
  description = "GKE node machine type"
  type        = string
}

variable "node_count" {
  description = "Number of GKE nodes"
  type        = number
}

variable "disk_size_gb" {
  description = "Node disk size in GB"
  type        = number
  default     = 20
}

variable "disk_type" {
  description = "Node disk type"
  type        = string
  default     = "pd-standard"
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}