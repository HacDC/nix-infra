packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.6"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "nix-tailscale" {
  # For testing purposes
  # skip_create_ami = true

  # Legacy SSO profile, configured separately from the new style SSO
  profile       = "legacy"

  ami_name      = "nix-tailscale"
  instance_type = "t3.micro"
  region        = "us-east-1"
  # TODO: setup ami block or load from nixpkgs
  source_ami    = "ami-07df5833f04703a2a"
  ssh_username  = "root"

  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_type = "gp3"
    volume_size = 8
    delete_on_termination = true
  }

  launch_block_device_mappings {
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = 8
    delete_on_termination = true
  }
}

build {
  name = "nix-tailscale"
  sources = [
    "source.amazon-ebs.nix-tailscale"
  ]

  provisioner "shell" {
    inline = [ <<-EOT
      function wait_for() {
        drive="$1"
        until [ -e "$drive" ]; do
          echo "Waiting for $drive to be ready..."
          sleep 1
        done
        echo "Device $drive ready"
      }

      # Setup temp swap file to help building & stability
      fallocate -l 1G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile

      drive="/dev/sdf"
      wait_for "$drive"
      mkfs -t ext4 -L state "$drive"

      drive="/dev/disk/by-label/state"
      wait_for "$drive"
      mkdir /state
      mount "$drive" /state
    EOT
    ]
  }

  provisioner "shell-local" {
    env = {
      "HOST" = build.Host
      "USER" = build.User
      "KEY" = build.SSHPrivateKey
    }
    # Default shell is sh, set to bash for $() expansion
    inline_shebang = "/usr/bin/env bash -e"
    inline = [ <<-EOT
      set -euo pipefail
      # Create temp file for key, remove on script exit
      keyfile="$(mktemp)"
      trap 'rm -rf -- "$keyfile"' EXIT
      echo "$KEY" > "$keyfile"

      # Allow all host keys, and don't save to known_hosts file
      ssh_opts="-o StrictHostKeyChecking=no"
      ssh_opts="$ssh_opts -o UserKnownHostsFile=/dev/null"
      # Use the provided key, and only that key, for login
      ssh_opts="$ssh_opts -o IdentitiesOnly=yes"
      ssh_opts="$ssh_opts -i $keyfile"

      # Deploy has to run in "boot" mode (IE no immediate switch) to ensure that
      # services don't hang due to invalid environment
      deploy \
        --boot \
        --ssh-opts="$ssh_opts" \
        --ssh-user="$USER" \
        --hostname="$HOST" \
        '${dirname(dirname(path.root))}#tailscale'
    EOT
    ]
  }

  provisioner "shell" {
    # Cleanup files set during deployment. Removing the authorized_keys is a
    # hard requirement, since the key won't be set during init otherwise.
    # Metadata is just a nicety, since that's cleared each boot
    inline = [ <<-EOT
      rm -f /root/.ssh/authorized_keys
      rm -f "/etc/ec2-metadata/*"
    EOT
    ]
  }
}
