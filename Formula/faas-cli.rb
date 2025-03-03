class FaasCli < Formula
  desc "CLI for templating and/or deploying FaaS functions"
  homepage "https://www.openfaas.com/"
  url "https://github.com/openfaas/faas-cli.git",
      tag:      "0.15.7",
      revision: "d18c161602faa95c22ba1c834e1744cc6b9b8a03"
  license "MIT"
  head "https://github.com/openfaas/faas-cli.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "34c37caef68253ee8bd5ff48fef03728e931d3d4d2c9c265fe280d1d9f38cab0"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "256d38c50d9eaad26a92e1ece89de058e882b8c705e3aaf5aa69729ac9d31ee3"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "1e0992c4b30798ad4057d13d39ff603df06da62fc8245726f1b07cfa6d36cf72"
    sha256 cellar: :any_skip_relocation, ventura:        "48b54fc019fe6b518e3d8e12414d0c87a47b42230648834186bc10d1315ab26a"
    sha256 cellar: :any_skip_relocation, monterey:       "bcfc64c361e8fe91f3012c722c0c721e41dc584455a2da25dc9e57485c5ec31d"
    sha256 cellar: :any_skip_relocation, big_sur:        "f8f121ffa4bc4fe72d9bd9404e5c19574295bb0c511583503f87d0dee7fb23e9"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "dc7a86945952a339e72b41c54a1630c5d078a1aa6e2239ee6e985ceac773a82d"
  end

  depends_on "go" => :build

  def install
    ENV["XC_OS"] = OS.kernel_name.downcase
    ENV["XC_ARCH"] = Hardware::CPU.intel? ? "amd64" : Hardware::CPU.arch.to_s
    project = "github.com/openfaas/faas-cli"
    ldflags = %W[
      -s -w
      -X #{project}/version.GitCommit=#{Utils.git_head}
      -X #{project}/version.Version=#{version}
    ]
    system "go", "build", *std_go_args(ldflags: ldflags), "-a", "-installsuffix", "cgo"
    bin.install_symlink "faas-cli" => "faas"

    generate_completions_from_executable(bin/"faas-cli", "completion", "--shell", shells: [:bash, :zsh])
    # make zsh completions also work for `faas` symlink
    inreplace zsh_completion/"_faas-cli", "#compdef faas-cli", "#compdef faas-cli\ncompdef faas=faas-cli"
  end

  test do
    require "socket"

    server = TCPServer.new("localhost", 0)
    port = server.addr[1]
    pid = fork do
      loop do
        socket = server.accept
        response = "OK"
        socket.print "HTTP/1.1 200 OK\r\n" \
                     "Content-Length: #{response.bytesize}\r\n" \
                     "Connection: close\r\n"
        socket.print "\r\n"
        socket.print response
        socket.close
      end
    end

    (testpath/"test.yml").write <<~EOS
      provider:
        name: openfaas
        gateway: https://localhost:#{port}
        network: "func_functions"

      functions:
        dummy_function:
          lang: python
          handler: ./dummy_function
          image: dummy_image
    EOS

    begin
      output = shell_output("#{bin}/faas-cli deploy --tls-no-verify -yaml test.yml 2>&1", 1)
      assert_match "stat ./template/python/template.yml", output

      assert_match "ruby", shell_output("#{bin}/faas-cli template pull 2>&1")
      assert_match "node", shell_output("#{bin}/faas-cli new --list")

      output = shell_output("#{bin}/faas-cli deploy --tls-no-verify -yaml test.yml", 1)
      assert_match "Deploying: dummy_function.", output

      commit_regex = /[a-f0-9]{40}/
      faas_cli_version = shell_output("#{bin}/faas-cli version")
      assert_match commit_regex, faas_cli_version
      assert_match version.to_s, faas_cli_version
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
