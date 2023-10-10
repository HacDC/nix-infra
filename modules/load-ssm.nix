{ config, pkgs, lib, ... }: 
with lib;
let
  cfg = config.services.load-ssm;

  esc = escapeShellArg;

  aws-login = pkgs.writeShellApplication {
    name = "aws-login";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -euo pipefail
      role="$1"
      ttl="$${2:-30}"

      imds="http://169.254.169.254/latest"
      token="$(
        curl \
          --silent \
          --request PUT \
          --header "X-aws-ec2-metadata-token-ttl-seconds: $ttl" \
          "$imds/api/token"
      )"
      creds="$(
        curl \
          --silent \
          --header "X-aws-ec2-metadata-token: $token" \
          "$imds/meta-data/iam/security-credentials/$role"
      )"
      AWS_ACCESS_KEY_ID="$(echo "$creds" | jq -r .AccessKeyId)"
      AWS_SECRET_ACCESS_KEY="$(echo "$creds" | jq -r .SecretAccessKey)"
      AWS_SESSION_TOKEN="$(echo "$creds" | jq -r .Token)"
      export AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY
      export AWS_SESSION_TOKEN
    '';
  };
in {
  options.services.load-ssm = {
    enable = mkEnableOption "load-ssm";

    instanceRole = mkOption {
      type = types.str;
    };

    instanceRegion = mkOption {
      type = types.str;
    };

    secretDir = mkOption {
      type = types.path;
      default = "/secrets";
    };

    secretList = mkOption {
      type = types.listOf types.str;
    };
  };

  config = mkIf cfg.enable {
    systemd.services.load-ssm = {
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ awscli jq util-linux ];
      script = ''
        set -euo pipefail
        source ${aws-login}/bin/aws-login ${esc cfg.instanceRole}

        secret_dir=${escapeShellArg cfg.secretDir}
        if mountpoint -q -- "$secret_dir"; then
          umount "$secret_dir"
        fi
        mkdir -p "$secret_dir"
        mount -t tmpfs -o size=1M tmpfs "$secret_dir"

        while IFS= read -r -d $'\0' parameter; do
          name="$(jq -r '.Name' <<< "$parameter")"
          mkdir -p "$secret_dir/$(dirname "$name")"
          jq -r '.Value' <<< "$parameter" > "$secret_dir/$name"
        done < <(
          aws ssm get-parameters \
            --name ${escapeShellArgs cfg.secretList} \
            --with-decryption \
            --output=json \
            --region=${escapeShellArg cfg.instanceRegion} \
          | jq --raw-output0 '.Parameters[]'
        )
      '';
    };
  };
}
