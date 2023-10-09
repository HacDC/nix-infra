{ ... }: {
  # UNCLEAN
  nixpkgs.config.allowUnfree = true;
  services.factorio.enable = true;
  # services.factorio.openFirewall = true;
}
