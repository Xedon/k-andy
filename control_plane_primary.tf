resource "hcloud_server" "first_control_plane" {
  name = "${var.name}-control-plane-0"

  image       = data.hcloud_image.server_image.name
  server_type = var.control_plane_server_type
  location    = var.server_locations[0]

  ssh_keys = [hcloud_ssh_key.provision_public.id]
  labels = merge({
    node_type = "control-plane"
  }, local.common_labels)

  user_data = format("%s\n%s", "#cloud-config", yamlencode(
    {
      runcmd = [
        "curl -sfL https://get.k3s.io | K3S_TOKEN='${random_password.k3s_cluster_secret.result}' INSTALL_K3S_VERSION='${var.k3s_version}' ${var.control_plane_already_initialized ? local.k3s_server_join_cmd : local.k3s_server_init_cmd}"
      ]
      packages = concat(local.server_base_packages, var.server_additional_packages)
    }
  ))

  provisioner "remote-exec" {
    inline = [
      "until systemctl is-active --quiet k3s.service; do sleep 1; done",
      "until kubectl get node ${self.name}; do sleep 1; done",
      # Disable workloads on master node
      "kubectl taint node ${self.name} node-role.kubernetes.io/master=true:NoSchedule",
      "kubectl taint node ${self.name} CriticalAddonsOnly=true:NoExecute",
      # Install hetzner CCM
      "kubectl -n kube-system create secret generic hcloud --from-literal=token=${var.hcloud_token} --from-literal=network=${local.network_name}",
      "kubectl apply -f -<<EOF\n${templatefile("${path.module}/manifests/hcloud-ccm-net.yaml", { cluster_cidr = var.cluster_cidr })}\nEOF",
      # Install hetzner CSI plugin
      "kubectl -n kube-system create secret generic hcloud-csi --from-literal=token=${var.hcloud_token}",
      "kubectl apply -f -<<EOF\n${data.http.hcloud_csi_driver_manifest.body}\nEOF",
    ]

    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  // Otherwise we would be in a case where this would always be recreated because we switch the primary control plane IP
  lifecycle {
    ignore_changes = [user_data]
  }

}

resource "hcloud_server_network" "first_control_plane" {
  subnet_id = hcloud_network_subnet.k3s_nodes.id
  server_id = hcloud_server.first_control_plane.id
  ip        = local.primary_control_plane_ip
}
