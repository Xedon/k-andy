data "hcloud_image" "server_image" {
  name = var.server_image
}

resource "random_pet" "agent_suffix" {
  count = var.server_count
}

locals {
  agent_pet_names = [for pet in random_pet.agent_suffix : pet.id]
  agent_name_map  = { for i in range(0, var.server_count) : random_pet.agent_suffix[i].id => i }
}
