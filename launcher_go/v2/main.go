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
	Version      kong.VersionFlag `help:"Show version."`
	ConfDir      string           `default:"./containers" help:"Discourse pups config directory." predictor:"dir"`
	TemplatesDir string           `default:"." help:"Home project directory containing a templates/ directory which in turn contains pups yaml templates." predictor:"dir"`
	BuildDir     string           `default:"./tmp" help:"Temporary build folder for building images." predictor:"dir"`
	ForceMkdir   bool             `short:"p" name:"parent-dirs" help:"Create intermediate output directories as required.  If this option is not specified, the full path prefix of each operand must already exist."`
	BuildCmd     DockerBuildCmd   `cmd:"" name:"build" help:"Build a base image. This command does not need a running database. Saves resulting container."`
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
