{ self, nixpkgs, deploy-rs, impermanence, ... }: {
  nixosModules = import ./nixosModules;
  # TODO investigate automatic per-need IAM role creation
  nixosConfigurations.tailscale = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.tailscale-backed-ec2
      self.nixosModules.user-config
      {
        networking.hostName = "factorio";
        hacdc.tailscale.ssm-param = "/factorio/tailscale/key";
        hacdc.tailscale.aws-role = "factorio_role";
        hacdc.impermanence.mountpoint = "/state";
        hacdc.impermanence.device = "/dev/disk/by-label/state";
      }
    ];
    specialArgs = { inherit impermanence; };
  };
  deployNodes.tailscale = {
    # Hostname not used, overriden by CLI setting.
    hostname = "packer";
    sshUser = "root";
    user = "root";

    profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.tailscale;
  };
}