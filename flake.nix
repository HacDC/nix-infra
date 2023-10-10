{
  description = "";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, deploy-rs, ... }: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    # forEachSystem [ "x86_64-linux" ] (_: { example = true; }) -> { x86_64-linux.example = true }
    forEachSystem = nixpkgs.lib.genAttrs systems;
  in {
    devShells = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixos-rebuild
          awscli2
          opentofu
          tailscale
          infracost
          deploy-rs.packages.${system}.default
          jq
          curl
          nix-tree
        ];
      };
    });

    nixosConfigurations.factorio = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./cfg/configuration.nix
        ./cfg/factorio.nix
      ];
    };

    deploy.nodes.factorio = {
      hostname = "factorio";
      sshUser = "root";
      user = "root";

      profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.factorio;
    };

    nixosConfigurations.terraria = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./cfg/configuration.nix
        ./cfg/terraria.nix
      ];
    };

    deploy.nodes.terraria = {
      hostname = "terraria";
      sshUser = "root";
      user = "root";

      profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.terraria;
    };
  };
}
