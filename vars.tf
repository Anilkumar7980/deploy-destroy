variable "credentials" {
  description = "The path to the credentials file"
}

variable "project_id" {
  description = "The project ID"
}





variable "service_account" {
  description = "The service account to be used by the node VMs"
  default     = "pre-sales@project-7989.iam.gserviceaccount.com"
}
variable "name" {
  description = "The name of the cluster"
  default     = "simple-zonal-private-poc-dev"
}

variable "region" {
  description = "The region to host the vpc,cluste and db"
  
  default     = "asia-south2"
}

variable "initial_node_count" {
  description = "The initial node count for the cluster"
  default     = 1
}

