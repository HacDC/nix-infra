{ pkgs, lib, modulesPath, ... }: {
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  system.stateVersion = "23.05";

  # Setup some swap space to help low-power systems with medium-size builds
  swapDevices = [{
    device = "/swapfile";
    size = 1*1024; # 1G
  }];

  environment.systemPackages = with pkgs; [
    awscli2
    amazon-ec2-utils
    neovim-unwrapped # Unwrapped, to avoid pulling in ruby/python dependencies
    jq
  ];

  boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users.mmazzanti = {
    isNormalUser  = true;
    extraGroups  = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4h5HZCnD2uFkpb8Z/pPQKXrtdV5YU3DG1w+9rOyddy mmazzanti@beta.xi" ];
  };

  # passwordless sudo required to deploy via deploy-rs
  security.sudo.wheelNeedsPassword = false;

  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  systemd.services.amazon-init.enable = false;
}
