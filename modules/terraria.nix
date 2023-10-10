{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg   = config.services.terraria;
  opt   = options.services.terraria;
  worldSizeMap = { small = 1; medium = 2; large = 3; };
  valFlag = name: val: optionalString (val != null) "-${name} ${escapeShellArg val}";
  boolFlag = name: val: optionalString val "-${name}";
  flags = [
    (valFlag "port" cfg.port)
    (valFlag "maxPlayers" cfg.maxPlayers)
    (if cfg.passwordFile != null
      then "-password \"$(cat ${escapeShellArg cfg.passwordFile})\""
      else valFlag cfg.password
    )
    (valFlag "motd" cfg.messageOfTheDay)
    (valFlag "world" cfg.worldPath)
    (valFlag "autocreate" (builtins.getAttr cfg.autoCreatedWorldSize worldSizeMap))
    (valFlag "banlist" cfg.banListPath)
    (boolFlag "secure" cfg.secure)
    (boolFlag "noupnp" cfg.noUPnP)
  ];
in
{
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
        default     = 255;
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
      passwordFile = mkOption {
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

      worldPath = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        description = lib.mdDoc ''
          The path to the world file (`.wld`) which should be loaded.
          If no world exists at this path, one will be created with the size
          specified by `autoCreatedWorldSize`.
        '';
      };

      autoCreatedWorldSize = mkOption {
        type        = types.enum [ "small" "medium" "large" ];
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
    systemd.services.terraria = {
      description   = "Terraria Server Service";
      wantedBy      = [ "multi-user.target" ];
      after         = [ "network.target" ];

      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "terraria";
        UMask = "0007";
        ExecStart = let
          tmux = "${pkgs.tmux}/bin/tmux -S ${cfg.dataDir}/terraria.sock";
          startScript = pkgs.writeScript "terraria-start" ''
            #!${pkgs.runtimeShell}
            set -euo pipefail
            # Need job control for tmux
            set -m

            cd ${escapeShellArg cfg.dataDir}
            export HOME=${escapeShellArg cfg.dataDir}
            ${tmux} -D &
            ${tmux} new -d ${pkgs.terraria-server}/bin/TerrariaServer ${concatStringsSep " " flags}
            ${tmux} set-option exit-empty on
            ${pkgs.coreutils}/bin/chmod 660 ${cfg.dataDir}/terraria.sock
            fg
          '';
        in startScript;
        ExecStop = "${pkgs.tmux}/bin/tmux -S ${cfg.dataDir}/terraria.sock send-keys Enter exit Enter";

        # Sandboxing
        # NoNewPrivileges = true;
        # MemoryDenyWriteExecute = true;
        # ^ Both of these cause this to fail, probably because of the mono
        # runtime
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
        RestrictRealtime = true;
        RestrictNamespaces = true;
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };

  };
}
