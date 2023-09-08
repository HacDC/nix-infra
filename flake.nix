{
  description = "";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, impermanence, deploy-rs, ... }@inputs: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    # forEachSystem [ "x86_64-linux" ] (_: { example = true; }) -> { x86_64-linux.example = true }
    forEachSystem = nixpkgs.lib.genAttrs systems;

    common = import ./common inputs;
    factorio = import ./factorio inputs;
  in {
    devShells = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixos-rebuild
          awscli2
          terraform
          packer
          tailscale
          infracost
          deploy-rs.packages.${system}.default
          jq
          curl
        ];
      };
    });

    nixosModules = common.nixosModules;
    nixosConfigurations = factorio.nixosConfigurations // common.nixosConfigurations;
    deploy.nodes = factorio.deployNodes // common.deployNodes;

    # Requires an x86_64-linux builder to be available
    checks = builtins.mapAttrs (system: deployLib:
      deployLib.deployChecks self.deploy
    ) deploy-rs.lib;
  };
}
