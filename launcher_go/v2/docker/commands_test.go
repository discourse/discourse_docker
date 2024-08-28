package docker_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bytes"
	"context"
	"github.com/discourse/discourse_docker/launcher_go/v2/config"
	"github.com/discourse/discourse_docker/launcher_go/v2/docker"
	. "github.com/discourse/discourse_docker/launcher_go/v2/test_utils"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"strings"
)

var _ = Describe("Commands", func() {
	Context("under normal conditions", func() {
		var conf *config.Config
		var out *bytes.Buffer
		var ctx context.Context

		BeforeEach(func() {
			utils.DockerPath = "docker"
			out = &bytes.Buffer{}
			utils.Out = out
			utils.CommitWait = 0
			conf = &config.Config{Name: "test"}
			ctx = context.Background()
			utils.CmdRunner = CreateNewFakeCmdRunner()
		})
		It("Removes unspecified image tags on commit", func() {
			runner := docker.DockerPupsRunner{Config: conf, ContainerId: "123", Ctx: &ctx, SavedImageName: "local_discourse/test:"}
			runner.Run()
			cmd := GetLastCommand()
			Expect(cmd.String()).To(ContainSubstring("docker run"))
			cmd = GetLastCommand()
			Expect(cmd.String()).To(ContainSubstring("docker commit"))
			Expect(strings.HasSuffix(cmd.String(), ":")).To(BeFalse())
			cmd = GetLastCommand()
			Expect(cmd.String()).To(ContainSubstring("docker rm"))
		})
	})
})
