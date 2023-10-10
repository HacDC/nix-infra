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
    tailscale
    neovim-unwrapped # Unwrapped, to avoid pulling in ruby/python dependencies
    jq
  ];

  boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";

  # passwordless sudo required to deploy via deploy-rs
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users.hacdc = {
    isNormalUser  = true;
    extraGroups  = [ "wheel" ];
    hashedPassword = "$y$j9T$zhD4ntsrvOGlpgDcatdun.$26c1CAonxC.3serEg/GE/2oHdFO9ahXsaYVSEupHOR/";
  };

  systemd.services.amazon-init.enable = false;
}
