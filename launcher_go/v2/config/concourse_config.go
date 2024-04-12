package config

import (
	"bytes"
	"errors"
	"os"

	"gopkg.in/yaml.v3"
)

type ConcourseRepo struct {
	Repository string
}
type ConcourseImageResource struct {
	Type   string
	Source ConcourseRepo
}
type ConcourseIo struct {
	Name string
}
type ConcourseRun struct {
	Path string
}
type ConcourseTask struct {
	Params        yaml.Node
	Platform      string
	ImageResource ConcourseImageResource `yaml:"image_resource"`
	Inputs        []ConcourseIo
	Outputs       []ConcourseIo
	Run           ConcourseRun
}

type ConcourseConfig struct {
	Dockerfile    string
	ConcourseTask string `yaml:"concourse_task"`
	Config        string
}

func getConcourseTask(config Config) string {
	content := []*yaml.Node{}
	for k, v := range config.Env {
		key := yaml.Node{
			Kind:  yaml.ScalarNode,
			Tag:   "!!str",
			Value: "BUILD_ARG_" + k,
		}
		val := yaml.Node{
			Kind:  yaml.ScalarNode,
			Tag:   "!!str",
			Value: v,
		}
		content = append(content, &key)
		content = append(content, &val)
	}
	params := yaml.Node{
		Kind:    yaml.MappingNode,
		Tag:     "!!map",
		Content: content,
	}
	concourseTask := &ConcourseTask{
		Platform: "linux",
		Params:   params,
		ImageResource: ConcourseImageResource{
			Type:   "registry-image",
			Source: ConcourseRepo{Repository: "concourse/oci-build-task"},
		},
		Inputs:  []ConcourseIo{ConcourseIo{Name: "docker-config"}, ConcourseIo{Name: "docker-from-image"}},
		Outputs: []ConcourseIo{ConcourseIo{Name: "image"}},
		Run:     ConcourseRun{Path: "build"},
	}
	var b bytes.Buffer
	encoder := yaml.NewEncoder(&b)
	encoder.SetIndent(2)
	encoder.Encode(&concourseTask)
	yaml := b.Bytes()
	return string(yaml)
}

// generates a yaml file containing:
// dockerfile, concoursetask, config
// which may be used in a static concourse resource
// to generate build jobs
func GenConcourseConfig(config Config) string {

	concourseConfig := &ConcourseConfig{
		Dockerfile:    config.Dockerfile("--skip-tags=precompile,migrate,db", false),
		ConcourseTask: getConcourseTask(config),
		Config:        config.Yaml(),
	}

	var b bytes.Buffer
	encoder := yaml.NewEncoder(&b)
	encoder.SetIndent(2)
	encoder.Encode(&concourseConfig)
	yaml := b.Bytes()
	return string(yaml)
}

func WriteConcourseConfig(config Config, file string) error {
	if err := os.WriteFile(file, []byte(GenConcourseConfig(config)), 0660); err != nil {
		return errors.New("error writing concourse job config " + file)
	}
	return nil
}
