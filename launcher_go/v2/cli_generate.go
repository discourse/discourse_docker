package main

import (
	"context"
	"errors"
	"github.com/discourse/discourse_docker/launcher_go/v2/config"
	"os"
)

/*
 * raw-yaml
 * compose
 * args (args, run-image, boot-command, hostname)
 */

type CliGenerate struct {
	DockerCompose DockerComposeCmd `cmd:"" name:"compose" help:"Create docker compose setup in the output {output-directory}/{config}/. The builder generates a docker-compose.yaml, Dockerfile, config.yaml, and an env file for you to source .envrc. Run with 'source .envrc; docker compose up'."`
}

type DockerComposeCmd struct {
	OutputDir string `name:"output dir" default:"./compose" short:"o" help:"Output dir for docker compose files." predictor:"dir"`
	BakeEnv   bool   `short:"e" help:"Bake in the configured environment to image after build."`

	Config string `arg:"" name:"config" help:"config" predictor:"config"`
}

func (r *DockerComposeCmd) Run(cli *Cli, ctx *context.Context) error {
	config, err := config.LoadConfig(cli.ConfDir, r.Config, true, cli.TemplatesDir)
	if err != nil {
		return errors.New("YAML syntax error. Please check your containers/*.yml config files.")
	}
	dir := r.OutputDir + "/" + r.Config
	if err := os.MkdirAll(dir, 0755); err != nil && !os.IsExist(err) {
		return err
	}
	if err := config.WriteDockerCompose(dir, r.BakeEnv); err != nil {
		return err
	}
	return nil
}
