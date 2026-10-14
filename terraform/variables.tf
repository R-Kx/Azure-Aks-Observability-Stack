variable "prefix" {
  type        = string
  description = "name prefix"
}

variable "environment" {
  type        = string
  description = "env for resources"
}

variable "location" {
  type        = string
  description = "region for resources"
}

variable "win_admin_username" {
  type        = string
  description = "adm user for aks win pool"
}

variable "win_admin_password" {
  type        = string
  sensitive   = true
  description = "adm pass for aks win pool"
}

variable "admin_email" {
  type        = string
  description = "admin email for ag"
}

variable "prometheus_datasource_uid" {
  type        = string
  description = "grafana prometheus datasource uid"
}

variable "principal_id" {
  type        = string
  description = "id of principal"
}