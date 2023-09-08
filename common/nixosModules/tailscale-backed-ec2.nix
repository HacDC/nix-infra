{ lib, config, pkgs, ... }:
let
  cfg = config.hacdc.tailscale;
in
{
  imports = [
    ./ec2.nix
    ./ec2-impermanence.nix
  ];

  options.hacdc.tailscale = {
    device-name = lib.mkOption {
      type = lib.types.str;
      description = "The factorio device name";
      default = config.networking.hostName;
    };
    ssm-param = lib.mkOption {
      type = lib.types.str;
      description = "The SSM Paramstore key containing the Tailscale device key";
    };
    aws-role = lib.mkOption {
      type = lib.types.str;
      description = "The AWS IAM Role to assume in order to pull down the Tailscale key SSM parameter";
    };
  };

  config = {
    hacdc.impermanence.persistent-dirs = [
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

        hostname=${lib.strings.escapeShellArg cfg.device-name}
        secret=${lib.strings.escapeShellArg cfg.ssm-param}
        role=${lib.strings.escapeShellArg cfg.aws-role}

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
  };
}