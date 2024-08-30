package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"syscall"
	"time"

	"github.com/discourse/discourse_docker/launcher_go/v2/config"
	"github.com/discourse/discourse_docker/launcher_go/v2/docker"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"

	"golang.org/x/sys/unix"
)

/*
 * start
 * run
 * stop
 * cleanup
 * destroy
 * logs
 * enter
 * rebuild
 * restart
 */

type StartCmd struct {
	Config     string `arg:"" name:"config" help:"config" predictor:"config"`
	DryRun     bool   `name:"dry-run" short:"n" help:"Do not start, print docker start command and exit."`
	DockerArgs string `name:"docker-args" help:"Extra arguments to pass when running docker."`
	RunImage   string `name:"run-image" help:"Start with a custom image."`
	Supervised bool   `name:"supervised" env:"SUPERVISED" help:"Attach the running container on start."`

	extraEnv []string
}

func (r *StartCmd) Run(cli *Cli, ctx *context.Context) error {
	//start stopped container first if exists
	running, _ := docker.ContainerRunning(r.Config)

	if running && !r.DryRun {
		fmt.Fprintln(utils.Out, "Nothing to do, your container has already started!")
		return nil
	}

	exists, _ := docker.ContainerExists(r.Config)

	if exists && !r.DryRun {
		fmt.Fprintln(utils.Out, "starting up existing container")
		cmd := exec.CommandContext(*ctx, utils.DockerPath, "start", r.Config)

		if r.Supervised {
			cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}

			cmd.Cancel = func() error {
				if runtime.GOOS == "darwin" {
					runCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
					stopCmd := exec.CommandContext(runCtx, utils.DockerPath, "stop", r.Config)
					utils.CmdRunner(stopCmd).Run()
					cancel()
				}
				return unix.Kill(-cmd.Process.Pid, unix.SIGINT)
			}

			cmd.Args = append(cmd.Args, "--attach")
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
		}

		fmt.Fprintln(utils.Out, cmd)

		if err := utils.CmdRunner(cmd).Run(); err != nil {
			return err
		}

		return nil
	}

	config, err := config.LoadConfig(cli.ConfDir, r.Config, true, cli.TemplatesDir)

	if err != nil {
		return errors.New("YAML syntax error. Please check your containers/*.yml config files.")
	}

	defaultHostname, _ := os.Hostname()
	defaultHostname = defaultHostname + "-" + r.Config
	hostname := config.DockerHostname(defaultHostname)

	restart := true
	detatch := true

	if r.Supervised {
		restart = false
		detatch = false
	}

	extraFlags := strings.Fields(r.DockerArgs)
	bootCmd := config.BootCommand()

	runner := docker.DockerRunner{
		Config:      config,
		Ctx:         ctx,
		ContainerId: r.Config,
		DryRun:      r.DryRun,
		CustomImage: r.RunImage,
		Restart:     restart,
		Detatch:     detatch,
		ExtraFlags:  extraFlags,
		ExtraEnv:    r.extraEnv,
		Hostname:    hostname,
		Cmd:         []string{bootCmd},
	}

	fmt.Fprintln(utils.Out, "starting new container...")
	return runner.Run()
}

type RunCmd struct {
	RunImage   string   `name:"run-image" help:"Override the image used for running the container."`
	DockerArgs string   `name:"docker-args" help:"Extra arguments to pass when running docker"`
	Config     string   `arg:"" name:"config" help:"config" predictor:"config"`
	Cmd        []string `arg:"" help:"command to run" passthrough:""`
}

func (r *RunCmd) Run(cli *Cli, ctx *context.Context) error {
	config, err := config.LoadConfig(cli.ConfDir, r.Config, true, cli.TemplatesDir)
	if err != nil {
		return errors.New("YAML syntax error. Please check your containers/*.yml config files.")
	}
	extraFlags := strings.Fields(r.DockerArgs)
	runner := docker.DockerRunner{
		Config:      config,
		Ctx:         ctx,
		CustomImage: r.RunImage,
		SkipPorts:   true,
		Rm:          true,
		Cmd:         r.Cmd,
		ExtraFlags:  extraFlags,
	}
	return runner.Run()
	return nil
}

type StopCmd struct {
	Config string `arg:"" name:"config" help:"config" predictor:"config"`
}

func (r *StopCmd) Run(cli *Cli, ctx *context.Context) error {
	exists, _ := docker.ContainerExists(r.Config)
	if !exists {
		fmt.Fprintln(utils.Out, r.Config+" was not found")
		return nil
	}
	cmd := exec.CommandContext(*ctx, "docker", "stop", "--time", "600", r.Config)
	fmt.Fprintln(utils.Out, cmd)
	if err := utils.CmdRunner(cmd).Run(); err != nil {
		return err
	}
	return nil
}

type RestartCmd struct {
	Config     string `arg:"" name:"config" help:"config" predictor:"config"`
	DockerArgs string `name:"docker-args" help:"Extra arguments to pass when running docker."`
	RunImage   string `name:"run-image" help:"Override the image used for running the container."`
}

func (r *RestartCmd) Run(cli *Cli, ctx *context.Context) error {
	start := StartCmd{Config: r.Config, DockerArgs: r.DockerArgs, RunImage: r.RunImage}
	stop := StopCmd{Config: r.Config}

	if err := stop.Run(cli, ctx); err != nil {
		return err
	}

	if err := start.Run(cli, ctx); err != nil {
		return err
	}

	return nil
}

type DestroyCmd struct {
	Config string `arg:"" name:"config" help:"config" predictor:"config"`
}

