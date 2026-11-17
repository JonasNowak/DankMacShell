{ config, lib, pkgs, ... }:

let
  cfg = config.programs.dankmacshell;
  xdgConfig = config.xdg.configHome;

  package =
    if cfg.package != null then
      cfg.package
    else
      throw "programs.dankmacshell.package must be set (the flake's homeManagerModules.default sets it automatically)";

  gopPackage = cfg.dmsGop.package;
  dtePackage = cfg.themeEngine.package;

  themeFiles = {
    kitty = "${xdgConfig}/kitty/dms-theme.conf";
    alacritty = "${xdgConfig}/alacritty/dms-theme.toml";
    ghostty = "${xdgConfig}/ghostty/themes/dms";
    tmux = "${xdgConfig}/tmux/dms.conf";
    fish = "${xdgConfig}/fish/conf.d/dms.fish";
    zsh = "${xdgConfig}/zsh/dms.zsh";
    neovim = "${xdgConfig}/nvim/colors/dms.lua";
  };

  targetEnabled = name: (cfg.themeEngine.targets ? ${name}) && cfg.themeEngine.targets.${name}.enable;
  live = name: cfg.themeEngine.enable && cfg.themeEngine.liveInclude && targetEnabled name;

  targetSubmodule =
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "live DMS theme wiring for ${name}" // {
          default = true;
        };
      };
    };
in
{
  options.programs.dankmacshell = {
    enable = lib.mkEnableOption "DankMacShell CLI suite, companion tools, and Home Manager terminal theme wiring";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The DankMacShell package providing `dms` and `dms-symbian`.";
    };

    dmsGop = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the `dms-gop` (`dgop`) system monitor CLI.";
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "The dms-gop package to install.";
      };
    };

    themeEngine = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the `dank-theme-engine` (`dte`) CLI and optional live-include terminal theme pointers.";
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "The dank-theme-engine package to install.";
      };

      liveInclude = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Wire mutable `~/.config/<app>/dms-theme.*` includes into Home Manager terminal/shell configs so DMS can hot-reload themes without touching `/nix/store`.";
      };

      targets = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule targetSubmodule);
        default = { };
        description = "Per-app targets (`kitty`, `ghostty`, `alacritty`, `tmux`, `fish`, `zsh`, `neovim`) to wire with live DMS theme includes.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [ package ]
      ++ lib.optional (cfg.dmsGop.enable && gopPackage != null) gopPackage
      ++ lib.optional (cfg.themeEngine.enable && dtePackage != null) dtePackage;

    programs.kitty.extraConfig = lib.mkIf (live "kitty") (
      lib.mkAfter ''
        include ${themeFiles.kitty}
      ''
    );

    programs.alacritty.settings.general.import = lib.mkIf (live "alacritty") (
      lib.mkAfter [ themeFiles.alacritty ]
    );

    programs.ghostty.settings = lib.mkIf (live "ghostty") {
      config-file = "themes/dms";
    };

    programs.tmux.extraConfig = lib.mkIf (live "tmux") (
      lib.mkAfter ''
        source-file -q ${themeFiles.tmux}
      ''
    );

    programs.fish.interactiveShellInit = lib.mkIf (live "fish") (
      lib.mkAfter ''
        if test -f ${themeFiles.fish}
            source ${themeFiles.fish}
        end
      ''
    );

    programs.zsh.initContent = lib.mkIf (live "zsh") (
      lib.mkAfter ''
        if [ -f ${themeFiles.zsh} ]; then
          source ${themeFiles.zsh}
        fi
      ''
    );

    programs.neovim.extraLuaConfig = lib.mkIf (live "neovim") (
      lib.mkAfter ''
        local dmsTheme = vim.fn.stdpath("config") .. "/colors/dms.lua"
        if vim.fn.filereadable(dmsTheme) == 1 then
          pcall(vim.cmd.colorscheme, "dms")
        end
      ''
    );
  };
}
