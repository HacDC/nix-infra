{ pkgs, modulesPath, lib, ... }: {
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  system.stateVersion = lib.mkDefault "23.05";

  # setup some swap space to help low-power systems with medium-size builds
  swapDevices = [{
    device = "/swapfile";
    size = 1*1024; # 1G
  }];

  environment.systemPackages = with pkgs; [
    awscli2
    amazon-ec2-utils
    jq
  ];

  # passwordless sudo required to deploy via deploy-rs
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = lib.mkDefault false;
    settings.KbdInteractiveAuthentication = lib.mkDefault false;
  };
}