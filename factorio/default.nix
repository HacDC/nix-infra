{ self, deploy-rs, ... }@inputs: {
  nixosConfigurations.factorio = import ./nixosConfiguration.nix inputs;
  deployNodes.factorio = {
      hostname = "factorio";
      # Getting a "signing key" error with hacdc user
      sshUser = "root";
      user = "root";

      profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.factorio;
  };
}