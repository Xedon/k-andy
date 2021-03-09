variable "hcloud_token" {}

provider "hcloud" {
  token = var.hcloud_token
}

resource "random_password" "k3s_cluster_secret" {
  length  = 48
  special = false
}

resource "hcloud_ssh_key" "default" {
  name       = "K3S terraform module - Provisionning SSH key"
  public_key = file(var.public_key)
}

resource "hcloud_network" "k3s" {
  name     = "k3s-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k3s_nodes" {
  type         = "cloud"
  network_id   = hcloud_network.k3s.id
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

data "hcloud_image" "ubuntu" {
  name = "ubuntu-20.04"
}

variable "servers_num" {
  description = "Number of control plane nodes."
  default     = 3
}

variable "agents_num" {
  description = "Number of agent nodes."
  default     = 2
}

variable "k3s_version" {
  description = "K3s version"
  default     = "v1.20.4+k3s1"
}

variable "hetzner_csi_version" {
  description = "Hetzner CSI version"
  default     = "master"
}