func (r *DestroyCmd) Run(cli *Cli, ctx *context.Context) error {
	exists, _ := docker.ContainerExists(r.Config)
	if !exists {
		fmt.Fprintln(utils.Out, r.Config+" was not found")
		return nil
	}

	cmd := exec.CommandContext(*ctx, utils.DockerPath, "stop", "-t", "600", r.Config)
	fmt.Fprintln(utils.Out, cmd)
	if err := utils.CmdRunner(cmd).Run(); err != nil {
		return err
	}
	cmd = exec.CommandContext(*ctx, utils.DockerPath, "rm", r.Config)
	fmt.Fprintln(utils.Out, cmd)
	if err := utils.CmdRunner(cmd).Run(); err != nil {
		return err
	}
	return nil
}

type EnterCmd struct {
	Config string `arg:"" name:"config" help:"config" predictor:"config"`
}

func (r *EnterCmd) Run(cli *Cli, ctx *context.Context) error {
	cmd := exec.CommandContext(*ctx, utils.DockerPath, "exec", "-it", r.Config, "/bin/bash", "--login")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := utils.CmdRunner(cmd).Run(); err != nil {
		return err
	}
	return nil
}

type LogsCmd struct {
	Config string `arg:"" name:"config" help:"config" predictor:"config"`
}

func (r *LogsCmd) Run(cli *Cli, ctx *context.Context) error {
	cmd := exec.CommandContext(*ctx, utils.DockerPath, "logs", r.Config)
	output, err := utils.CmdRunner(cmd).Output()
	if err != nil {
		return err
	}
	fmt.Fprintln(utils.Out, string(output[:]))
	return nil
}

type RebuildCmd struct {
	Config    string `arg:"" name:"config" help:"config" predictor:"config"`
	FullBuild bool   `name:"full-build" help:"Run a full build image even when migrate on boot and precompile on boot are present in the config. Saves a fully built image with environment baked in. Without this flag, if MIGRATE_ON_BOOT is set in config it will defer migration until container start, and if PRECOMPILE_ON_BOOT is set in the config, it will defer configure step until container start."`
	Clean     bool   `help:"also runs clean"`
}

func (r *RebuildCmd) Run(cli *Cli, ctx *context.Context) error {

	config, err := config.LoadConfig(cli.ConfDir, r.Config, true, cli.TemplatesDir)
	if err != nil {
		return errors.New("YAML syntax error. Please check your containers/*.yml config files.")
	}

	// if we're not in an all-in-one setup, we can run migrations while the app is running
	externalDb := config.Env["DISCOURSE_DB_SOCKET"] == "" && config.Env["DISCOURSE_DB_HOST"] != ""

	build := DockerBuildCmd{Config: r.Config}
	configure := DockerConfigureCmd{Config: r.Config}
	stop := StopCmd{Config: r.Config}
	destroy := DestroyCmd{Config: r.Config}
	clean := CleanupCmd{}
	extraEnv := []string{}

	if err := build.Run(cli, ctx); err != nil {
		return err
	}
	if !externalDb {
		if err := stop.Run(cli, ctx); err != nil {
			return err
		}
	}
	_, migrateOnBoot := config.Env["MIGRATE_ON_BOOT"]
	if !migrateOnBoot || r.FullBuild {
		migrate := DockerMigrateCmd{Config: r.Config}
		if externalDb {
			// defer post deploy migrations until after reboot
			migrate.SkipPostDeploymentMigrations = true
		}
		if err := migrate.Run(cli, ctx); err != nil {
			return err
		}
		extraEnv = append(extraEnv, "MIGRATE_ON_BOOT=0")
	}
	_, precompileOnBoot := config.Env["PRECOMPILE_ON_BOOT"]
	if !precompileOnBoot || r.FullBuild {
		if err := configure.Run(cli, ctx); err != nil {
			return err
		}
		extraEnv = append(extraEnv, "PRECOMPILE_ON_BOOT=0")
	}
	if err := destroy.Run(cli, ctx); err != nil {
		return err
	}
	start := StartCmd{Config: r.Config, extraEnv: extraEnv}
	if err := start.Run(cli, ctx); err != nil {
		return err
	}
	// run post deploy migrations since we've rebooted
	if externalDb {
		migrate := DockerMigrateCmd{Config: r.Config}
		if err := migrate.Run(cli, ctx); err != nil {
			return err
		}
	}
	if r.Clean {
		if err := clean.Run(cli, ctx); err != nil {
			return err
		}
	}
	return nil
}

type CleanupCmd struct{}

func (r *CleanupCmd) Run(cli *Cli, ctx *context.Context) error {
	cmd := exec.CommandContext(*ctx, utils.DockerPath, "container", "prune", "--filter", "until=1h")
	if err := utils.CmdRunner(cmd).Run(); err != nil {
		return err
	}
	cmd = exec.CommandContext(*ctx, utils.DockerPath, "image", "prune", "--all", "--filter", "until=1h")
	if err := utils.CmdRunner(cmd).Run(); err != nil {
		return err
	}
	_, err := os.Stat("/var/discourse/shared/standalone/postgres_data_old")
	if !os.IsNotExist(err) {
		fmt.Fprintln(utils.Out, "Old PostgreSQL backup data cluster detected")
		fmt.Fprintln(utils.Out, "Would you like to remove it? (y/N)")
		scanner := bufio.NewScanner(os.Stdin)
		scanner.Scan()
		reply := scanner.Text()
		if reply == "y" || reply == "Y" {
			fmt.Fprintln(utils.Out, "removing old PostgreSQL data cluster at /var/discourse/shared/standalone/postgres_data_old...")
			os.RemoveAll("/var/discourse/shared/standalone/postgres_data_old")
		} else {
			return errors.New("Cancelled")
		}
	}

	return nil
}
