# Generate an SSH key pair as strings stored in Terraform state
resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

# Synchronize the SSH private key to a local file that the "nixos" module can use
resource "local_sensitive_file" "ssh_private_key" {
  filename = "${path.module}/id_ed25519"
  content  = tls_private_key.deploy_key.private_key_openssh
}

resource "local_file" "ssh_public_key" {
  filename = "${path.module}/id_ed25519.pub"
  content  = tls_private_key.deploy_key.public_key_openssh
}

# Mirror the SSH public key to EC2 so that we can later install the public key
# as an authorized key for our server
resource "aws_key_pair" "deploy_key" {
  public_key = tls_private_key.deploy_key.public_key_openssh
}
