variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "routing_mode" {
  description = "VPC routing mode"
  type        = string
  default     = "REGIONAL"
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "subnet_name" {
  description = "Private subnet name"
  type        = string
}

variable "subnet_cidr" {
  description = "Private subnet CIDR range"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
  default     = "k8s-pods"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
  default     = "k8s-services"
}

variable "services_cidr" {
  description = "Secondary CIDR range for services"
  type        = string
}

variable "router_name" {
  description = "Cloud router name"
  type        = string
}

variable "nat_name" {
  description = "Cloud NAT name"
  type        = string
}

variable "nat_ip_name" {
  description = "Cloud NAT external IP name"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}