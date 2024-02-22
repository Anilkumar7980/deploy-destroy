
#depends_on = [google_project_service.service_networking]: This line specifies a dependency for a Terraform resource. 
#It means that the current resource should only be created after the specified dependency, 
#in this case, google_project_service.service_networking, has been created. 
#Dependencies are used to ensure resources are created in the correct order.

#lifecycle { create_before_destroy = true }: This block defines a lifecycle rule for a resource, 
#specifically the create_before_destroy policy. 
#When set to true, Terraform will first create a new instance of a resource before destroying the old version during updates. 
#This is useful for minimizing downtime during infrastructure changes and ensuring that a new resource is successfully created before removing the old one.
  
  




resource "google_compute_router" "nat_router" {
  project = var.project_id
  name    = "nat-router"
  region  = var.region
  network = google_compute_network.vpc.name
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.5.0.0/20", "10.5.16.0/20"]
}



resource "google_project_service" "logging" {
  service = "logging.googleapis.com"
  project = var.project_id
  disable_dependent_services = true

  disable_on_destroy = true
}

resource "google_project_service" "monitoring" {
  service                    = "monitoring.googleapis.com"
  project                    = var.project_id
  disable_dependent_services = true
}



resource "google_project_iam_binding" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"

  members = [
    "serviceAccount:pre-sales@project-7989.iam.gserviceaccount.com",
  ]
}


resource "google_project_iam_binding" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"


  members = [
    "serviceAccount:pre-sales@project-7989.iam.gserviceaccount.com",
  ]
}


#vpc


resource "google_compute_network" "vpc" {
  name                    = "banking-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet"
  project       = var.project_id
  ip_cidr_range = "10.5.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.name
}

resource "google_compute_subnetwork" "public_subnet" {
  project       = var.project_id
  name          = "public-subnet"
  ip_cidr_range = "10.5.16.0/20"
  region        = var.region
  network       = google_compute_network.vpc.name
}


provider "google" {
  project = "project-7989"
  region  = "asia-south2"
}

resource "google_project_service" "kubernetes" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}




resource "google_container_cluster" "private_cluster" {
  name               = "private-cluster1"
  location           = "asia-south2"
  network            = google_compute_network.vpc.name
  subnetwork         = google_compute_subnetwork.gke_subnet.name
  deletion_protection = false
  initial_node_count = 1
  release_channel {
    channel = "REGULAR"
  }
  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  ip_allocation_policy {}
    
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" # For demonstration; adjust according to your security policies
      display_name = "Open to the world"
    }
  }
  node_config {
    preemptible  = false
    machine_type = "e2-medium"
    disk_size_gb = 25
    disk_type    = "pd-ssd"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]
    image_type = "COS_CONTAINERD"
    tags       = ["gke-cluster", "private"]
  }
   
  vertical_pod_autoscaling {
    enabled = true
  }
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  network_policy {
    enabled  = true
    provider = "CALICO"
  }
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    dns_cache_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }
}

# Note: Adjust the secondary IP range names according to your VPC and subnet setup.











resource "google_compute_instance" "jump_box" {
  project             = var.project_id
  name                = "jump-box"
  machine_type        = "e2-micro"
  zone                = "${var.region}-a"
  deletion_protection = false

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      size  = 50
    }
  }

  network_interface {
    network            = google_compute_network.vpc.name
    subnetwork         = google_compute_subnetwork.public_subnet.name
    subnetwork_project = var.project_id
  }

  tags = ["jump-box"]
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    windows-startup-script-ps1 = <<EOF
# PowerShell script to download kubectl and add it to the system PATH

# Create directory for kubectl
$kubectlDir = "C:\\kubectl"
New-Item -ItemType Directory -Force -Path $kubectlDir

# Download kubectl.exe
Invoke-WebRequest -Uri "https://storage.googleapis.com/kubernetes-release/release/v1.20.0/bin/windows/amd64/kubectl.exe" -OutFile "$kubectlDir\\kubectl.exe"

# Add the kubectl directory to the system PATH
$oldPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
if (-not $oldPath.Contains($kubectlDir)) {
    $newPath = $oldPath + ";" + $kubectlDir
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, [System.EnvironmentVariableTarget]::Machine)
}

# Refresh the environment variables for this session
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
EOF
  }
}

#


resource "google_compute_firewall" "allow_iap_to_jump_box" {
  project = var.project_id
  name    = "allow-iap-to-jump-box"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"] # Corrected spacing for consistency
  }

  target_tags = ["jump-box"]
  source_ranges = ["35.235.240.0/20"] # IP range for IAP
}



resource "google_project_service" "service_networking" {
  service = "servicenetworking.googleapis.com"
  project = var.project_id
}

resource "google_compute_global_address" "private_services_range" {
  name          = "private-services-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.self_link
  project       = var.project_id
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_service_networking_connection" "private_vpc_connection" {

  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services_range.name]
  depends_on = [google_project_service.service_networking]
  lifecycle {
    create_before_destroy = true
  }
}





resource "google_sql_database_instance" "postgres_instance" {
  name             = "postgres-instance"
  project          = var.project_id
  region           = "asia-south2"
  database_version = "POSTGRES_15"
  deletion_protection = false

  settings {
    tier            = "db-custom-8-32768"
    availability_type = "REGIONAL"
    disk_size       = 20
    disk_type       = "PD_SSD"
    
    ip_configuration {
      ipv4_enabled = false
      private_network = google_compute_network.vpc.id
    }
    backup_configuration {
      enabled            = true
      start_time         = "12:00"
      point_in_time_recovery_enabled = true
    }
    database_flags {
      name  = "max_connections"
      value = "100"
    }
    location_preference {
      zone = "${var.region}-a"
    }
  }
  
  depends_on = [google_service_networking_connection.private_vpc_connection]

}