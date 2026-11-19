{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  symlinkJoin,
  buildGoModule,
  go_1_27 ? null,
  installShellFiles,
}:

let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  dankmacshell = stdenvNoCC.mkDerivation {
    pname = "dankmacshell";
    version = sources.dankmacshell.version;

    src = fetchurl {
      inherit (sources.dankmacshell) url sha256;
    };

    nativeBuildInputs = [ undmg ];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      cp -R "DankMacShell.app" "$out/Applications/DankMacShell.app"
      ln -sf "DankMacShell.app" "$out/Applications/DankMaterialShell.app"

      if [ -f "$out/Applications/DankMacShell.app/Contents/MacOS/dms" ]; then
        ln -sf "$out/Applications/DankMacShell.app/Contents/MacOS/dms" "$out/bin/dms"
      else
        ln -sf "$out/Applications/DankMacShell.app/Contents/MacOS/DankMaterialShell" "$out/bin/dms"
      fi

      if [ -f "$out/Applications/DankMacShell.app/Contents/MacOS/dms-symbian" ]; then
        ln -sf "$out/Applications/DankMacShell.app/Contents/MacOS/dms-symbian" "$out/bin/dms-symbian"
      fi

      runHook postInstall
    '';

    meta = {
      description = "Native Swift 6 Material Design 3 desktop shell for macOS";
      homepage = "https://github.com/JonasNowak/DankMacShell";
      license = lib.licenses.mit;
      mainProgram = "dms";
      platforms = lib.platforms.darwin;
    };
  };

  goBuilder = if go_1_27 != null then buildGoModule.override { go = go_1_27; } else buildGoModule;

  dms-gop =
    if (sources."dms-gop" ? vendorHash) && sources."dms-gop".vendorHash != null then
      goBuilder (finalAttrs: {
        pname = "dms-gop";
        version = sources."dms-gop".version;
        src = fetchurl {
          inherit (sources."dms-gop") url sha256;
        };
        vendorHash = sources."dms-gop".vendorHash;
        subPackages = [ "cmd/dms-gop" ];
        env.CGO_ENABLED = 0;
        ldflags = [
          "-s"
          "-w"
          "-X main.Version=${finalAttrs.version}"
        ];
        nativeBuildInputs = [ installShellFiles ];
        postInstall = ''
          ln -s dms-gop "$out/bin/dgop"
        '';
        meta = {
          description = "Apple Silicon macOS system monitoring CLI, TUI and REST API";
          homepage = "https://github.com/JonasNowak/dms-gop";
          license = lib.licenses.mit;
          mainProgram = "dms-gop";
          platforms = [ "aarch64-darwin" ];
        };
      })
    else
      stdenvNoCC.mkDerivation {
        pname = "dms-gop";
        version = sources."dms-gop".version;
        src = fetchurl {
          inherit (sources."dms-gop") url sha256;
        };
        sourceRoot = ".";
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/bin"
          if [ -f "dms-gop-darwin-arm64" ]; then
            install -m755 "dms-gop-darwin-arm64" "$out/bin/dms-gop"
          elif [ -f "dms-gop" ]; then
            install -m755 "dms-gop" "$out/bin/dms-gop"
          fi
          ln -sf "dms-gop" "$out/bin/dgop"
          runHook postInstall
        '';
        meta = {
          description = "Apple Silicon macOS system monitoring CLI, TUI and REST API";
          homepage = "https://github.com/JonasNowak/dms-gop";
          license = lib.licenses.mit;
          mainProgram = "dms-gop";
          platforms = [ "aarch64-darwin" ];
        };
      };

  dank-theme-engine = stdenvNoCC.mkDerivation {
    pname = "dank-theme-engine";
    version = sources."dank-theme-engine".version;

    src = fetchurl {
      inherit (sources."dank-theme-engine") url sha256;
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      if [ -f "bin/dte" ]; then
        install -m755 "bin/dte" "$out/bin/dte"
      elif [ -f "dte" ]; then
        install -m755 "dte" "$out/bin/dte"
      fi
      if [ -d "share" ]; then
        cp -R "share" "$out/share"
      fi
      runHook postInstall
    '';

    meta = {
      description = "Dank Theme Engine CLI: Material 3 dynamic color, Dank16 palettes, terminal/theme target sync";
      homepage = "https://github.com/JonasNowak/dank-theme-engine";
      license = lib.licenses.mit;
      mainProgram = "dte";
      platforms = lib.platforms.darwin;
    };
  };

  all = symlinkJoin {
    name = "dankmacshell-suite-${sources.dankmacshell.version}";
    paths = [
      dankmacshell
      dank-theme-engine
    ]
    # dms-gop is aarch64-darwin only; including it on x86_64-darwin breaks evaluation.
    ++ lib.optional stdenvNoCC.hostPlatform.isAarch64 dms-gop;
  };
in
{
  inherit
    dankmacshell
    dms-gop
    dank-theme-engine
    all
    ;
}
