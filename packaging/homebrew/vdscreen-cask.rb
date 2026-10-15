cask "vdscreen" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "__URL__"
  name "VDScreenBar"
  desc "Create HiDPI virtual displays on macOS (CLI and menu bar app)"
  homepage "https://github.com/lyonDan/vdscreen"

  depends_on arch: :arm64
  depends_on macos: ">= :ventura"

  app "VDScreenBar.app"
  binary "#{appdir}/VDScreenBar.app/Contents/Resources/vdscreen"
end
