#cloud-config

package_update: true
package_upgrade: true

packages:
  - ansible
  - tmux
  - rsync
  - git
  - curl
  - gettext
  - device-mapper-persistent-data
  - lvm2
  - bzip2

groups:
  - docker
system_info:
  default_user:
    groups: [docker]
%{ if wg_enabled ~}

write_files:
  - path: /opt/wg-relay/setup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Provision this A1 instance as a WireGuard relay that DNATs the
      # BitTorrent port to a home peer behind CGNAT. Idempotent.
      set -euo pipefail
      mkdir -p /etc/wireguard
      umask 077
      if [ ! -f /etc/wireguard/server.key ]; then
        wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
      fi
      SRV_PRIV=$(cat /etc/wireguard/server.key)
      cat > /etc/wireguard/wg0.conf <<EOF
      [Interface]
      Address = ${wg_server_address}
      ListenPort = ${wg_listen_port}
      PrivateKey = $SRV_PRIV
      # Forward inbound BitTorrent to the home peer over the tunnel.
      PostUp = sysctl -w net.ipv4.ip_forward=1
      PostUp = iptables -t nat -A PREROUTING -p tcp --dport ${bt_port} -j DNAT --to-destination ${wg_client_address}:${bt_port}
      PostUp = iptables -t nat -A PREROUTING -p udp --dport ${bt_port} -j DNAT --to-destination ${wg_client_address}:${bt_port}
      PostUp = iptables -t nat -A POSTROUTING -d ${wg_client_address} -j MASQUERADE
      # Masquerade the home peer's outbound traffic so trackers see this VPS IP.
      PostUp = iptables -t nat -A POSTROUTING -s ${wg_server_address} ! -d ${wg_server_address} -j MASQUERADE
      PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
      PostUp = iptables -A FORWARD -o wg0 -j ACCEPT
      PostDown = iptables -t nat -D PREROUTING -p tcp --dport ${bt_port} -j DNAT --to-destination ${wg_client_address}:${bt_port}
      PostDown = iptables -t nat -D PREROUTING -p udp --dport ${bt_port} -j DNAT --to-destination ${wg_client_address}:${bt_port}
      PostDown = iptables -t nat -D POSTROUTING -d ${wg_client_address} -j MASQUERADE
      PostDown = iptables -t nat -D POSTROUTING -s ${wg_server_address} ! -d ${wg_server_address} -j MASQUERADE
      PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
      PostDown = iptables -D FORWARD -o wg0 -j ACCEPT

      [Peer]
      PublicKey = ${wg_client_pubkey}
      AllowedIPs = ${wg_client_address}/32
      EOF
      chmod 600 /etc/wireguard/wg0.conf
%{ endif ~}

runcmd:
  - grubby --update-kernel ALL || true
  - dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  - dnf update -y
  - dnf install epel-release -y
%{ if wg_enabled ~}
  - dnf install -y wireguard-tools
%{ endif ~}
  - dnf install docker-ce docker-ce-cli containerd.io -y
  - dnf install -y docker-compose-plugin
  - docker compose --version
  - systemctl enable docker
  - systemctl start docker
  - docker info
  - echo 'OCI Ampere A1 OracleLinux 9' >> /etc/motd
%{ if wg_enabled ~}
  # WireGuard relay: enable forwarding, defer firewalling to the OCI security
  # list + wg-quick rules, then bring up the tunnel.
  - echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-wg-forward.conf
  - sysctl --system
  - systemctl disable --now firewalld || true
  - /opt/wg-relay/setup.sh
  - systemctl enable --now wg-quick@wg0
  - echo "WireGuard relay public key: $(cat /etc/wireguard/server.pub)" >> /etc/motd
%{ endif ~}
  # Mount additional drive
  - |
    if [ ! -e "/dev/oracleoci/oraclevdb1" ]; then
      echo "n1" | sfdisk /dev/oracleoci/oraclevdb
      mkfs.ext4 /dev/oracleoci/oraclevdb1
      mkdir -p /mnt/data
      mount /dev/oracleoci/oraclevdb1 /mnt/data
      echo '/dev/oracleoci/oraclevdb1 /mnt/data ext4 defaults,nofail 0 2' >> /etc/fstab
    fi
