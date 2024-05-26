package config

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"

	"dario.cat/mergo"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"

	"gopkg.in/yaml.v3"
)

const defaultBootCommand = "/sbin/boot"
const defaultBaseImage = "discourse/base:2.0.20231121-0024"

type DockerComposeYaml struct {
	Services ComposeAppService
	Volumes  map[string]*interface{}
}
type ComposeAppService struct {
	App ComposeService
}
type ComposeService struct {
	Image       string
	Build       ComposeBuild
	Volumes     []string
	Links       []string
	Environment map[string]string
	Ports       []string
}
type ComposeBuild struct {
	Dockerfile string
	Labels     map[string]string
	Shm_Size   string
	Args       []string
	No_Cache   bool
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
		Boot_Command: defaultBootCommand,
		Base_Image:   defaultBaseImage,
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

func (config *Config) WriteDockerCompose(dir string, bakeEnv bool) error {
	if err := config.WriteEnvConfig(dir); err != nil {
		return err
	}
	pupsArgs := "--skip-tags=precompile,migrate,db"
	if err := config.WriteDockerfile(dir, pupsArgs, bakeEnv); err != nil {
		return err
	}
	labels := map[string]string{}
	for k, v := range config.Labels {
		labels[k] = v
	}
	env := map[string]string{}
	for k, v := range config.Env {
		env[k] = v
	}
	env["CREATE_DB_ON_BOOT"] = "1"
	env["MIGRATE_ON_BOOT"] = "1"

	links := []string{}
	for _, v := range config.Links {
		links = append(links, v.Link.Name+":"+v.Link.Alias)
	}
	slices.Sort(links)
	volumes := []string{}
	composeVolumes := map[string]*interface{}{}
	for _, v := range config.Volumes {
		volumes = append(volumes, v.Volume.Host+":"+v.Volume.Guest)
		// if this is a docker volume (vs a bind mount), add to global volume list
		matched, _ := regexp.MatchString(`^[A-Za-z]`, v.Volume.Host)
		if matched {
			composeVolumes[v.Volume.Host] = nil
		}
	}
	slices.Sort(volumes)
	ports := []string{}
	for _, v := range config.Expose {
		ports = append(ports, v)
	}
	slices.Sort(ports)

	args := []string{}
	for k, _ := range config.Env {
		args = append(args, k)
	}
	slices.Sort(args)
	compose := &DockerComposeYaml{
		Services: ComposeAppService{
			App: ComposeService{
				Image: utils.BaseImageName + config.Name,
				Build: ComposeBuild{
					Dockerfile: "./Dockerfile",
					Labels:     labels,
					Shm_Size:   "512m",
					Args:       args,
					No_Cache:   true,
				},
				Environment: env,
				Links:       links,
				Volumes:     volumes,
				Ports:       ports,
			},
		},
		Volumes: composeVolumes,
	}

	var b bytes.Buffer
	encoder := yaml.NewEncoder(&b)
	encoder.SetIndent(2)
	err := encoder.Encode(&compose)
	yaml := b.Bytes()
	if err != nil {
		return errors.New("error marshalling compose file to write docker-compose.yaml")
	}
	if err := os.WriteFile(strings.TrimRight(dir, "/")+"/"+"docker-compose.yaml", yaml, 0660); err != nil {
		return errors.New("error writing compose file docker-compose.yaml")
	}
	return nil
}

func (config *Config) WriteDockerfile(dir string, pupsArgs string, bakeEnv bool) error {
	if err := config.WriteYamlConfig(dir); err != nil {
		return err
	}

	file := strings.TrimRight(dir, "/") + "/" + "Dockerfile"
	if err := os.WriteFile(file, []byte(config.Dockerfile(pupsArgs, bakeEnv)), 0660); err != nil {
		return errors.New("error writing dockerfile Dockerfile " + file)
	}
	return nil
}

func (config *Config) Dockerfile(pupsArgs string, bakeEnv bool) string {
	builder := strings.Builder{}
	builder.WriteString("ARG dockerfile_from_image=" + config.Base_Image + "\n")
	builder.WriteString("FROM ${dockerfile_from_image}\n")
	builder.WriteString(config.dockerfileArgs() + "\n")
	if bakeEnv {
		builder.WriteString(config.dockerfileEnvs() + "\n")
	}
	builder.WriteString(config.dockerfileExpose() + "\n")
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

func (config *Config) WriteEnvConfig(dir string) error {
	file := strings.TrimRight(dir, "/") + "/.envrc"
	if err := os.WriteFile(file, []byte(config.ExportEnv()), 0660); err != nil {
		return errors.New("error writing export env " + file)
	}
	return nil
}

func (config *Config) BootCommand() string {
	if len(config.Boot_Command) > 0 {
		return config.Boot_Command
	} else if config.No_Boot_Command {
		return ""
	} else {
		return defaultBootCommand
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

func (config *Config) DockerArgs() []string {
	return strings.Fields(config.Docker_Args)
}

func (config *Config) ExportEnv() string {
	builder := []string{}
	for k, v := range config.Env {
		val := strings.ReplaceAll(v, "\\", "\\\\")
		val = strings.ReplaceAll(val, "\"", "\\\"")
		builder = append(builder, "export "+k+"=\""+val+"\"")
	}
	slices.Sort(builder)
	return strings.Join(builder, "\n")
}

func (config *Config) dockerfileEnvs() string {
	builder := []string{}
	for k, _ := range config.Env {
		builder = append(builder, "ENV "+k+"=${"+k+"}")
	}
	slices.Sort(builder)
	return strings.Join(builder, "\n")
}

func (config *Config) dockerfileArgs() string {
	builder := []string{}
	for k, _ := range config.Env {
		builder = append(builder, "ARG "+k)
	}
	slices.Sort(builder)
	return strings.Join(builder, "\n")
}

func (config *Config) dockerfileExpose() string {
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

func (config *Config) RunImage() string {
	if len(config.Run_Image) > 0 {
		return config.Run_Image
	}
	return utils.BaseImageName + config.Name
}

func (config *Config) DockerHostname(defaultHostname string) string {
	_, exists := config.Env["DOCKER_USE_HOSTNAME"]
	re := regexp.MustCompile(`[^a-zA-Z-]`)
	hostname := defaultHostname
	if exists {
		hostname = config.Env["DISCOURSE_HOSTNAME"]
	}
	hostname = string(re.ReplaceAll([]byte(hostname), []byte("-"))[:])
	return hostname
}
