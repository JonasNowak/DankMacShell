# typed: false
# frozen_string_literal: true

class DankThemeEngine < Formula
  desc "Material 3 dynamic theming CLI and palette sync engine for macOS"
  homepage "https://github.com/JonasNowak/dank-theme-engine"
  url "https://github.com/JonasNowak/dank-theme-engine/releases/download/v0.1.1/dte-macos-universal.tar.gz"
  sha256 "850ef9a283031dd21706b2724a9332c16fe0129a796a47895c7cb99e8df8c690"
  license "MIT"
  head "https://github.com/JonasNowak/dank-theme-engine.git", branch: "main"

  depends_on :macos

  on_head do
    depends_on "rust" => :build
  end

  def install
    if build.head?
      system "cargo", "install", *std_cargo_args(path: "crates/dte-cli")
      pkgshare.install "templates" if Dir.exist?("templates")
    elsif File.exist?("bin/dte")
      bin.install "bin/dte"
      pkgshare.install Dir["share/dank-theme-engine/*"] if Dir.exist?("share/dank-theme-engine")
    else
      bin.install "dte"
    end
    generate_completions_from_executable(bin/"dte", "completions")
  end

  service do
    run [opt_bin/"dte", "watch"]
    keep_alive true
    process_type :background
    log_path var/"log/dank-theme-engine.log"
    error_log_path var/"log/dank-theme-engine.err.log"
  end

  test do
    assert_match "dte", shell_output("#{bin}/dte --help")
  end
end
