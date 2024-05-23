package main_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bytes"
	"context"
	ddocker "github.com/discourse/discourse_docker/launcher_go/v2"
	. "github.com/discourse/discourse_docker/launcher_go/v2/test_utils"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"io"
	"os"
	"os/exec"
	"strings"
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

		It("Should run docker build with correct arguments", func() {
			runner := ddocker.DockerBuildCmd{Config: "test"}
			runner.Run(cli, &ctx)
			Expect(len(RanCmds)).To(Equal(1))
			checkBuildCmd(RanCmds[0])
		})
	})
})
