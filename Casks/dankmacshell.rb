# typed: false
# frozen_string_literal: true

cask "dankmacshell" do
  version "0.9.8"
  sha256 "9aefb48e6055496b45641850b1a16a370eed62a9d026ab5d9a9acb034b6def6b"

  url "https://github.com/JonasNowak/DankMacShell/releases/download/v#{version}/DankMacShell-#{version}.dmg"
  name "DankMacShell"
  desc "Material Design 3 desktop shell for macOS"
  homepage "https://github.com/JonasNowak/DankMacShell"

  depends_on macos: ">= :sonoma"
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
