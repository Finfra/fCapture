class Fcapture < Formula
  desc "macOS screen capture CLI (CoreGraphics) with JSON/YAML presets"
  homepage "https://github.com/Finfra/fCapture"
  url "https://github.com/Finfra/fCapture/releases/download/v1.0.18/fCapture-1.0.18.tar.gz"
  version "1.0.18"
  sha256 "4fbba5c9c834838db2b230c7781bd698536fc2e35729ecd05fc271dfb9745cde"
  license "PolyForm-Noncommercial-1.0.0"

  depends_on :macos

  def install
    bin.install "fcapture"
  end

  def caveats
    <<~EOS
      fCapture 는 화면 녹화 권한이 필요합니다.
        System Settings > Privacy & Security > Screen Recording > 터미널(또는 사용 앱) 허용

      비상업 사용 무료 / 상업 사용은 별도 라이선스 필요: https://finfra.kr
    EOS
  end

  test do
    assert_match "fCapture", shell_output("#{bin}/fcapture --version")
  end
end
