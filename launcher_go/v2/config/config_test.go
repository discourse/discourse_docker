package config_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/discourse/discourse_docker/launcher_go/v2/config"
	"os"
	"strings"
)

var _ = Describe("Config", func() {
	var testDir string
	var conf *config.Config
	BeforeEach(func() {
		testDir, _ = os.MkdirTemp("", "ddocker-test")
		conf, _ = config.LoadConfig("../test/containers", "test", true, "../test")
	})
	AfterEach(func() {
		os.RemoveAll(testDir)
	})
	It("should be able to run LoadConfig to load yaml configuration", func() {
		conf, err := config.LoadConfig("../test/containers", "test", true, "../test")
		Expect(err).To(BeNil())
		result := conf.Yaml()
		Expect(result).To(ContainSubstring("DISCOURSE_DEVELOPER_EMAILS: 'me@example.com,you@example.com'"))
		Expect(result).To(ContainSubstring("_FILE_SEPERATOR_"))
		Expect(result).To(ContainSubstring("version: tests-passed"))
	})

	It("can write raw yaml config", func() {
		err := conf.WriteYamlConfig(testDir)
		Expect(err).To(BeNil())
		out, err := os.ReadFile(testDir + "/config.yaml")
		Expect(err).To(BeNil())
		Expect(strings.Contains(string(out[:]), ""))
		Expect(string(out[:])).To(ContainSubstring("DISCOURSE_DEVELOPER_EMAILS: 'me@example.com,you@example.com'"))
	})

	It("can convert pups config to dockerfile format", func() {
		dockerfile := conf.Dockerfile("", false)
		Expect(dockerfile).To(ContainSubstring("ARG DISCOURSE_DEVELOPER_EMAILS"))
		Expect(dockerfile).To(ContainSubstring("RUN cat /temp-config.yaml"))
		Expect(dockerfile).To(ContainSubstring("EXPOSE 80"))
	})

	It("can write env file", func() {
		conf.WriteEnvConfig(testDir)
		out, err := os.ReadFile(testDir + "/.envrc")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("export DISCOURSE_HOSTNAME"))
	})

	It("can write a dockerfile", func() {
		conf.WriteDockerfile(testDir, "", false)
		out, err := os.ReadFile(testDir + "/config.yaml")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("DISCOURSE_DEVELOPER_EMAILS: 'me@example.com,you@example.com'"))
		out, err = os.ReadFile(testDir + "/Dockerfile")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("RUN cat /temp-config.yaml"))
		Expect(string(out[:])).To(ContainSubstring("EXPOSE 80"))
	})

	It("can write a docker compose setup", func() {
		conf.WriteDockerCompose(testDir, false)
		out, err := os.ReadFile(testDir + "/.envrc")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("export DISCOURSE_HOSTNAME"))
		out, err = os.ReadFile(testDir + "/config.yaml")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("DISCOURSE_DEVELOPER_EMAILS: 'me@example.com,you@example.com'"))
		out, err = os.ReadFile(testDir + "/Dockerfile")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("RUN cat /temp-config.yaml"))

		out, err = os.ReadFile(testDir + "/docker-compose.yaml")
		Expect(err).To(BeNil())
		Expect(string(out[:])).To(ContainSubstring("build:"))
		Expect(string(out[:])).To(ContainSubstring("image: local_discourse/test"))
	})

	Context("hostname tests", func() {
		It("replaces hostname", func() {
			config := config.Config{Env: map[string]string{"DOCKER_USE_HOSTNAME": "true", "DISCOURSE_HOSTNAME": "asdfASDF"}}
			Expect(config.DockerHostname("")).To(Equal("asdfASDF"))
		})
		It("replaces hostname", func() {
			config := config.Config{Env: map[string]string{"DOCKER_USE_HOSTNAME": "true", "DISCOURSE_HOSTNAME": "asdf!@#$%^&*()ASDF"}}
			Expect(config.DockerHostname("")).To(Equal("asdf----------ASDF"))
		})
		It("replaces a default hostnamehostname", func() {
			config := config.Config{}
			Expect(config.DockerHostname("asdf!@#")).To(Equal("asdf---"))
		})
	})
})
