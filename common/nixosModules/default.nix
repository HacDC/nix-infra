{
  ec2-impermanence = import ./ec2-impermanence.nix;
  ec2 = import ./ec2.nix;
  tailscale-backed-ec2 = import ./tailscale-backed-ec2.nix;
  user-config = import ./user-config.nix;
}