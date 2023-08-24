{ pkgs, modulesPath, ... }: {
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  environment.systemPackages = with pkgs; [
    neovim
    tailscale
    awscli2
  ];

  users.users.mmazzanti = {
    isNormalUser  = true;
    extraGroups  = [ "wheel" ];
    openssh.authorizedKeys.keys  = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAXPC+JicLK6gxDVtvQaLN5CEPSXyFIrPe8OlcEm3Zz mmazzanti@beta.local" ];
  };
}
