variable "tenancy_ocid" {
  description = "The OCID of the tenancy"
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the user"
  type        = string
}

variable "private_key_path" {
  description = "The path of the private key"
  type        = string
}

variable "fingerprint" {
  description = "The fingerprint for the key pair"
  type        = string
}

variable "region" {
  description = "The OCI region for resources"
  type        = string
}

variable "compartment_name" {
  description = "The name of the compartment"
  type        = string
}

variable "tags" {
  description = "Freeform tags for the resources"
  type        = map(any)
  default     = {}
}

variable "vm_name" {
  description = "The name of the VM instances"
  type        = string
}

variable "vm_image_ocid_ampere" {
  description = "Override OCID for the Oracle Linux 9 image (Ampere/aarch64); empty = auto-select latest"
  type        = string
  default     = ""
}

variable "vm_image_ocid_x86_64" {
  description = "Override OCID for the Oracle Linux 9 image (x86_64); empty = auto-select latest"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "The public key for SSH access to instances"
  type        = string
}

# --- WireGuard relay (optional) -------------------------------------------
variable "wg_client_pubkey" {
  description = "Base64 WireGuard public key of the home peer; empty disables the relay"
  type        = string
  default     = ""
}

variable "wg_listen_port" {
  description = "UDP port the WireGuard relay listens on"
  type        = number
  default     = 51820
}

variable "bt_port" {
  description = "TCP+UDP BitTorrent port forwarded through the relay to the home peer"
  type        = number
  default     = 11899
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
