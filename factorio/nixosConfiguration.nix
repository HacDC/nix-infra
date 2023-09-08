{ self, nixpkgs, impermanence, ... }: nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit impermanence; };
  modules = [
    self.nixosModules.tailscale-backed-ec2
    self.nixosModules.user-config
    {
      networking.hostName = "factorio";
      hacdc.tailscale.ssm-param = "/factorio/tailscale/key";
      hacdc.tailscale.aws-role = "factorio_role";
      hacdc.impermanence.mountpoint = "/state";
      hacdc.impermanence.device = "/dev/disk/by-label/state";

      # UNCLEAN
      nixpkgs.config.allowUnfree = true;
      services.factorio.enable = true;
      services.factorio.openFirewall = true;
      # The factorio state directory is made under /var/lib/factorio, but this is a
      # symlink to /var/lib/private/factorio. This is due to the DynamicUser and
      # StateDirectory configs in the service definition
      hacdc.impermanence.persistent-dirs = [
        "/var/lib/private/factorio"
      ];
    }
  ];
}
