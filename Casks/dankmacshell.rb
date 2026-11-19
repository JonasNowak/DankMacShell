# typed: false
# frozen_string_literal: true

cask "dankmacshell" do
  version "0.8.2"
  sha256 "c68fd4cba9c014cd440ba909bbcee8f3e0ab34b423539661f740494ab438cb36"

  url "https://github.com/JonasNowak/DankMacShell/releases/download/v#{version}/DankMacShell-#{version}.dmg"
  name "DankMacShell"
  desc "Material Design 3 desktop shell for macOS"
  homepage "https://github.com/JonasNowak/DankMacShell"

  depends_on formula: "jonasnowak/dankmac/dank-theme-engine"
  depends_on formula: "jonasnowak/dankmac/dms-gop"

  app "DankMacShell.app"
  binary "#{appdir}/DankMacShell.app/Contents/MacOS/dms"
  binary "#{appdir}/DankMacShell.app/Contents/MacOS/dms-symbian"

  zap trash: [
    "~/Library/Application Support/DMS",
    "~/Library/Caches/DMS",
  ]

  caveats <<~EOS
    To preserve macOS Accessibility & Input Monitoring permissions across updates:
      dms setup-cert

    To start the companion telemetry server:
      brew services start dms-gop
  EOS
end
