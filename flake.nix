{
  description = "DankMacShell (DMS): Native Swift 6 Material Design 3 desktop shell for macOS with dms-gop & dank-theme-engine";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

      forEachSystem = f: lib.genAttrs systems (system: f (pkgsFor system));
    in
    {
      packages = forEachSystem (
        pkgs:
        let
          suite = pkgs.callPackage ./nix/package.nix { };
        in
        {
          inherit (suite)
            dankmacshell
            dms-gop
            dank-theme-engine
            all
            ;
          default = suite.dankmacshell;
        }
      );

      overlays.default =
        final: _prev:
        let
          suite = final.callPackage ./nix/package.nix { };
        in
        {
          inherit (suite)
            dankmacshell
            dms-gop
            dank-theme-engine
            ;
        };

      darwinModules.default =
        { lib, pkgs, ... }:
        let
          sysPkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          imports = [ ./nix/darwin-module.nix ];
          programs.dankmacshell.package = lib.mkDefault sysPkgs.dankmacshell;
          programs.dankmacshell.dmsGop.package = lib.mkDefault sysPkgs.dms-gop;
          programs.dankmacshell.themeEngine.package = lib.mkDefault sysPkgs.dank-theme-engine;
        };

      homeManagerModules.default =
        { lib, pkgs, ... }:
        let
          sysPkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          imports = [ ./nix/home-manager-module.nix ];
          programs.dankmacshell.package = lib.mkDefault sysPkgs.dankmacshell;
          programs.dankmacshell.dmsGop.package = lib.mkDefault sysPkgs.dms-gop;
          programs.dankmacshell.themeEngine.package = lib.mkDefault sysPkgs.dank-theme-engine;
        };

      checks = forEachSystem (pkgs: {
        nix-syntax = pkgs.runCommand "dankmacshell-nix-syntax" { } ''
          for f in ${./flake.nix} ${./nix/package.nix} ${./nix/darwin-module.nix} ${./nix/home-manager-module.nix}; do
            ${pkgs.nix}/bin/nix-instantiate --parse "$f" > /dev/null
          done
          touch "$out"
        '';

        module-options =
          let
            sysPkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
            evalHM =
              extra:
              lib.evalModules {
                modules = [
                  ./nix/home-manager-module.nix
                  (
                    { lib, ... }:
                    {
                      options = {
                        xdg.configHome = lib.mkOption {
                          type = lib.types.str;
                          default = "/tmp/.config";
                        };
                        home.packages = lib.mkOption {
                          type = lib.types.listOf lib.types.package;
                          default = [ ];
                        };
                        programs.kitty.extraConfig = lib.mkOption {
                          type = lib.types.lines;
                          default = "";
                        };
                        programs.alacritty.settings = lib.mkOption {
                          type = lib.types.attrsOf lib.types.anything;
                          default = { };
                        };
                        programs.ghostty.settings = lib.mkOption {
                          type = lib.types.attrsOf lib.types.anything;
                          default = { };
                        };
                        programs.tmux.extraConfig = lib.mkOption {
                          type = lib.types.lines;
                          default = "";
                        };
                        programs.fish.interactiveShellInit = lib.mkOption {
                          type = lib.types.lines;
                          default = "";
                        };
                        programs.zsh.initContent = lib.mkOption {
                          type = lib.types.lines;
                          default = "";
                        };
                        programs.neovim.extraLuaConfig = lib.mkOption {
                          type = lib.types.lines;
                          default = "";
                        };
                      };
                    }
                  )
                  (
                    { ... }:
                    {
                      programs.dankmacshell = lib.recursiveUpdate {
                        enable = true;
                        package = sysPkgs.dankmacshell;
                        dmsGop = {
                          enable = true;
                          package = sysPkgs.dms-gop;
                        };
                        themeEngine.package = sysPkgs.dank-theme-engine;
                      } extra;
                    }
                  )
                ];
                specialArgs = { inherit pkgs; };
              };
            hmEval = evalHM {
              themeEngine.targets = {
                kitty.enable = true;
                ghostty.enable = true;
                tmux.enable = true;
              };
            };
            darwinEval = lib.evalModules {
              modules = [
                ./nix/darwin-module.nix
                (
                  { lib, ... }:
                  {
                    options = {
                      assertions = lib.mkOption {
                        type = lib.types.listOf lib.types.anything;
                        default = [ ];
                      };
                      system.primaryUser = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = "tester";
                      };
                      environment.systemPackages = lib.mkOption {
                        type = lib.types.listOf lib.types.package;
                        default = [ ];
                      };
                      system.activationScripts.postActivation.text = lib.mkOption {
                        type = lib.types.lines;
                        default = "";
                      };
                      launchd.user.agents = lib.mkOption {
                        type = lib.types.attrsOf lib.types.anything;
                        default = { };
                      };
                    };
                    config.programs.dankmacshell = {
                      enable = true;
                      package = sysPkgs.dankmacshell;
                      dmsGop = {
                        enable = true;
                        package = sysPkgs.dms-gop;
                      };
                      themeEngine = {
                        package = sysPkgs.dank-theme-engine;
                        launchd.enable = true;
                      };
                    };
                  }
                )
              ];
              specialArgs = { inherit pkgs; };
            };
          in
          pkgs.runCommand "dankmacshell-module-options" { } ''
            test "${toString (builtins.length hmEval.config.home.packages)}" -eq 3
            test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext hmEval.config.programs.kitty.extraConfig)}
            test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext hmEval.config.programs.tmux.extraConfig)}
            test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext darwinEval.config.system.activationScripts.postActivation.text)}
            test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext darwinEval.config.launchd.user.agents.dankmacshell.serviceConfig.EnvironmentVariables.PATH)}
            test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext darwinEval.config.launchd.user.agents.dms-gop.serviceConfig.EnvironmentVariables.API_PORT)}
            test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext darwinEval.config.launchd.user.agents.dank-theme-engine.serviceConfig.EnvironmentVariables.PATH)}
            touch "$out"
          '';

        package-eval = pkgs.runCommand "dankmacshell-package-eval" { } ''
          test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext self.packages.${pkgs.stdenv.hostPlatform.system}.default.drvPath)}
          test -n ${lib.escapeShellArg (builtins.unsafeDiscardStringContext self.packages.${pkgs.stdenv.hostPlatform.system}.all.drvPath)}
          touch "$out"
        '';
      });
    };
}
