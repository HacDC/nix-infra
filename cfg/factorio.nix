{ pkgs, ... }: {
  disabledModules = [ "services/games/factorio.nix" ];
  imports = [
    ../modules/factorio.nix
    ../modules/load-ssm.nix
  ];
  config = {
    nixpkgs.config.allowUnfree = true;

    networking.hostName = "factorio";

    environment.systemPackages = [pkgs.inotify-tools];

    services.factorio = {
      enable = true;
      gamePasswordPath = "/secrets/factorio/password";
      openFirewall = true;
      admins = ["mmazzanti"];
      autosave-interval = 10;
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
