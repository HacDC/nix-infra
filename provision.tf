# Ensure that the instance is reachable via `ssh` before deploying
resource "null_resource" "wait" {
  provisioner "remote-exec" {
    connection {
      host        = aws_instance.factorio.public_dns
      private_key = tls_private_key.deploy-key.private_key_openssh
    }

    inline = [":"] # Do nothing; we're just testing SSH connectivity
  }
}

locals {
  # run the command in the nix dev shell
  nix-shell-cmd = "nix --extra-experimental-features \"nix-command flakes\" develop .# --command"
  # use the generated keys and trust the new host
  ssh-opts = "-o StrictHostKeyChecking=accept-new -i ${local_sensitive_file.ssh_private_key.filename}"
  # override ssh-user and hostname for the bootstrap deployment
  deploy-args = "--ssh-user=root --ssh-opts=\"${local.ssh-opts}\" --hostname=${aws_instance.factorio.public_dns}"
}

resource "null_resource" "deploy" {
  provisioner "local-exec" {
    command = "${local.nix-shell-cmd} deploy ${deploy-args} .#factorio"
  }

  depends_on = [null_resource.wait]
}
