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
    hashedPassword = "$y$j9T$zhD4ntsrvOGlpgDcatdun.$26c1CAonxC.3serEg/GE/2oHdFO9ahXsaYVSEupHOR/";
  };

  systemd.services.amazon-init.enable = false;

  # fileSystems."/state" = {
  #   # TODO: Had some conflicts with autoResize and neededForBoot (maybe, may
  #   # have been a different issue) Figure out if autoResize is required for AWS
  #   # disk sizing
  #   # autoResize = true;
  #   # neededForBoot = true;
  #   # Use labeled disk for consistency
  #   device = "/dev/nvme1n1";
  #   fsType = "ext4";
  #   autoFormat = true;
  #   autoResize = true;
  #   neededForBoot = true; # Not needed for our usecase, but needed for impermanence
  #   options = ["x-systemd.device-timeout=10min"];
  # };
  systemd.services.format-nvme = {
    description = "Format /dev/sdf";

    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    path = with pkgs; [
      util-linux
      e2fsprogs
      amazon-ec2-utils
    ];
    script = ''
      set -euo pipefail

      function find_drive() {
        while IFS= read -r -d ''' dev; do
          if [[ "$(ebsnvme-id --block-dev "$dev")" == "/dev/sdf" ]]; then
            echo "$dev"
            return 0
          fi
          echo "after return"
        done < <(find /dev -regex '^/dev/nvme[0-9]+n1$' -print0)

        echo "Error: Device not found"
        return 1
      }

      drive="$(find_drive)"
      mkfs -t ext4 -L state "$drive"

      drive="/dev/disk/by-label/state"
      until [[ -e "$drive" ]]; do
        echo "Waiting for $drive to be ready..."
        sleep 1
      done
      echo "Device $drive ready"
    '';
  };

  systemd.mounts = [
    {
      what = "/dev/disk/by-label/state";
      where = "/state";
      type = "ext4";
      wantedBy = ["multi-user.target"];
      wants = ["format-nvme.service"];
      after = ["format-nvme.service"];
    }
    {
      what = "/state/var/lib/tailscale";
      where = "/var/lib/tailscale";
      wantedBy = ["multi-user.target"];
    }
  ];

  # Tailscale configuration
  services.tailscale.enable = true;
  systemd.services.tailscaled = {
    after = [ "var-lib-tailscale.mount" ];
    wants = [ "var-lib-tailscale.mount" ];
  };

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
      secret="/$hostname/tailscale/key"
      role="$hostname"_role

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
      token="$(
        curl \
          --silent \
          --request PUT \
          --header "X-aws-ec2-metadata-token-ttl-seconds: 30" \
          "$imds/api/token"
      )"

      creds="$(
        curl \
          --silent \
          --header "X-aws-ec2-metadata-token: $token" \
          "$imds/meta-data/iam/security-credentials/$role"
      )"

      export AWS_ACCESS_KEY_ID="$(echo "$creds" | jq -r .AccessKeyId)"
      export AWS_SECRET_ACCESS_KEY="$(echo "$creds" | jq -r .SecretAccessKey)"
      export AWS_SESSION_TOKEN="$(echo "$creds" | jq -r .Token)"
      auth_key="$(
        aws ssm get-parameter \
          --name="$secret" \
          --with-decryption \
          --output json \
          --region us-east-1 \
        | jq -r .Parameter.Value
      )"

      tailscale up --hostname="$hostname" --ssh --authkey="$auth_key"
    '';
  };
}
