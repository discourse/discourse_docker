package main_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bytes"
	"context"
	"io"
	"os"
	"os/exec"
	"strings"

	ddocker "github.com/discourse/discourse_docker/launcher_go/v2"
	. "github.com/discourse/discourse_docker/launcher_go/v2/test_utils"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
)

var _ = Describe("Build", func() {
	var testDir string
	var out *bytes.Buffer
	var cli *ddocker.Cli
	var ctx context.Context

	BeforeEach(func() {
		utils.DockerPath = "docker"
		out = &bytes.Buffer{}
		utils.Out = out
		testDir, _ = os.MkdirTemp("", "ddocker-test")

		ctx = context.Background()

		cli = &ddocker.Cli{
			ConfDir:      "./test/containers",
			TemplatesDir: "./test",
			BuildDir:     testDir,
		}
		utils.CmdRunner = CreateNewFakeCmdRunner()
	})
	AfterEach(func() {
		os.RemoveAll(testDir)
	})

	Context("When running build commands", func() {
		var checkBuildCmd = func(cmd exec.Cmd) {
			Expect(cmd.String()).To(ContainSubstring("docker build"))
			Expect(cmd.String()).To(ContainSubstring("--build-arg DISCOURSE_DEVELOPER_EMAILS"))
			Expect(cmd.Dir).To(Equal(testDir + "/test"))

			//db password is ignored
			Expect(cmd.Env).ToNot(ContainElement("DISCOURSE_DB_PASSWORD=SOME_SECRET"))
			Expect(cmd.Env).ToNot(ContainElement("DISCOURSEDB_SOCKET="))
			buf := new(strings.Builder)
			io.Copy(buf, cmd.Stdin)
			// docker build's stdin is a dockerfile
			Expect(buf.String()).To(ContainSubstring("COPY config.yaml /temp-config.yaml"))
			Expect(buf.String()).To(ContainSubstring("--skip-tags=precompile,migrate,db"))
			Expect(buf.String()).ToNot(ContainSubstring("SKIP_EMBER_CLI_COMPILE=1"))
		}

		var checkConfigureCmd = func(cmd exec.Cmd) {
			Expect(cmd.String()).To(ContainSubstring("docker run"))
			Expect(cmd.String()).To(ContainSubstring("--env DISCOURSE_DEVELOPER_EMAILS"))
			Expect(cmd.String()).To(ContainSubstring("--env SKIP_EMBER_CLI_COMPILE=1"))
			// we commit, we need the container to stick around after it is stopped.
			Expect(cmd.String()).ToNot(ContainSubstring("--rm"))

			// we don't expose ports on configure command
			Expect(cmd.String()).ToNot(ContainSubstring("-p 80"))
			Expect(cmd.Env).To(ContainElement("DISCOURSE_DB_PASSWORD=SOME_SECRET"))
			buf := new(strings.Builder)
			io.Copy(buf, cmd.Stdin)
			// docker run's stdin is a pups config
			Expect(buf.String()).To(ContainSubstring("path: /etc/service/nginx/run"))
		}

		// commit on configure
		var checkConfigureCommit = func(cmd exec.Cmd) {
			Expect(cmd.String()).To(ContainSubstring("docker commit"))
			Expect(cmd.String()).To(ContainSubstring("--change CMD [\"/sbin/boot\"]"))
			Expect(cmd.String()).To(ContainSubstring("discourse-build"))
			Expect(cmd.String()).To(ContainSubstring("local_discourse/test"))
			Expect(cmd.Env).ToNot(ContainElement("DISCOURSE_DB_PASSWORD=SOME_SECRET"))
		}

		// configure also cleans up
		var checkConfigureClean = func(cmd exec.Cmd) {
			Expect(cmd.String()).To(ContainSubstring("docker rm -f discourse-build-"))
		}

		It("Should run docker build with correct arguments", func() {
			runner := ddocker.DockerBuildCmd{Config: "test"}
			runner.Run(cli, &ctx)
			Expect(len(RanCmds)).To(Equal(1))
			checkBuildCmd(RanCmds[0])
		})

		It("Should run docker run followed by docker commit and rm container when configuring", func() {
			runner := ddocker.DockerConfigureCmd{Config: "test"}
			runner.Run(cli, &ctx)
			Expect(len(RanCmds)).To(Equal(3))
			checkConfigureCmd(RanCmds[0])
			checkConfigureCommit(RanCmds[1])
			checkConfigureClean(RanCmds[2])
		})
	})
})
