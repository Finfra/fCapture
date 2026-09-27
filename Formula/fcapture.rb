class Fcapture < Formula
  desc "macOS screen capture CLI (CoreGraphics) with JSON/YAML presets"
  homepage "https://github.com/Finfra/fCapture"
  url "https://github.com/Finfra/fCapture/releases/download/v1.0.18/fCapture-1.0.18.tar.gz"
  version "1.0.18"
  sha256 "4fbba5c9c834838db2b230c7781bd698536fc2e35729ecd05fc271dfb9745cde"
  license "Apache-2.0"

  depends_on :macos

  def install
    bin.install "fcapture"
    prefix.install Dir["LICENSE", "NOTICE", "TRADEMARK.md", "DISTRIBUTION-TERMS.md", "COMMERCIAL.md"]
  end

  def caveats
    <<~EOS
      fCapture 는 화면 녹화 권한이 필요합니다.
        System Settings > Privacy & Security > Screen Recording > 터미널(또는 사용 앱) 허용

      Source code: Apache-2.0. This official build is subject to DISTRIBUTION-TERMS.md:
      free for personal use, education, non-profits, open-source projects, and other organizations up to 250 concurrent copies.
        https://github.com/Finfra/fCapture/blob/main/DISTRIBUTION-TERMS.md
    EOS
  end

  test do
    assert_match "fCapture", shell_output("#{bin}/fcapture --version")
  end
end
