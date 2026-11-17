# typed: false
# frozen_string_literal: true

class DmsGop < Formula
  desc "Apple Silicon macOS system monitoring CLI, TUI and REST API"
  homepage "https://github.com/JonasNowak/dms-gop"
  url "https://github.com/JonasNowak/dms-gop/archive/f8cb7bba68a92c8e000ce0e1427ba110e2026ff1.tar.gz"
  version "2.1.0"
  sha256 "087680f688abdd2f25ef09e227a9f966797ebc14af7ec2b4020eecf30a5cce25"
  license "MIT"
  head "https://github.com/JonasNowak/dms-gop.git", branch: "master"

  depends_on "go" => :build
  depends_on arch: :arm64
  depends_on :macos

  def install
    if File.exist?("dms-gop-darwin-arm64")
      bin.install "dms-gop-darwin-arm64" => "dms-gop"
    else
      ldflags = "-s -w -X main.Version=#{version}"
      system "go", "build", *std_go_args(ldflags: ldflags, output: bin/"dms-gop"), "./cmd/dms-gop"
    end
    bin.install_symlink "dms-gop" => "dgop"
    generate_completions_from_executable(bin/"dms-gop", "completion")
  end

  service do
    run [opt_bin/"dms-gop", "server"]
    environment_variables API_PORT: ":63484"
    keep_alive true
    process_type :background
    log_path var/"log/dms-gop.log"
    error_log_path var/"log/dms-gop.err.log"
  end

  test do
    assert_match "dms-gop", shell_output("#{bin}/dms-gop --help")
  end
end
