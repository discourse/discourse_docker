package main

import (
	"context"
	"errors"
	"flag"
	"os"
	"strings"

	"github.com/discourse/discourse_docker/launcher_go/v2/config"
	"github.com/discourse/discourse_docker/launcher_go/v2/docker"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"github.com/google/uuid"
)

/*
 * build
 * migrate
 * configure
 * bootstrap
 */
type DockerBuildCmd struct {
	BakeEnv bool   `short:"e" help:"Bake in the configured environment to image after build."`
	Tag     string `default:"latest" help:"Resulting image tag."`

	Config string `arg:"" name:"config" help:"configuration" predictor:"config"`
}

func (r *DockerBuildCmd) Run(cli *Cli, ctx *context.Context) error {
	config, err := config.LoadConfig(cli.ConfDir, r.Config, true, cli.TemplatesDir)
	if err != nil {
		return errors.New("YAML syntax error. Please check your containers/*.yml config files.")
	}

	dir := cli.BuildDir + "/" + r.Config
	if err := os.MkdirAll(dir, 0755); err != nil && !os.IsExist(err) {
		return err
	}
	if err := config.WriteYamlConfig(dir); err != nil {
		return err
	}

	pupsArgs := "--skip-tags=precompile,migrate,db"
	builder := docker.DockerBuilder{
		Config:   config,
		Ctx:      ctx,
		Stdin:    strings.NewReader(config.Dockerfile(pupsArgs, r.BakeEnv)),
		Dir:      dir,
		ImageTag: r.Tag,
	}
	if err := builder.Run(); err != nil {
		return err
	}
	cleaner := CleanCmd{Config: r.Config}
	cleaner.Run(cli)

	return nil
}

type DockerConfigureCmd struct {
	Tag    string `default:"latest" help:"Resulting image tag."`
	Config string `arg:"" name:"config" help:"config" predictor:"config"`
}

func (r *DockerConfigureCmd) Run(cli *Cli, ctx *context.Context) error {
	config, err := config.LoadConfig(cli.ConfDir, r.Config, true, cli.TemplatesDir)
	if err != nil {
		return errors.New("YAML syntax error. Please check your containers/*.yml config files.")
	}

	var uuidString string

	if flag.Lookup("test.v") == nil {
		uuidString = uuid.NewString()
	} else {
		uuidString = "test"
	}

	containerId := "discourse-build-" + uuidString

	pups := docker.DockerPupsRunner{
		Config:         config,
		PupsArgs:       "--tags=db,precompile",
		SavedImageName: utils.BaseImageName + r.Config + ":" + r.Tag,
		ExtraEnv:       []string{"SKIP_EMBER_CLI_COMPILE=1"},
		Ctx:            ctx,
		ContainerId:    containerId,
	}

	return pups.Run()
}

type CleanCmd struct {
	Config string `arg:"" name:"config" help:"config to clean" predictor:"config"`
}

func (r *CleanCmd) Run(cli *Cli) error {
	dir := cli.BuildDir + "/" + r.Config
	os.Remove(dir + "/config.yaml")
	if err := os.Remove(dir); err != nil {
		return err
	}
	return nil
}
