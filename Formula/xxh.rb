class Xxh < Formula
  include Language::Python::Virtualenv

  desc "Bring your favorite shell wherever you go through the ssh"
  homepage "https://github.com/xxh/xxh"
  url "https://files.pythonhosted.org/packages/21/10/ecf32b1205e9e5be1eeb0e9f9bac665d1c978d2ae2c8c1c54e2d4945f8f0/xxh-xxh-0.8.8.tar.gz"
  sha256 "0e49dee04455465bf6f77a9fd625f87ec9dae48306dddf423c18a0ef01a2ce1c"
  license "BSD-2-Clause"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_monterey: "1568bf8ddbffef649c1184ab8fd1c8e1add294b15333c2eaba896bc0e3ba4390"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "d9d1f7e84ff619ffc721847256a3cb6621f73d0f50e8a3a9b05b1070faadcbc4"
    sha256 cellar: :any_skip_relocation, monterey:       "c6b94cf93576f3e0c36af9a7214ca791588e3d743560c9cd8ec9419ac460c8c9"
    sha256 cellar: :any_skip_relocation, big_sur:        "eef06592cabd88edf515e64b7814c6a235081522c5789557151b210990b4bb98"
    sha256 cellar: :any_skip_relocation, catalina:       "89a119013535bc9e651ae15037cc926c54d7086acdd66bf0c2490fd189e38b72"
    sha256 cellar: :any_skip_relocation, mojave:         "bad0b4899fb415178eb58559fe81dcf1eb4013431fede475ceea423d14d058f6"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "3684ca87a1a2cba24227fe9615c9a0afdc6de1e80004911d10021a790beb7b98"
  end

  depends_on "python@3.10"

  resource "pexpect" do
    url "https://files.pythonhosted.org/packages/e5/9b/ff402e0e930e70467a7178abb7c128709a30dfb22d8777c043e501bc1b10/pexpect-4.8.0.tar.gz"
    sha256 "fc65a43959d153d0114afe13997d439c22823a27cefceb5ff35c2178c6784c0c"
  end

  resource "ptyprocess" do
    url "https://files.pythonhosted.org/packages/20/e5/16ff212c1e452235a90aeb09066144d0c5a6a8c0834397e03f5224495c4e/ptyprocess-0.7.0.tar.gz"
    sha256 "5c5d0a3b48ceee0b48485e0c26037c0acd7d29765ca3fbb5cb3831d347423220"
  end

  resource "PyYAML" do
    url "https://files.pythonhosted.org/packages/36/2b/61d51a2c4f25ef062ae3f74576b01638bebad5e045f747ff12643df63844/PyYAML-6.0.tar.gz"
    sha256 "68fb519c14306fec9720a2a5b45bc9f0c8d1b9c72adf45c37baedfcd949c35a2"
  end

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xxh --version")

    (testpath/"config.xxhc").write <<~EOS
      hosts:
        test.localhost:
          -o: HostName=127.0.0.1
          +s: xxh-shell-zsh
    EOS
    begin
      port = free_port
      server = TCPServer.new(port)
      server_pid = fork do
        msg = server.accept.gets
        server.close
        assert_match "SSH", msg
      end

      stdout, stderr, = Open3.capture3(
        "#{bin}/xxh", "test.localhost",
        "-p", port.to_s,
        "+xc", "#{testpath}/config.xxhc",
        "+v"
      )

      argv = stdout.lines.grep(/^Final arguments list:/).first.split(":").second
      args = JSON.parse argv.tr("'", "\"")
      assert_includes args, "xxh-shell-zsh"

      ssh_argv = stderr.lines.grep(/^ssh arguments:/).first.split(":").second
      ssh_args = JSON.parse ssh_argv.tr("'", "\"")
      assert_includes ssh_args, "Port=#{port}"
      assert_includes ssh_args, "HostName=127.0.0.1"
      assert_match "Connection closed by remote host", stderr
    ensure
      Process.kill("TERM", server_pid)
    end
  end
end
