variable "project_id" {
  type        = string
  description = "Project ID to deploy resources to"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "docai_processor_id" {
  type = string
}

variable "provider_project" {
  type = string
}

variable "terraform_service_account" {
  type = string
}
