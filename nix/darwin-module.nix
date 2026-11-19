{ config, lib, pkgs, ... }:

let
  cfg = config.programs.dankmacshell;

  primaryUser = config.system.primaryUser or "";
  homeDir = "/Users/${primaryUser}";
  dmsAppSupport = "${homeDir}/Library/Application Support/DMS";
  themeJsonPath = "${dmsAppSupport}/theme.json";

  package =
    if cfg.package != null then
      cfg.package
    else
      throw "programs.dankmacshell.package must be set (the flake's darwinModules.default sets it automatically)";

  gopPackage = cfg.dmsGop.package;
  dtePackage = cfg.themeEngine.package;

  appInstallPath =
    if cfg.installAppToApplications then
      "/Applications/DankMacShell.app"
    else
      "${package}/Applications/DankMacShell.app";

  agentPath = lib.concatStringsSep ":" (
    lib.optionals (primaryUser != "") [
      "${homeDir}/.local/bin"
      "${homeDir}/.nix-profile/bin"
      "/etc/profiles/per-user/${primaryUser}/bin"
    ]
    ++ [
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/opt/homebrew/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ]
  );

  runAsUser =
    cmd:
    if primaryUser != "" then
      ''
        if [ "$(id -u)" -eq 0 ]; then
          /usr/bin/sudo -u ${lib.escapeShellArg primaryUser} env HOME=${lib.escapeShellArg homeDir} ${cmd}
        else
          ${cmd}
        fi
      ''
    else
      cmd;
in
{
  options.programs.dankmacshell = {
    enable = lib.mkEnableOption "DankMacShell desktop shell ecosystem (DankMacShell.app, dms, dms-symbian, dms-gop, dank-theme-engine)";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The DankMacShell package to install. Set automatically by darwinModules.default.";
    };

    installAppToApplications = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Copy DankMacShell.app into /Applications/DankMacShell.app during activation so macOS TCC and LaunchServices see a stable bundle path.";
    };

    resignWithDmsCert = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run `dms setup-cert` on the installed /Applications/DankMacShell.app bundle during activation so Accessibility & Input Monitoring TCC permissions persist across upgrades.";
    };

    launchd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Register the DankMacShell LaunchAgent (Aqua session) to start at login.";
      };
    };

    dmsGop = {
      enable = lib.mkOption {
        type = lib.types.bool;
        # dms-gop is aarch64-darwin only; default off on x86_64-darwin.
        default = pkgs.stdenv.hostPlatform.isAarch64;
        description = "Install the dms-gop (dgop) companion CLI and optional REST API LaunchAgent.";
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "The dms-gop package to install. Set automatically by darwinModules.default.";
      };

      server = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the dms-gop REST API LaunchAgent (`dms-gop server`).";
        };

        port = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:63484";
          description = "Listen address passed via API_PORT to `dms-gop server`.";
        };
      };
    };

    themeEngine = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the dank-theme-engine (dte) CLI and optional theme watcher LaunchAgent.";
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "The dank-theme-engine package to install. Set automatically by darwinModules.default.";
      };

      launchd = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the dank-theme-engine LaunchAgent (`dte watch`) watching ~/Library/Application Support/DMS/theme.json.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = primaryUser != "" || !(cfg.launchd.enable || cfg.dmsGop.server.enable || cfg.themeEngine.launchd.enable);
        message = "programs.dankmacshell: system.primaryUser must be set when any launchd agent is enabled (launchd.enable, dmsGop.server.enable, or themeEngine.launchd.enable); an empty primaryUser would produce broken /Users//Library/... paths.";
      }
    ];

    environment.systemPackages =
      [ package ]
      ++ lib.optional (cfg.dmsGop.enable && gopPackage != null) gopPackage
      ++ lib.optional (cfg.themeEngine.enable && dtePackage != null) dtePackage;

    system.activationScripts.postActivation.text = lib.mkIf cfg.installAppToApplications ''
      echo "==> Installing DankMacShell.app to /Applications/DankMacShell.app..."
      # Stop any running instance first (bounded wait, then force) so macOS never
      # SIGKILLs a running binary whose bundle files are about to be replaced.
      pkill -x DankMacShell 2>/dev/null || true
      pkill -x DankMaterialShell 2>/dev/null || true
      dms_stop_i=0
      while pgrep -x DankMacShell >/dev/null 2>&1 || pgrep -x DankMaterialShell >/dev/null 2>&1; do
        dms_stop_i=$((dms_stop_i + 1))
        if [ "$dms_stop_i" -ge 20 ]; then
          pkill -9 -x DankMacShell 2>/dev/null || true
          pkill -9 -x DankMaterialShell 2>/dev/null || true
          break
        fi
        sleep 0.1
      done
      rm -rf "/Applications/DankMacShell.app" "/Applications/DankMaterialShell.app"
      /usr/bin/ditto "${package}/Applications/DankMacShell.app" "/Applications/DankMacShell.app"
      chmod -R u+w "/Applications/DankMacShell.app"
      ln -sf "DankMacShell.app" "/Applications/DankMaterialShell.app"
      ${lib.optionalString cfg.resignWithDmsCert (
        runAsUser ''"/Applications/DankMacShell.app/Contents/MacOS/dms" setup-cert "/Applications/DankMacShell.app" || true''
      )}
    '';

    launchd.user.agents.dankmacshell = lib.mkIf cfg.launchd.enable {
      serviceConfig = {
        ProgramArguments = [
          "${appInstallPath}/Contents/MacOS/DankMaterialShell"
        ];
        EnvironmentVariables = {
          PATH = agentPath;
        };
        LimitLoadToSessionType = "Aqua";
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
        ProcessType = "Interactive";
        StandardOutPath = "${homeDir}/Library/Logs/DankMacShell.log";
        StandardErrorPath = "${homeDir}/Library/Logs/DankMacShell.err.log";
      };
    };

    launchd.user.agents.dms-gop = lib.mkIf (cfg.dmsGop.enable && cfg.dmsGop.server.enable && gopPackage != null) {
      serviceConfig = {
        ProgramArguments = [
          "${gopPackage}/bin/dms-gop"
          "server"
        ];
        EnvironmentVariables = {
          API_PORT = cfg.dmsGop.server.port;
          PATH = agentPath;
        };
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = "${homeDir}/Library/Logs/dms-gop.log";
        StandardErrorPath = "${homeDir}/Library/Logs/dms-gop.err.log";
      };
    };

    launchd.user.agents.dank-theme-engine = lib.mkIf (cfg.themeEngine.enable && cfg.themeEngine.launchd.enable && dtePackage != null) {
      serviceConfig = {
        ProgramArguments = [
          "${dtePackage}/bin/dte"
          "watch"
          "--doc"
          themeJsonPath
        ];
        EnvironmentVariables = {
          PATH = agentPath;
        };
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = "${homeDir}/Library/Logs/dank-theme-engine.log";
        StandardErrorPath = "${homeDir}/Library/Logs/dank-theme-engine.err.log";
      };
    };
  };
}
