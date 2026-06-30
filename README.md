<div align="center">
<img src="docs/assets/logo.png" align="center" width="144px" height="144px"/>

### OCI Free Terraform Stack

_An opinionated Terraform module for Oracle Cloud Infrastructure that provisions a complete free-tier stack including compute and networking. Ships with a ready-to-run GitHub Actions workflow._
</div>

<div align="center">

[![Terraform](https://img.shields.io/badge/Terraform-Required-623CE4?logo=terraform&logoColor=white&style=for-the-badge)](https://www.terraform.io/)
[![Terraform Version](https://img.shields.io/badge/Terraform-1.6%2B-623CE4?logo=terraform&logoColor=white&style=for-the-badge)](https://www.terraform.io/)

</div>

<div align="center">

[![OpenSSF Scorecard](https://img.shields.io/ossf-scorecard/github.com/sudo-kraken/oci-free-terraform-stack?label=openssf%20scorecard&style=for-the-badge)](https://scorecard.dev/viewer/?uri=github.com/sudo-kraken/oci-free-terraform-stack)

</div>

## Contents

- [Overview](#overview)
- [Architecture at a glance](#architecture-at-a-glance)
- [Features](#features)
- [Prerequisites](#prerequisites)
  - [Secrets required](#secrets-required)
- [Automated deployment with GitHub Actions](#automated-deployment-with-github-actions)
  - [GitHub Action execution](#github-action-execution)
  - [Accessing the instances](#accessing-the-instances)
- [Quick start](#quick-start)
- [Troubleshooting](#troubleshooting)
- [Licence](#licence)
- [Security](#security)
- [Contributing](#contributing)
- [Support](#support)

## Overview

This module provisions an Oracle Cloud Infrastructure environment that fits the free-tier allowances. It creates compute, networking and storage so you can launch useful workloads at zero cost.

The stack includes:
- **2x VM.Standard.E2.1.Micro** instances, each with **1 OCPU** and **1 GB RAM**
- **1x VM.Standard.A1.Flex** instance with **2 OCPUs** and **12 GB RAM**, plus a **59 GB block volume** # REDUCED FROM 4 OCPUs and 26GB RAM 15/06/2026
- A **Virtual Cloud Network** with subnets, security lists and an internet gateway

> [!NOTE]  
> All resources are defined to align with free-tier constraints where applicable. Always check your tenancy and region limits.

## Architecture at a glance

- Terraform module defines:
  - VCN, subnets, security lists and internet gateway
  - Three compute instances as listed above
  - One block volume attached to the A1 Flex instance
- Opinionated security lists to enable typical access
- Ready-made GitHub Actions workflow to run Terraform from CI

## Features

- Free-tier friendly shapes and sizes
- Complete baseline networking with internet access
- Automated plan and apply from GitHub Actions
- Clean-up on failure to help maintain a tidy tenancy

## Prerequisites

- Oracle Cloud Infrastructure account
- Terraform 1.6 or newer
- **OCI API credentials** stored as GitHub Secrets

### Secrets required

| Secret name | Required | Description |
|-------------|----------|-------------|
| `PKEY` | yes | OCI **API signing** private key in PEM form (RSA/PKCS8). NOT an OpenSSH key — an OpenSSH key is the #1 cause of `401-NotAuthenticated`. The pipeline preflights this and prints the computed fingerprint if it mismatches `FP`. |
| `FP` | yes | Fingerprint of the API key (must match `PKEY`). |
| `TENANCY_OCID` | yes | OCID of your tenancy. |
| `USER_OCID` | yes | OCID of your user. |
| `SSH_PUB_KEY` | yes | SSH public key added to the instances (`opc` login). |
| `OCI_S3_ACCESS_KEY` | yes | Access key of an OCI **Customer Secret Key** — used by the Terraform S3 state backend. |
| `OCI_S3_SECRET_KEY` | yes | Secret of that Customer Secret Key. |
| `WG_CLIENT_PUBKEY` | no | Base64 WireGuard public key of your home peer. Set it to turn the A1 instance into a WireGuard relay; leave unset for a plain stack. |

> [!IMPORTANT]
> Deploy into a region your tenancy is **subscribed to** (usually your home
> region). Targeting an unsubscribed region returns `401-NotAuthenticated` on the
> very first Identity call — this is a region problem, not a credentials problem.
> The region defaults to `eu-milan-1`; override with the `region` variable.

## Automated deployment with GitHub Actions

The workflow **Execute OCI Pipeline** performs the following:

- Checks out the repository to the GitHub runner
- Sets up **Node.js** and the **Terraform CLI** environments
- Configures the SSH private key and Terraform variables from **GitHub Secrets**
- Initialises Terraform, creates a plan and applies it
- On failure, automatically destroys provisioned resources to return to a clean state

### GitHub Action execution

The root **`main.tf`** is the entry point used by the workflow. It wires the module, variables and provisioners. As part of instance initialisation it **updates packages** and installs **Docker** and **Docker Compose**.

### Accessing the instances

When the workflow completes successfully, the **public IPs** of instances are shown in the Terraform outputs. Connect using:

- Username: `opc`  
- Authentication: the SSH key you provided in `SSH_PUB_KEY`

## WireGuard relay (inbound behind CGNAT)

Set `WG_CLIENT_PUBKEY` and the **A1 instance** is provisioned as a WireGuard
relay: it terminates a tunnel from your home machine and **DNATs the BitTorrent
port** (`bt_port`, default `11899`) back to it. Outbound traffic from the home
peer is masqueraded behind the relay's public IP, so trackers/peers see a stable
address and inbound connections work even when your ISP uses carrier-grade NAT.

Relevant variables (root `main.tf`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `wg_client_pubkey` | `""` | Home peer's WireGuard public key; empty disables the relay |
| `wg_listen_port` | `51820` | UDP port the relay listens on |
| `bt_port` | `11899` | TCP+UDP port forwarded to the home peer |
| `wg_server_address` | `10.200.0.1/24` | Relay tunnel address |
| `wg_client_address` | `10.200.0.2` | Home-peer tunnel address |

After apply, `terraform output wireguard_relay_public_ip` gives the endpoint.
Fetch the relay's generated public key over SSH:

```sh
ssh opc@<relay-ip> 'sudo cat /etc/wireguard/server.pub'
```

Then on your home machine (`/etc/wireguard/wg1.conf`):

```ini
[Interface]
Address = 10.200.0.2/32
PrivateKey = <your home private key>

[Peer]
PublicKey = <relay server.pub>
Endpoint = <relay-ip>:51820
AllowedIPs = 10.200.0.1/32
PersistentKeepalive = 25
```

Bring it up with `wg-quick up wg1`, point your BitTorrent client's listen port at
`11899`, and inbound peers reach you through the relay.

## Quick start

1. **Fork or clone** this repository into your GitHub account.
2. Create the **GitHub Secrets** listed above in your repository settings.
3. Review `main.tf` and the module variables to confirm regions, compartments and any tags.
4. Open the **Actions** tab, select **Execute OCI Pipeline**, provide any inputs and **run** it.
5. On completion, use the outputs to **SSH** to the instances as `opc`.

> [!NOTE]  
> If you prefer local execution, you can run `terraform init`, `terraform plan` and `terraform apply` from your workstation once your OCI credentials are exported appropriately. The CI workflow remains the recommended path.

## Troubleshooting

- **Apply failed or timed out**  
  Check the Actions logs for missing or incorrect secrets. Ensure the tenancy, compartment and region match your expectations.
- **Cannot SSH**  
  Verify that `SSH_PUB_KEY` matches your local private key and that security lists allow ingress from your IP.
- **Quota or service limits**  
  Free-tier entitlements and regional capacity can vary. Adjust regions or shapes if a resource cannot be created.

## Licence

This project is licensed under the MIT Licence. See the [LICENCE](LICENCE) file for details.

## Security

If you discover a security issue, please review and follow the guidance in [SECURITY.md](SECURITY.md), or open a private security-focused issue with minimal details and request a secure contact channel.

## Contributing

Feel free to open issues or submit pull requests if you have suggestions or improvements.  
See [CONTRIBUTING.md](CONTRIBUTING.md)

## Support

Open an [issue](/../../issues) with as much detail as possible, including your tenancy region, the workflow you ran and relevant Terraform logs.
