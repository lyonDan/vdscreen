class Vdscreen < Formula
  desc "Create HiDPI virtual displays on macOS (CLI and menu bar app)"
  homepage "https://github.com/lyonDan/vdscreen"
  url "__URL__"
  sha256 "__SHA256__"
  license "MIT"

  depends_on :macos

  def install
    # 本机编译，不涉及下载二进制，也就不会被 Gatekeeper 隔离
    ENV["VERSION"] = version.to_s
    system "./build.sh"
    libexec.install "vdscreen", "vdscreen-core"
    # 用 opt 路径而非带版本号的 Cellar 路径：LaunchAgent 会记下核心路径，升级后不能失效
    (bin/"vdscreen").write <<~SH
      #!/bin/sh
      exec "#{opt_libexec}/vdscreen" "$@"
    SH
    prefix.install "VDScreenBar.app"
  end

  def caveats
    <<~EOS
      菜单栏 App 已编译在：
        #{opt_prefix}/VDScreenBar.app
      想要它出现在启动台 / 应用程序里：
        cp -R #{opt_prefix}/VDScreenBar.app ~/Applications/
    EOS
  end

  test do
    assert_match "vdscreen", shell_output("#{bin}/vdscreen help")
  end
end
