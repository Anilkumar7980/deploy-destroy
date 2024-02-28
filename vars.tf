variable "credentials" {
  description = "The path to the credentials file"
}

variable "project_id" {
  description = "The project ID"
}



variable "github_actions_ip_ranges" {
  description = "A map of GitHub Actions IP ranges to allowlist"
  type        = map(string)
  default     = {
    "actions1" = "192.0.2.0/24",
    "actions2" = "198.51.100.0/24",
    "actions3" = "203.0.113.0/24",
  }
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

