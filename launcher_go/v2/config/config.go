package config

import (
	"dario.cat/mergo"
	"errors"
	"fmt"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"os"
	"regexp"
	"runtime"
	"slices"
	"strings"

	"gopkg.in/yaml.v3"
)

var DefaultBootCommand = "/sbin/boot"

func DefaultBaseImage() string {
	if runtime.GOARCH == "arm64" {
		return "discourse/base:aarch64"
	}
	return "discourse/base:2.0.20231121-0024"
}

type Config struct {
	Name            string `yaml:-`
	rawYaml         []string
	Base_Image      string            `yaml:,omitempty`
	Update_Pups     bool              `yaml:,omitempty`
	Run_Image       string            `yaml:,omitempty`
	Boot_Command    string            `yaml:,omitempty`
	No_Boot_Command bool              `yaml:,omitempty`
	Docker_Args     string            `yaml:,omitempty`
	Templates       []string          `yaml:templates,omitempty`
	Expose          []string          `yaml:expose,omitempty`
	Params          map[string]string `yaml:params,omitempty`
	Env             map[string]string `yaml:env,omitempty`
	Labels          map[string]string `yaml:labels,omitempty`
	Volumes         []struct {
		Volume struct {
			Host  string `yaml:host`
			Guest string `yaml:guest`
		} `yaml:volume`
	} `yaml:volumes,omitempty`
	Links []struct {
		Link struct {
			Name  string `yaml:name`
			Alias string `yaml:alias`
		} `yaml:link`
	} `yaml:links,omitempty`
}

func (config *Config) loadTemplate(templateDir string, template string) error {
	template_filename := strings.TrimRight(templateDir, "/") + "/" + string(template)
	content, err := os.ReadFile(template_filename)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("template file does not exist: " + template_filename)
		}
		return err
	}
	templateConfig := &Config{}
	if err := yaml.Unmarshal(content, templateConfig); err != nil {
		return err
	}
	if err := mergo.Merge(config, templateConfig, mergo.WithOverride); err != nil {
		return err
	}
	config.rawYaml = append(config.rawYaml, string(content[:]))
	return nil
}

func LoadConfig(dir string, configName string, includeTemplates bool, templatesDir string) (*Config, error) {
	config := &Config{
		Name:         configName,
		Boot_Command: DefaultBootCommand,
		Base_Image:   DefaultBaseImage(),
	}
	matched, _ := regexp.MatchString("[[:upper:]/ !@#$%^&*()+~`=]", configName)
	if matched {
		msg := "ERROR: Config name '" + configName + "' must not contain upper case characters, spaces or special characters. Correct config name and rerun."
		fmt.Println(msg)
		return nil, errors.New(msg)
	}

	config_filename := string(strings.TrimRight(dir, "/") + "/" + config.Name + ".yml")
	content, err := os.ReadFile(config_filename)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("config file does not exist: " + config_filename)
		}
		return nil, err
	}
	baseConfig := &Config{}

	if err := yaml.Unmarshal(content, baseConfig); err != nil {
		return nil, err
	}

	if includeTemplates {
		for _, t := range baseConfig.Templates {
			if err := config.loadTemplate(templatesDir, t); err != nil {
				return nil, err
			}
		}
	}
	if err := mergo.Merge(config, baseConfig, mergo.WithOverride); err != nil {
		return nil, err
	}
	config.rawYaml = append(config.rawYaml, string(content[:]))
	if err != nil {
		return nil, err
	}

	for k, v := range config.Labels {
		val := strings.ReplaceAll(v, "{{config}}", config.Name)
		config.Labels[k] = val
	}

	for k, v := range config.Env {
		val := strings.ReplaceAll(v, "{{config}}", config.Name)
		config.Env[k] = val
	}

	return config, nil
}

func (config *Config) Yaml() string {
	return strings.Join(config.rawYaml, "_FILE_SEPERATOR_")
}

func (config *Config) Dockerfile(pupsArgs string, bakeEnv bool) string {
	builder := strings.Builder{}
	builder.WriteString("ARG dockerfile_from_image=" + config.Base_Image + "\n")
	builder.WriteString("FROM ${dockerfile_from_image}\n")
	builder.WriteString(config.DockerfileArgs() + "\n")
	if bakeEnv {
		builder.WriteString(config.DockerfileEnvs() + "\n")
	}
	builder.WriteString(config.DockerfileExpose() + "\n")
	builder.WriteString("COPY config.yaml /temp-config.yaml\n")
	builder.WriteString("RUN " +
		"cat /temp-config.yaml | /usr/local/bin/pups " + pupsArgs + " --stdin " +
		"&& rm /temp-config.yaml\n")
	builder.WriteString("CMD [\"" + config.BootCommand() + "\"]")
	return builder.String()
}

func (config *Config) WriteYamlConfig(dir string) error {
	file := strings.TrimRight(dir, "/") + "/config.yaml"
	if err := os.WriteFile(file, []byte(config.Yaml()), 0660); err != nil {
		return errors.New("error writing config file " + file)
	}
	return nil
}

func (config *Config) BootCommand() string {
	if len(config.Boot_Command) > 0 {
		return config.Boot_Command
	} else if config.No_Boot_Command {
		return ""
	} else {
		return "/sbin/boot"
	}
}

func (config *Config) EnvArray(includeKnownSecrets bool) []string {
	envs := []string{}
	for k, v := range config.Env {
		if !includeKnownSecrets && slices.Contains(utils.KnownSecrets, k) {
			continue
		}
		envs = append(envs, k+"="+v)
	}
	slices.Sort(envs)
	return envs
}

func (config *Config) DockerfileEnvs() string {
	builder := []string{}
	for k, _ := range config.Env {
		builder = append(builder, "ENV "+k+"=${"+k+"}")
	}
	slices.Sort(builder)
	return strings.Join(builder, "\n")
}

func (config *Config) DockerfileArgs() string {
	builder := []string{}
	for k, _ := range config.Env {
		builder = append(builder, "ARG "+k)
	}
	slices.Sort(builder)
	return strings.Join(builder, "\n")
}

func (config *Config) DockerfileExpose() string {
	builder := []string{}
	for _, p := range config.Expose {
		port := p
		if strings.Contains(p, ":") {
			_, port, _ = strings.Cut(p, ":")
		}
		builder = append(builder, "EXPOSE "+port)
	}
	slices.Sort(builder)
	return strings.Join(builder, "\n")
}
