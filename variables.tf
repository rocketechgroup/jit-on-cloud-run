variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west2"
}

variable "domain" {
  type = string
}

variable "lb_name" {
  type = string
}

variable "iap_client_id" {
  type = string
}

variable "iap_client_secret" {
  type = string
}

variable "vpc_name" {
  type    = string
  default = "jitaccess-vpc"
}

variable "subnet_name" {
  type    = string
  default = "jitaccess-subnet"
}

variable "iap_members" {
  type = string
  # If you have multiple, split with commas
  # "group:everyone@google.com", // a google group
  # "allAuthenticatedUsers"          // anyone with a Google account (not recommended)
  # "user:ahmetalpbalkan@gmail.com", // a particular user
}

variable "scope_type" {
  type    = string
  default = "project" # this can be "projects", "folders", "organizations" depends on what you would like to manage
}
variable "scope_id" {
  type = string
  # this is the project, folder or org ID you would like to manage, keep in mind this is usually not the project where JIT is deployed
}

variable "artifact_repo" {
  type = string
}

variable "iap_backend_service_id" {
  # this is a bit of a tricky one, you can only get this after the backend service is created. So this needs to be updated after the initial Terraform ran.
  # you can get this by doing "gcloud compute backend-services describe jit-sandbox-lb-backend-default --global --format 'value(id)'"
  type = string
  default = ""
}
