{ ... }: {
  # UNCLEAN
  nixpkgs.config.allowUnfree = true;
  # The factorio state directory is made under /var/lib/factorio, but this is a
  # symlink to /var/lib/private/factorio. This is due to the DynamicUser and
  # StateDirectory configs in the service definition
  # environment.persistence."/state".directories = [
  #   "/var/lib/private/factorio"
  # ];
  services.factorio.enable = true;
  services.factorio.openFirewall = true;
  # systemd.services.factorio = {
  #   after = [ "var-lib-private-factorio.mount" ];
  #   wants = [ "var-lib-private-factorio.mount" ];
  # };
}
