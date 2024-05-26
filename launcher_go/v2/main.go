package main

import (
	"context"
	"fmt"
	"github.com/alecthomas/kong"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"golang.org/x/sys/unix"
	"os"
	"os/exec"
	"os/signal"
)

type Cli struct {
	Version      kong.VersionFlag   `help:"Show version."`
	ConfDir      string             `default:"./containers" hidden:"" help:"Discourse pups config directory." predictor:"dir"`
	TemplatesDir string             `default:"." hidden:"" help:"Home project directory containing a templates/ directory which in turn contains pups yaml templates." predictor:"dir"`
	BuildDir     string             `default:"./tmp" hidden:"" help:"Temporary build folder for building images." predictor:"dir"`
	BuildCmd     DockerBuildCmd     `cmd:"" name:"build" help:"Build a base image. This command does not need a running database. Saves resulting container."`
	ConfigureCmd DockerConfigureCmd `cmd:"" name:"configure" help:"Configure and save an image with all dependencies and environment baked in. Updates themes and precompiles all assets. Saves resulting container."`
	MigrateCmd   DockerMigrateCmd   `cmd:"" name:"migrate" help:"Run migration tasks for a site. Running container is temporary and is not saved."`
	BootstrapCmd DockerBootstrapCmd `cmd:"" name:"bootstrap" help:"Builds, migrates, and configures an image. Resulting image is a fully built and configured Discourse image."`
}

func main() {
	cli := Cli{}
	runCtx, cancel := context.WithCancel(context.Background())

	parser := kong.Must(&cli, kong.UsageOnError(), kong.Bind(&runCtx), kong.Vars{"version": utils.Version})

	ctx, err := parser.Parse(os.Args[1:])
	parser.FatalIfErrorf(err)

	defer cancel()
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, unix.SIGTERM)
	signal.Notify(sigChan, unix.SIGINT)
	done := make(chan struct{})
	defer close(done)
	go func() {
		select {
		case <-sigChan:
			fmt.Fprintln(utils.Out, "Command interrupted")
			cancel()
		case <-done:
		}
	}()
	err = ctx.Run()
	if err == nil {
		return
	}
	if exiterr, ok := err.(*exec.ExitError); ok {
		// Magic exit code that indicates a retry
		if exiterr.ExitCode() == 77 {
			os.Exit(77)
		} else if runCtx.Err() != nil {
			fmt.Fprintln(utils.Out, "Aborted with exit code", exiterr.ExitCode())
		} else {
			ctx.Fatalf(
				"run failed with exit code %v\n"+
					"** FAILED TO BOOTSTRAP ** please scroll up and look for earlier error messages, there may be more than one.\n"+
					"./discourse-doctor may help diagnose the problem.", exiterr.ExitCode())
		}
	} else {
		ctx.FatalIfErrorf(err)
	}
}
