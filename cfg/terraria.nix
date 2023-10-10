{ pkgs, ... }: {
  disabledModules = [ "services/games/terraria.nix" ];
  imports = [
    ../modules/terraria.nix
    ../modules/load-ssm.nix
  ];
  config = {
    nixpkgs.config.allowUnfree = true;

    networking.hostName = "terraria";

    environment.systemPackages = [ pkgs.tmux ];

    services.terraria = {
      enable = true;
      passwordFile = "/secrets/terraria/password";
      worldPath = "/var/lib/terraria/.local/share/Terraria/Worlds/World.wld";
      openFirewall = true;
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
