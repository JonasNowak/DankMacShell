# typed: false
# frozen_string_literal: true

cask "dankmacshell" do
  version "0.8.1"
  sha256 "a231b03864cebb4b735a1baa7504e67c1e297cec59ada54ae705c675fc94f863"

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
