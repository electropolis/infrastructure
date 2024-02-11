# Define provider configuration
provider "google" {
  project     = "sandbox-sonic"
  region  = "us-central1"
  zone    = "us-central1-c"
}

# Define VPC network
resource "google_compute_network" "vpc_network" {
  name = "custom-vpc"
  auto_create_subnetworks = false
}

# Define custom subnet within the VPC network
resource "google_compute_subnetwork" "custom_subnet" {
  name          = "custom-vpc-subnet"
  ip_cidr_range = "10.0.50.0/24"
  network       = google_compute_network.vpc_network.name
}

# Define firewall rule to allow SSH access
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "6443", "80", "443", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Define external IP address
resource "google_compute_address" "external_ip" {
  name   = "k3s-external-ip"
}

# Define VM instance
resource "google_compute_instance" "vm_instance" {
  name         = "k3s-vm"
  machine_type = "e2-medium"
  network_interface {
    network = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.custom_subnet.name
    access_config {
      nat_ip = google_compute_address.external_ip.address
    }
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  metadata = {
    ssh-keys = "konrad:${file("~/.ssh/id_ed_sonic.pub")}"
  }
  scheduling {
    preemptible = true
    provisioning_model = "SPOT"
    automatic_restart = false
  }
}

output "vm_external_ip" {
  value = google_compute_address.external_ip.address
}
