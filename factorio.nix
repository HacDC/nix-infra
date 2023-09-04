{ ... }: {
  nixpkgs.config.allowUnfree = true;
  environment.persistence."/state".directories = [
    "/var/lib/private/factorio"
  ];
  services.factorio.enable = true;
  services.factorio.openFirewall = true;
}
