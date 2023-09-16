# Enable Cloud Resource Manager API for the project
resource "google_project_service" "cloud_resource_manager" {
  service = "cloudresourcemanager.googleapis.com"
}

# Enable Compute Engine API for the project. Also, use a local exec provisioner to remove default firewall rules.
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute firewall-rules list --format 'value(name)' --project=${var.project_id} | xargs gcloud compute firewall-rules delete -q
    EOT
  }
  # Ensure Cloud Resource Manager is enabled before proceeding
  depends_on = [google_project_service.cloud_resource_manager]
}

# Create a custom VPC without default subnets
resource "google_compute_network" "main" {
  name                    = "vpc"
  auto_create_subnetworks = false

  # Ensure the Compute API is enabled before creating the VPC
  depends_on = [google_project_service.compute]
}

# Create a custom subnet within the above VPC
resource "google_compute_subnetwork" "main" {
  region        = "us-east1"
  ip_cidr_range = "10.0.0.0/16"
  name          = "subnet"
  network       = google_compute_network.main.self_link

  # Configure advanced VPC Flow Logs with a 5-second aggregation interval
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Setup a router within the VPC for Cloud NAT
resource "google_compute_router" "router" {
  name    = "cloud-router"
  region  = "us-east1"
  network = google_compute_network.main.name
}

# Define the Cloud NAT configuration for outbound connectivity
resource "google_compute_router_nat" "nat" {
  name                               = "cloud-nat"
  region                             = "us-east1"
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall rule to allow internal traffic within the VPC
resource "google_compute_firewall" "allow_internal" {
  name          = "allow-internal"
  network       = google_compute_network.main.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/16"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }
}

# Firewall rule to allow SSH access via Identity-Aware Proxy (IAP)
resource "google_compute_firewall" "allow_iap" {
  name          = "allow-iap"
  network       = google_compute_network.main.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Create a shared SSD with multi-writer enabled
resource "google_compute_disk" "shared" {
  provider     = google-beta
  name         = "shared"
  type         = "pd-ssd"
  zone         = "us-east1-d"
  size         = 10
  multi_writer = true

  # Ensure the Compute API is enabled before creating the disk  
  depends_on = [google_project_service.compute]
}

# Define the first Compute Instance "nas-1" with the shared disk attached
resource "google_compute_instance" "nas-1" {
  machine_type = "n2-standard-2"
  name         = "nas-1"
  zone         = "us-east1-d"
  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20230908"
      size  = 10
      type  = "pd-balanced"
    }
  }
  attached_disk {
    source = google_compute_disk.shared.self_link
  }
  network_interface {
    subnetwork = google_compute_subnetwork.main.self_link
  }
}

# Define the second Compute Instance "nas-2" with the shared disk attached
resource "google_compute_instance" "nas-2" {
  machine_type = "n2-standard-2"
  name         = "nas-2"
  zone         = "us-east1-d"
  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20230908"
      size  = 10
      type  = "pd-balanced"
    }
  }
  attached_disk {
    source = google_compute_disk.shared.self_link
  }
  network_interface {
    subnetwork = google_compute_subnetwork.main.self_link
  }
  # Ensure "nas-1" instance is created before creating "nas-2"
  depends_on = [google_compute_instance.nas-1]
}
