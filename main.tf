# Tenancy OCID Value
variable "tenancy_ocid" {}

# User OCID Value
variable "user_ocid" {}

# Fingerprint Value
variable "fp" {}

# Private Key Contents
variable "pkey_path" {}

# SSH public key to use for SSH access
variable "ssh_pub_key" {}

# OCI region to deploy into. MUST be a region your tenancy is subscribed to
# (usually your home region). A region the tenancy is not subscribed to returns
# "401-NotAuthenticated" on the very first Identity call.
variable "region" {
  description = "OCI region to deploy into (must be subscribed; default is the home region)"
  type        = string
  default     = "eu-milan-1"
}

# Optional explicit image OCIDs. Leave empty to auto-select the latest
# Oracle Linux 9 platform image for each shape in the chosen region. Image OCIDs
# are region-specific, so hardcoding them breaks the moment the region changes.
variable "vm_image_ocid_x86_64" {
  description = "Override OCID for the E2 (x86_64) image; empty = latest Oracle Linux 9"
  type        = string
  default     = ""
}

variable "vm_image_ocid_ampere" {
  description = "Override OCID for the A1 (aarch64) image; empty = latest Oracle Linux 9"
  type        = string
  default     = ""
}

# --- WireGuard relay (optional) -------------------------------------------
# When wg_client_pubkey is non-empty the A1 instance is provisioned as a
# WireGuard relay: it terminates a tunnel from your home machine and DNATs the
# BitTorrent port back to it, giving a stable public IP + inbound peers even
# behind carrier-grade NAT. Leave wg_client_pubkey empty to skip all of this.
variable "wg_client_pubkey" {
  description = "Base64 WireGuard public key of your home peer; empty disables the relay"
  type        = string
  default     = ""
}

variable "wg_listen_port" {
  description = "UDP port the WireGuard relay listens on"
  type        = number
  default     = 51820
}

variable "bt_port" {
  description = "TCP+UDP BitTorrent port to forward through the relay to the home peer"
  type        = number
  default     = 11899
}

variable "dht_port" {
  description = "TCP+UDP port for the Bitmagnet DHT crawler (inbound opened in the security list); 0 disables"
  type        = number
  default     = 3334
}

variable "wg_server_address" {
  description = "Relay address inside the tunnel (CIDR)"
  type        = string
  default     = "10.200.0.1/24"
}

variable "wg_client_address" {
  description = "Home-peer address inside the tunnel (host, no CIDR)"
  type        = string
  default     = "10.200.0.2"
}

# Define the module source and its location
module "oci-stack" {
  source               = "./oci-stack-module"
  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  compartment_name     = "oci-stack"
  fingerprint          = var.fp
  region               = var.region
  vm_name              = "oci-stack-instance"
  vm_image_ocid_x86_64 = var.vm_image_ocid_x86_64
  vm_image_ocid_ampere = var.vm_image_ocid_ampere
  private_key_path     = var.pkey_path
  ssh_public_key       = var.ssh_pub_key
  tags                 = { Project = "oci-tf-stack" }

  wg_client_pubkey  = var.wg_client_pubkey
  wg_listen_port    = var.wg_listen_port
  bt_port           = var.bt_port
  dht_port          = var.dht_port
  wg_server_address = var.wg_server_address
  wg_client_address = var.wg_client_address
}

output "module_public_ips_x86_64" {
  value = module.oci-stack.public-ip-x86_64-instances
}

output "module_private_ips_x86_64" {
  value = module.oci-stack.private-ip-x86_64-instances
}

output "module_instance_id_x86_64" {
  value = module.oci-stack.instance-id-x86_64-instances
}

output "module_public_ip_ampere" {
  value = module.oci-stack.public-ip-ampere-instance
}

output "module_private_ip_ampere" {
  value = module.oci-stack.private-ip-ampere-instance
}

output "module_instance_id_ampere" {
  value = module.oci-stack.instance-id-ampere-instance
}

# Public IP of the WireGuard relay (the A1 instance) — this is the stable
# address your trackers/peers will see. Empty string when the relay is disabled.
output "wireguard_relay_public_ip" {
  description = "Public IP to use as the WireGuard endpoint on your home peer"
  value       = var.wg_client_pubkey == "" ? "" : module.oci-stack.public-ip-ampere-instance
}
