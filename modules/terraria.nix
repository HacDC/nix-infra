{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg   = config.services.terraria;
  opt   = options.services.terraria;

  worldSizeMap = { small = 1; medium = 2; large = 3; };
  worldPath = "${cfg.dataDir}/.local/share/Terraria/Worlds/${cfg.worldName}.wld";

  startStript = let
    joinFlags = flags:
      concatStringsSep " " (filter (flag: flag != "") flags);

    valFlag = name: val:
      optionalString (val != null) "-${name} ${escapeShellArg val}";

    boolFlag = name: val:
      optionalString val "-${name}";

    flags = joinFlags [
      "-world ${escapeShellArg worldPath}"
      "-worldname ${escapeShellArg cfg.worldName}"
      (valFlag "autocreate" (getAttr cfg.autoCreatedWorldSize worldSizeMap))

      (valFlag "port" cfg.port)
      (valFlag "maxPlayers" cfg.maxPlayers)
      (if cfg.passwordPath != null
        then "-password \"$(cat ${escapeShellArg cfg.passwordPath})\""
        else (valFlag "password" cfg.password)
      )
      (valFlag "motd" cfg.messageOfTheDay)
      (valFlag "banlist" cfg.banListPath)
      (boolFlag "secure" cfg.secure)
      (boolFlag "noupnp" cfg.noUPnP)
    ];
  in pkgs.writeShellScriptBin "terraria-start" ''
    set -eu
    exec ${pkgs.terraria-server}/bin/TerrariaServer ${flags}
  '';

  stopScript = pkgs.writeShellScriptBin "terraria-stop" ''
    set -eu
    MAINPID="$1"
    echo exit > ${config.systemd.sockets.terraria.socketConfig.ListenFIFO}
    # Wait for the PID of the terraria server to disappear before
    # returning, so systemd doesn't attempt to SIGKILL it.
    while kill -0 "$MAINPID" 2> /dev/null; do
      sleep 1s
    done
  '';
in
{
  disabledModules = [ "services/games/terraria.nix" ];

  options = {
    services.terraria = {
      enable = mkOption {
        type        = types.bool;
        default     = false;
        description = lib.mdDoc ''
          If enabled, starts a Terraria server. The server can be connected to via `tmux -S ''${config.${opt.dataDir}}/terraria.sock attach`
          for administration by users who are a part of the `terraria` group (use `C-b d` shortcut to detach again).
        '';
      };

      port = mkOption {
        type        = types.port;
        default     = 7777;
        description = lib.mdDoc ''
          Specifies the port to listen on.
        '';
      };

      maxPlayers = mkOption {
        type        = types.ints.u8;
        default     = 16;
        description = lib.mdDoc ''
          Sets the max number of players (between 1 and 255).
        '';
      };

      password = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        description = lib.mdDoc ''
          Sets the server password. Leave `null` for no password.
        '';
      };

      passwordPath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = lib.mdDoc ''
          Sets the server password. Leave `null` for no password.
        '';
      };

      messageOfTheDay = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        description = lib.mdDoc ''
          Set the server message of the day text.
        '';
      };

      worldName = mkOption {
        type        = types.str;
        default     = "World";
        description = lib.mdDoc ''
        '';
      };

      autoCreatedWorldSize = mkOption {
        type        = types.enum (attrNames worldSizeMap);
        default     = "medium";
        description = lib.mdDoc ''
          Specifies the size of the auto-created world if `worldPath` does not
          point to an existing world.
        '';
      };

      banListPath = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        description = lib.mdDoc ''
          The path to the ban list.
        '';
      };

      secure = mkOption {
        type        = types.bool;
        default     = false;
        description = lib.mdDoc "Adds additional cheat protection to the server.";
      };

      noUPnP = mkOption {
        type        = types.bool;
        default     = false;
        description = lib.mdDoc "Disables automatic Universal Plug and Play.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc "Whether to open ports in the firewall";
      };

      dataDir = mkOption {
        type        = types.str;
        default     = "/var/lib/terraria";
        example     = "/srv/terraria";
        description = lib.mdDoc "Path to variable state data directory for terraria.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.terraria = {
      description     = "Terraria server service user";
      home            = cfg.dataDir;
      createHome      = true;
      isSystemUser    = true;
      group           = "terraria";
    };
    users.groups.terraria = {};

    systemd.sockets.terraria = {
      bindsTo = [ "terraria.service" ];
      socketConfig = {
        ListenFIFO = "/run/terraria.stdin";
        SocketMode = "0660";
        SocketUser = "terraria";
        SocketGroup = "terraria";
        RemoveOnStop = true;
        FlushPending = true;
      };
    };

    systemd.services.terraria = {
      description   = "Terraria Server Service";
      wantedBy      = [ "multi-user.target" ];
      requires      = [ "terraria.socket" ];
      after         = [ "network.target" "terraria.socket"];

      serviceConfig = {
        ExecStart = "${startStript}/bin/terraria-start";
        ExecStop = "${stopScript}/bin/terraria-stop $MAINPID";
        Restart = "always";
        User = "terraria";
        WorkingDirectory = cfg.dataDir;

        StandardInput = "socket";
        StandardOutput = "journal";
        StandardError = "journal";

        # Hardening
        # Cannot set MemoryDenyWriteExecute due to mono runtime
        CapabilityBoundingSet = [ "" ];
        DeviceAllow = [ "" ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true; # May be implied by NoNewPrivileges
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
