# Homebrew formula 模板：从源码编译（release 流程会填入 url / sha256，产物是 release 里的 vdscreen.rb）
# 放进 tap 仓库（lyonDan/homebrew-tap 的 Formula/ 目录）后：brew install lyonDan/tap/vdscreen
class Vdscreen < Formula
  desc "用私有 CGVirtualDisplay API 创建 HiDPI 虚拟显示器（CLI + 菜单栏 App）"
  homepage "https://github.com/lyonDan/vdscreen"
  url "__URL__"
  sha256 "__SHA256__"
  license "MIT"

  depends_on :macos

  def install
    # 本机编译，不涉及下载二进制，也就不会被 Gatekeeper 隔离
    system "./build.sh"
    libexec.install "vdscreen", "vdscreen-core"
    bin.write_exec_script libexec/"vdscreen"   # 保持 vdscreen 与 vdscreen-core 同目录
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
