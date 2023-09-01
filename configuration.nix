{ pkgs, modulesPath, impermanence, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    impermanence.nixosModule
  ];

  networking.hostName = "factorio";

  system.stateVersion = "23.05";

  swapDevices = [{
    device = "/swapfile";
    size = 1*1024; # 1G
  }];

  fileSystems."/state" = {
    neededForBoot = true;
    device = "/dev/disk/by-label/state";
    fsType = "ext4";
  };

  environment.systemPackages = with pkgs; [
    neovim-unwrapped
    tailscale
    awscli2
    jq
    amazon-ec2-utils
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
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # Set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # Have the job run this shell script
    path = with pkgs; [
      tailscale
      awscli
      jq
      curl
    ];
    script = ''
      set -e

      hostname="factorio"
      secret="/factorio/tailscale/key"
      role="factorio_role"

      # Wait for tailscaled to settle
      sleep 2

      # Check if we are already authenticated to tailscale. If so do nothing
      status="$(tailscale status --json | jq -r .BackendState)"
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
