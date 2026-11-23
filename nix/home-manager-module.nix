{ config, lib, options, pkgs, ... }:

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
    btop = "${xdgConfig}/btop/themes/dms.theme";
    bat = "${xdgConfig}/bat/themes/dms.tmTheme";
    helix = "${xdgConfig}/helix/themes/dms.toml";
    lazygit = "${xdgConfig}/lazygit/dms-theme.yml";
    # yazi loads ~/.config/yazi/theme.toml automatically, so it needs no HM pointer.
    yazi = "${xdgConfig}/yazi/theme.toml";
  };

  targetEnabled = name: (cfg.themeEngine.targets ? ${name}) && cfg.themeEngine.targets.${name}.enable;
  live = name: cfg.themeEngine.enable && cfg.themeEngine.liveInclude && targetEnabled name;

  # Home Manager declares programs.<tool>.enable for every tool wired below, so
  # in a real Home Manager evaluation the `or true` fallback never fires and the
  # guard is exactly `config.programs.<tool>.enable`. The flake's minimal
  # module-eval harness (flake.nix checks) does not declare those per-tool
  # options; there the fallback keeps the live-include wiring active so the
  # harness can still assert on it.
  toolEnabled = name: config.programs.${name}.enable or true;

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

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Declarative DankMacShell settings. When non-empty, Home Manager writes
        {file}`~/.config/DankMaterialShell/settings.json` via
        {option}`xdg.configFile."DankMaterialShell/settings.json"` as
        {code}`builtins.toJSON` of this attrset. While set, these declarative
        Nix settings replace mutable GUI edits: the file is rewritten on every
        {command}`home-manager switch`, so manage settings here or in the DMS
        GUI, not both. Leave empty ({ }) to keep settings managed purely from
        the GUI. (Optional settingsPath/settingsMode knobs are intentionally not
        modeled; the path is fixed at
        {file}`$XDG_CONFIG_HOME/DankMaterialShell/settings.json` and the file
        mode is Home Manager's default.)
      '';
    };

    dmsGop = {
      enable = lib.mkOption {
        type = lib.types.bool;
        # dms-gop is aarch64-darwin only; default off on x86_64-darwin.
        default = pkgs.stdenv.hostPlatform.isAarch64;
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
        description = ''
          Per-app targets to wire with live DMS theme includes: `kitty`,
          `ghostty`, `alacritty`, `tmux`, `fish`, `zsh`, `neovim` (via the
          matching Home Manager program options), plus `btop`, `bat`, `helix`
          (via their Home Manager program options), `lazygit` (via
          `LG_CONFIG_FILE`) and `yazi` (loads its theme file automatically, no
          pointer needed).
        '';
      };
    };
  };

  # NOTE: the optional blocks below are merged with `//` one level down
  # (under `home` / `programs` / `xdg`), never at the top level: `//` is a
  # shallow merge, so top-level `//` would clobber e.g. `home.packages` with
  # the lazygit block's `home` key.
  config = lib.mkIf cfg.enable {
    home =
      {
        packages =
          [ package ]
          ++ lib.optional (cfg.dmsGop.enable && gopPackage != null) gopPackage
          ++ lib.optional (cfg.themeEngine.enable && dtePackage != null) dtePackage;
      }
      # lazygit has no config include; the engine's documented wiring is
      # LG_CONFIG_FILE listing config.yml plus the engine-written dms-theme.yml.
      # mkDefault lets a user-defined LG_CONFIG_FILE win without merge errors.
      // lib.optionalAttrs ((options.programs ? lazygit) && (options.home ? sessionVariables)) {
        sessionVariables.LG_CONFIG_FILE = lib.mkIf (live "lazygit" && toolEnabled "lazygit") (
          lib.mkDefault "${config.home.homeDirectory}/.config/lazygit/config.yml,${themeFiles.lazygit}"
        );
      };

    programs =
      {
        # Every live-include block is guarded by the tool's own Home Manager
        # `enable` flag so enabling programs.dankmacshell never generates configs
        # for terminals/shells the user did not enable.
        kitty.extraConfig = lib.mkIf (live "kitty" && toolEnabled "kitty") (
          lib.mkAfter ''
            include ${themeFiles.kitty}
          ''
        );

        alacritty.settings.general.import = lib.mkIf (live "alacritty" && toolEnabled "alacritty") (
          lib.mkAfter [ themeFiles.alacritty ]
        );

        ghostty.settings = lib.mkIf (live "ghostty" && toolEnabled "ghostty") {
          config-file = "themes/dms";
        };

        tmux.extraConfig = lib.mkIf (live "tmux" && toolEnabled "tmux") (
          lib.mkAfter ''
            source-file -q ${themeFiles.tmux}
          ''
        );

        fish.interactiveShellInit = lib.mkIf (live "fish" && toolEnabled "fish") (
          lib.mkAfter ''
            if test -f ${themeFiles.fish}
                source ${themeFiles.fish}
            end
          ''
        );

        zsh.initContent = lib.mkIf (live "zsh" && toolEnabled "zsh") (
          lib.mkAfter ''
            if [ -f ${themeFiles.zsh} ]; then
              source ${themeFiles.zsh}
            fi
          ''
        );

        neovim.extraLuaConfig = lib.mkIf (live "neovim" && toolEnabled "neovim") (
          lib.mkAfter ''
            local dmsTheme = vim.fn.stdpath("config") .. "/colors/dms.lua"
            if vim.fn.filereadable(dmsTheme) == 1 then
              pcall(vim.cmd.colorscheme, "dms")
            end
          ''
        );
      }
      # Additional 32-target theme-engine tools with clean Home Manager options.
      # Each block is only emitted when the corresponding HM option exists, and
      # each value is guarded by the tool's own enable flag (see toolEnabled).
      // lib.optionalAttrs (options.programs ? btop) {
        # btop picks the theme via color_theme in btop.conf; the engine writes
        # ~/.config/btop/themes/dms.theme.
        btop.settings.color_theme = lib.mkIf (live "btop" && toolEnabled "btop") "dms";
      }
      // lib.optionalAttrs (options.programs ? bat) {
        # bat config renders as --theme='dms'; the engine writes
        # ~/.config/bat/themes/dms.tmTheme.
        bat.config.theme = lib.mkIf (live "bat" && toolEnabled "bat") "dms";
      }
      // lib.optionalAttrs (options.programs ? helix) {
        # helix settings render as theme = "dms" in config.toml; the engine writes
        # ~/.config/helix/themes/dms.toml.
        helix.settings.theme = lib.mkIf (live "helix" && toolEnabled "helix") "dms";
      };

    # xdg.configFile is only declared by full Home Manager; the flake's minimal
    # eval harness does not declare it, so only wire it when the option exists.
    xdg = lib.optionalAttrs (options.xdg ? configFile) {
      configFile."DankMaterialShell/settings.json" = lib.mkIf (cfg.settings != { }) {
        text = builtins.toJSON cfg.settings;
      };
    };
  };
}
