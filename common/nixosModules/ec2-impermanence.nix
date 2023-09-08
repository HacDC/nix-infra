{ lib, config, impermanence, ... }:
let
  cfg = config.hacdc.impermanence;
in
{
  imports = [
    impermanence.nixosModule
  ];

  options.hacdc.impermanence = {
    device = lib.mkOption {
      type = lib.types.str;
      description = "The block device to set as the impermanence ";
    };
    mountpoint = lib.mkOption {
      type = lib.types.str;
      description = "The path to mount to ";
    };
    persistent-dirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Alias for environment.persistence.\"\${config.hacdc.impermanence.mountpoint}\".directories";
      default = [];
    };
  };

  config = {
    fileSystems."${cfg.mountpoint}" = {
      # TODO: Had some conflicts with autoResize and neededForBoot (maybe, may
      # have been a different issue) Figure out if autoResize is required for AWS
      # disk sizing
      # autoResize = true;
      neededForBoot = true;
      # Use labeled disk for consistency
      device = cfg.device;
      fsType = "ext4";
    };

    systemd.services.amazon-init.enable = false;

    environment.persistence.${cfg.mountpoint}.directories = cfg.persistent-dirs;
  };
}