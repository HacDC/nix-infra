{
  description = "";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, impermanence, deploy-rs, ... }: let
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
          terraform
          tailscale
          infracost
          deploy-rs.packages.${system}.default
        ];
      };
    });

    nixosConfigurations.factorio = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
      specialArgs = { inherit impermanence; };
    };

    deploy.nodes.factorio = {
      # By default, connect to host factorio with ssh user hacdc and sudo as
      # root Note that for terraform deployments the sshUser and hostname are
      # overridden.
      hostname = "factorio";
      sshUser = "hacdc";
      user = "root";

      profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.factorio;
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
