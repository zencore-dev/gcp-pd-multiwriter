resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute firewall-rules list --format 'value(name)' --project=${var.project_id} | xargs gcloud compute firewall-rules delete -q
      gcloud -q compute networks delete default --project=${var.project_id}
    EOT
  }
}

resource "google_compute_network" "main" {
  name                            = "vpc"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
  depends_on                      = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  ip_cidr_range = "10.0.0.0/16"
  name          = "subnet"
  network       = google_compute_network.main.self_link
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_disk" "shared" {
  provider     = google-beta
  name         = "shared"
  type         = "pd-ssd"
  zone         = "us-east1-d"
  size         = 10
  multi_writer = true
}

resource "google_compute_instance" "nas-1" {
  machine_type = "e2-micro"
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

resource "google_compute_instance" "nas-2" {
  machine_type = "e2-micro"
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
}

