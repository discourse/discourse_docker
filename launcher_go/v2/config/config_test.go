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

	It("can convert pups config to dockerfile format and bake in default env", func() {
		dockerfile := conf.Dockerfile("", false)
		Expect(dockerfile).To(ContainSubstring(`FROM ${dockerfile_from_image}
ARG DISCOURSE_DB_HOST
ARG DISCOURSE_DB_PASSWORD
ARG DISCOURSE_DB_PORT
ARG DISCOURSE_DB_SOCKET
ARG DISCOURSE_DEVELOPER_EMAILS
ARG DISCOURSE_HOSTNAME
ARG DISCOURSE_REDIS_HOST
ARG DISCOURSE_SMTP_ADDRESS
ARG DISCOURSE_SMTP_PASSWORD
ARG DISCOURSE_SMTP_USER_NAME
ARG LANG
ARG LANGUAGE
ARG LC_ALL
ARG MULTI
ARG RAILS_ENV
ARG REPLACED
ARG RUBY_GC_HEAP_GROWTH_MAX_SLOTS
ARG RUBY_GC_HEAP_INIT_SLOTS
ARG RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR
ARG UNICORN_SIDEKIQS
ARG UNICORN_WORKERS
ENV RAILS_ENV=${RAILS_ENV}
ENV RUBY_GC_HEAP_GROWTH_MAX_SLOTS=${RUBY_GC_HEAP_GROWTH_MAX_SLOTS}
ENV RUBY_GC_HEAP_INIT_SLOTS=${RUBY_GC_HEAP_INIT_SLOTS}
ENV RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=${RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR}
ENV UNICORN_SIDEKIQS=${UNICORN_SIDEKIQS}
ENV UNICORN_WORKERS=${UNICORN_WORKERS}
EXPOSE 443
EXPOSE 80
EXPOSE 90
COPY config.yaml /temp-config.yaml
RUN cat /temp-config.yaml | /usr/local/bin/pups  --stdin && rm /temp-config.yaml
CMD ["/sbin/boot"]`))
	})

	It("can generate a dockerfile with all env baked into the image", func() {
		dockerfile := conf.Dockerfile("", true)
		Expect(dockerfile).To(ContainSubstring(`FROM ${dockerfile_from_image}
ARG DISCOURSE_DB_HOST
ARG DISCOURSE_DB_PASSWORD
ARG DISCOURSE_DB_PORT
ARG DISCOURSE_DB_SOCKET
ARG DISCOURSE_DEVELOPER_EMAILS
ARG DISCOURSE_HOSTNAME
ARG DISCOURSE_REDIS_HOST
ARG DISCOURSE_SMTP_ADDRESS
ARG DISCOURSE_SMTP_PASSWORD
ARG DISCOURSE_SMTP_USER_NAME
ARG LANG
ARG LANGUAGE
ARG LC_ALL
ARG MULTI
ARG RAILS_ENV
ARG REPLACED
ARG RUBY_GC_HEAP_GROWTH_MAX_SLOTS
ARG RUBY_GC_HEAP_INIT_SLOTS
ARG RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR
ARG UNICORN_SIDEKIQS
ARG UNICORN_WORKERS
ENV DISCOURSE_DB_HOST=${DISCOURSE_DB_HOST}
ENV DISCOURSE_DB_PASSWORD=${DISCOURSE_DB_PASSWORD}
ENV DISCOURSE_DB_PORT=${DISCOURSE_DB_PORT}
ENV DISCOURSE_DB_SOCKET=${DISCOURSE_DB_SOCKET}
ENV DISCOURSE_DEVELOPER_EMAILS=${DISCOURSE_DEVELOPER_EMAILS}
ENV DISCOURSE_HOSTNAME=${DISCOURSE_HOSTNAME}
ENV DISCOURSE_REDIS_HOST=${DISCOURSE_REDIS_HOST}
ENV DISCOURSE_SMTP_ADDRESS=${DISCOURSE_SMTP_ADDRESS}
ENV DISCOURSE_SMTP_PASSWORD=${DISCOURSE_SMTP_PASSWORD}
ENV DISCOURSE_SMTP_USER_NAME=${DISCOURSE_SMTP_USER_NAME}
ENV LANG=${LANG}
ENV LANGUAGE=${LANGUAGE}
ENV LC_ALL=${LC_ALL}
ENV MULTI=${MULTI}
ENV RAILS_ENV=${RAILS_ENV}
ENV REPLACED=${REPLACED}
ENV RUBY_GC_HEAP_GROWTH_MAX_SLOTS=${RUBY_GC_HEAP_GROWTH_MAX_SLOTS}
ENV RUBY_GC_HEAP_INIT_SLOTS=${RUBY_GC_HEAP_INIT_SLOTS}
ENV RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=${RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR}
ENV UNICORN_SIDEKIQS=${UNICORN_SIDEKIQS}
ENV UNICORN_WORKERS=${UNICORN_WORKERS}
EXPOSE 443
EXPOSE 80
EXPOSE 90
COPY config.yaml /temp-config.yaml
RUN cat /temp-config.yaml | /usr/local/bin/pups  --stdin && rm /temp-config.yaml
CMD ["/sbin/boot"]`))
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
