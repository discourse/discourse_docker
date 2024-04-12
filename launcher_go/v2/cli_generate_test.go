package main_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bytes"
	"context"
	ddocker "github.com/discourse/discourse_docker/launcher_go/v2"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"os"
)

var _ = Describe("Generate", func() {
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
	})
	AfterEach(func() {
		os.RemoveAll(testDir)
	})

	It("should allow concatenated templates", func() {
		runner := ddocker.RawYamlCmd{Config: "test"}
		runner.Run(cli)
		Expect(out.String()).To(ContainSubstring("DISCOURSE_DEVELOPER_EMAILS: 'me@example.com,you@example.com'"))
		Expect(out.String()).To(ContainSubstring("_FILE_SEPERATOR_"))
		Expect(out.String()).To(ContainSubstring("version: tests-passed"))
	})

	It("should output docker compose cmd to config name's subdir", func() {
		runner := ddocker.DockerComposeCmd{Config: "test",
			OutputDir: testDir}
		err := runner.Run(cli, &ctx)
		Expect(err).To(BeNil())
		out, err := os.ReadFile(testDir + "/test/config.yaml")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("DISCOURSE_DEVELOPER_EMAILS: 'me@example.com,you@example.com'"))
	})

	It("does not create output parent folders when not asked", func() {
		runner := ddocker.DockerComposeCmd{Config: "test",
			OutputDir: testDir + "/subfolder/sub-subfolder"}
		err := runner.Run(cli, &ctx)
		Expect(err).ToNot(BeNil())
		_, err = os.ReadFile(testDir + "/subfolder/sub-subfolder/test/config.yaml")
		Expect(err).ToNot(BeNil())
	})

	It("should force create output parent folders when asked", func() {
		runner := ddocker.DockerComposeCmd{Config: "test",
			OutputDir: testDir + "/subfolder/sub-subfolder"}
		cli.ForceMkdir = true
		err := runner.Run(cli, &ctx)
		Expect(err).To(BeNil())
		out, err := os.ReadFile(testDir + "/subfolder/sub-subfolder/test/config.yaml")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("DISCOURSE_DEVELOPER_EMAILS: 'me@example.com,you@example.com'"))
	})
})
