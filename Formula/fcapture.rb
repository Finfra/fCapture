class Fcapture < Formula
  desc "macOS screen capture CLI (CoreGraphics) with JSON/YAML presets"
  homepage "https://github.com/Finfra/fCapture"
  url "https://github.com/Finfra/fCapture/archive/refs/tags/v1.0.18.tar.gz"
  # sha256 은 릴리즈 시 주입: curl -sL <url> | shasum -a 256
  sha256 "PLACEHOLDER_FILLED_AT_RELEASE"
  license "PolyForm-Noncommercial-1.0.0"

  depends_on xcode: ["15.0", :build] # swift 5.9 toolchain
  depends_on :macos

  def install
    cd "fCapture" do
      system "swift", "build", "-c", "release", "--disable-sandbox"
      bin.install ".build/release/fCapture" => "fcapture"

      # NOTE: 현재 코드는 리소스를 Bundle.main 으로 접근하나, SPM executable 의
      # Bundle.main 은 .build/release/fCapture_fCapture.bundle 을 인식하지 못함
      # (검증: bundle 옆에서 실행해도 fallback 동작). 모든 리소스 접근 지점이
      # graceful fallback(템플릿 미생성 + 기본값 사용) 이므로 bundle 없이도
      # 캡처 동작에 지장 없음. 단, 향후 코드가 Bundle.module 로 전환되거나
      # ~/.fCapture 템플릿 자동 생성을 보장하려면 아래처럼 bundle 을 바이너리
      # 옆에 동봉해야 한다. 안전장치로 존재 시 함께 설치한다.
      bundle = ".build/release/fCapture_fCapture.bundle"
      bin.install bundle if File.exist?(bundle)
    end
  end

  test do
    assert_match "fCapture", shell_output("#{bin}/fcapture --version")
  end
end
