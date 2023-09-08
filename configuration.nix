{ pkgs, modulesPath, impermanence, ... }: {
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    impermanence.nixosModule
  ];

  # TODO: Required? Will be configured by ec2-medata service, if set. Would make
  # image more flexible
  networking.hostName = "factorio";

  system.stateVersion = "23.05";

  # Setup some swap space to help low-power systems with medium-size builds
  swapDevices = [{
    device = "/swapfile";
    size = 1*1024; # 1G
  }];

  fileSystems."/state" = {
    # TODO: Had some conflicts with autoResize and neededForBoot (maybe, may
    # have been a different issue) Figure out if autoResize is required for AWS
    # disk sizing
    # autoResize = true;
    neededForBoot = true;
    # Use labeled disk for consistency
    device = "/dev/disk/by-label/state";
    fsType = "ext4";
  };

  environment.systemPackages = with pkgs; [
    awscli2
    amazon-ec2-utils
    tailscale
    neovim-unwrapped # Unwrapped, to avoid pulling in ruby/python dependencies
    jq
  ];

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
  };

  systemd.services.amazon-init.enable = false;

  # Tailscale configuration
  environment.persistence."/state".directories = [
    "/var/lib/tailscale"
  ];
  services.tailscale.enable = true;
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # Make sure tailscale is running before trying to connect to tailscale
    after = [
      "network-pre.target"
      "tailscaled.service"
      "apply-ec2-data.service"
    ];
    wants = [
      "network-pre.target"
      "tailscaled.service"
      "apply-ec2-data.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    path = with pkgs; [
      tailscale
      awscli
      jq
      curl
    ];
    script = ''
      set -euo pipefail

      # TODO: Find this from a hostname set in Terraform or Nix. Terraform path
      # requires ec2 metadata service to have run
      hostname="factorio"
      secret="/factorio/tailscale/key"
      role="factorio_role"

      # Check if we are already authenticated to tailscale. If so do nothing
      until status="$(tailscale status --json)"; do
        sleep 1
      done
      status="$(echo "$status" | jq -r .BackendState)"
      if [ "$status" = "Running" ]; then
        exit 0
      fi

      # Fetch the auth key from aws metadata
      imds="http://169.254.169.254/latest"
      token="$(curl -s -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 30" "$imds/api/token")"
      creds="$(curl -s -H "X-aws-ec2-metadata-token: $token" "$imds/meta-data/iam/security-credentials/$role")"
      export AWS_ACCESS_KEY_ID="$(echo "$creds" | jq -r .AccessKeyId)"
      export AWS_SECRET_ACCESS_KEY="$(echo "$creds" | jq -r .SecretAccessKey)"
      export AWS_SESSION_TOKEN="$(echo "$creds" | jq -r .Token)"
      auth_key="$(aws ssm get-parameter --name="$secret" --with-decryption --output json --region us-east-1 | jq -r .Parameter.Value)"

      tailscale up --hostname="$hostname" --ssh --authkey="$auth_key"
    '';
  };
}
