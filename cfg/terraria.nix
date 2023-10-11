{ pkgs, ... }: let
  terraria-admin = pkgs.writeShellScriptBin "terraria-admin" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail
    set -m

    trap 'kill "$(jobs -p)"' SIGINT SIGTERM EXIT
    journalctl --follow --unit terraria.service --output cat &
    cat > /run/terraria.stdin
  '';
in {
  imports = [
    ../modules/terraria.nix
    ../modules/load-ssm.nix
  ];
  config = {
    nixpkgs.config.allowUnfree = true;

    networking.hostName = "terraria";
    environment.systemPackages = [ terraria-admin ];
    users.users.mmazzanti.extraGroups  = [ "terraria" ];

    services.terraria = {
      enable = true;
      passwordPath = "/secrets/terraria/password";
      worldName = "test2";
      openFirewall = true;
      noUPnP = true;
      secure = true;
    };

    services.load-ssm = {
      enable = true;
      instanceRole = "terraria_service_role";
      instanceRegion = "us-east-1";
      secretList = [ "/terraria/password" ];
    };

    systemd.services.load-ssm = {
      requiredBy = ["terraria.service"];
      before = ["terraria.service"];
    };
  };
}
