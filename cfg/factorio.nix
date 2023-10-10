{ ... }: {
  disabledModules = [ "services/games/factorio.nix" ];
  imports = [
    ../modules/factorio.nix
    ../modules/load-ssm.nix
  ];
  config = {
    nixpkgs.config.allowUnfree = true;

    networking.hostName = "factorio";

    services.factorio = {
      enable = true;
      gamePasswordFile = "/secrets/factorio/password";
      openFirewall = true;
    };

    services.load-ssm = {
      enable = true;
      instanceRole = "factorio_service_role";
      instanceRegion = "us-east-1";
      secretList = [ "/factorio/password" ];
    };

    systemd.services.load-ssm = {
      requiredBy = ["factorio.service"];
      before = ["factorio.service"];
    };
  };
}
