terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>4.82"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~>4.82"
    }
  }
}

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}
