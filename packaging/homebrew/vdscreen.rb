class Vdscreen < Formula
  desc "Create HiDPI virtual displays on macOS (CLI and menu bar app)"
  homepage "https://github.com/lyonDan/vdscreen"
  version "__VERSION__"
  url "__URL__"
  sha256 "__SHA256__"
  license "MIT"

  depends_on :macos
  depends_on arch: :arm

  def install
    # 直接安装 Release 预编译包（Developer ID 签名 + Apple 公证），不做本机编译
    app = "VDScreenBar.app"
    # Homebrew 解压时会去掉 zip 唯一的顶层目录，恢复 App bundle 的目录结构。
    if File.directory?("Contents")
      mkdir app
      mv "Contents", app
    end
    # 复制而非移走资源，保留 App 的签名完整性。
    libexec.mkpath
    cp "#{app}/Contents/Resources/vdscreen", libexec
    cp "#{app}/Contents/Resources/vdscreen-core", libexec
    # 用 opt 路径而非带版本号的 Cellar 路径：LaunchAgent 会记下核心路径，升级后不能失效
    (bin/"vdscreen").write <<~SH
      #!/bin/sh
      exec "#{opt_libexec}/vdscreen" "$@"
    SH
    prefix.install app
  end

  def caveats
    <<~EOS
      菜单栏 App 已安装在：
        #{opt_prefix}/VDScreenBar.app
      想要它出现在启动台 / 应用程序里：
        cp -R #{opt_prefix}/VDScreenBar.app ~/Applications/
    EOS
  end

  test do
    assert_match "vdscreen", shell_output("#{bin}/vdscreen help")
  end
end
