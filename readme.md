# Auth
(TODO)
- Flakes
- Direnv
- AWS Configuration
- Tailscale setup
- .env.template -> .env
- Terraform/Packer init

# Deploying
```bash
# Build AMI
aws-ami-build
terraform apply
```

# Destroying
```bash
aws-ami-delete
tailscale-device-delete nix-tailscale
terraform destroy
```

# System Access
```bash
tailscale ssh hacdc@factorio
```
