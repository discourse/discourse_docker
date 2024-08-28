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
			Expect(cmd.String()).To(Equal(
				"/usr/local/bin/docker run " +
					"--env DISCOURSE_DB_HOST " +
					"--env DISCOURSE_DB_PASSWORD " +
					"--env DISCOURSE_DB_PORT " +
					"--env DISCOURSE_DB_SOCKET " +
					"--env DISCOURSE_DEVELOPER_EMAILS " +
					"--env DISCOURSE_HOSTNAME " +
					"--env DISCOURSE_REDIS_HOST " +
					"--env DISCOURSE_SMTP_ADDRESS " +
					"--env DISCOURSE_SMTP_PASSWORD " +
					"--env DISCOURSE_SMTP_USER_NAME " +
					"--env LANG " +
					"--env LANGUAGE " +
					"--env LC_ALL " +
					"--env MULTI " +
					"--env RAILS_ENV " +
					"--env REPLACED " +
					"--env RUBY_GC_HEAP_GROWTH_MAX_SLOTS " +
					"--env RUBY_GC_HEAP_INIT_SLOTS " +
					"--env RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR " +
					"--env UNICORN_SIDEKIQS " +
					"--env UNICORN_WORKERS " +
					"--env SKIP_EMBER_CLI_COMPILE=1 " +
					"--volume /var/discourse/shared/web-only:/shared " +
					"--volume /var/discourse/shared/web-only/log/var-log:/var/log " +
					"--link data:data " +
					"--shm-size=512m " +
					"--restart=no " +
					"--interactive " +
					"--expose 100 " +
					"--name discourse-build-test " +
					"local_discourse/test /bin/bash -c /usr/local/bin/pups --stdin --tags=db,precompile",
			))

			Expect(cmd.Env).To(Equal([]string{
				"DISCOURSE_DB_HOST=data",
				"DISCOURSE_DB_PASSWORD=SOME_SECRET",
				"DISCOURSE_DB_PORT=",
				"DISCOURSE_DB_SOCKET=",
				"DISCOURSE_DEVELOPER_EMAILS=me@example.com,you@example.com",
				"DISCOURSE_HOSTNAME=discourse.example.com",
				"DISCOURSE_REDIS_HOST=data",
				"DISCOURSE_SMTP_ADDRESS=smtp.example.com",
				"DISCOURSE_SMTP_PASSWORD=pa$$word",
				"DISCOURSE_SMTP_USER_NAME=user@example.com",
				"LANG=en_US.UTF-8",
				"LANGUAGE=en_US.UTF-8",
				"LC_ALL=en_US.UTF-8",
				"MULTI=test\nmultiline with some spaces\nvar\n",
				"RAILS_ENV=production",
				"REPLACED=test/test/test",
				"RUBY_GC_HEAP_GROWTH_MAX_SLOTS=40000",
				"RUBY_GC_HEAP_INIT_SLOTS=400000",
				"RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=1.5",
				"UNICORN_SIDEKIQS=1",
				"UNICORN_WORKERS=3",
			}))

			buf := new(strings.Builder)
			io.Copy(buf, cmd.Stdin)
			// docker run's stdin is a pups config

			// web.template.yml is merged with the test config
			Expect(buf.String()).To(ContainSubstring("path: /etc/service/nginx/run"))
			Expect(buf.String()).To(ContainSubstring(`exec: echo "custom test command"`))
		}

		// commit on configure
		var checkConfigureCommit = func(cmd exec.Cmd) {
			Expect(cmd.String()).To(MatchRegexp(
				"/usr/local/bin/docker commit " +
					`--change LABEL org\.opencontainers\.image\.created="[\d\-T:+]+" ` +
					`--change CMD \["/sbin/boot"\] ` +
					"discourse-build-test local_discourse/test",
			))

			Expect(cmd.Env).To(BeNil())
		}

		// configure also cleans up
		var checkConfigureClean = func(cmd exec.Cmd) {
			Expect(cmd.String()).To(Equal("/usr/local/bin/docker rm --force discourse-build-test"))
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
