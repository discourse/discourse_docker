package docker

import (
	"context"
	"fmt"
	"github.com/Wing924/shellwords"
	"github.com/discourse/discourse_docker/launcher_go/v2/config"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"golang.org/x/sys/unix"
	"io"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"syscall"
	"time"
)

type DockerBuilder struct {
	Config   *config.Config
	Ctx      *context.Context
	Stdin    io.Reader
	Dir      string
	ImageTag string
}

func (r *DockerBuilder) Run() error {
	if r.ImageTag == "" {
		r.ImageTag = "latest"
	}
	cmd := exec.CommandContext(*r.Ctx, utils.DockerPath, "build")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		return unix.Kill(-cmd.Process.Pid, unix.SIGINT)
	}
	cmd.Dir = r.Dir
	cmd.Env = r.Config.EnvArray(false)
	cmd.Env = append(cmd.Env, "BUILDKIT_PROGRESS=plain")
	for k, _ := range r.Config.Env {
		cmd.Args = append(cmd.Args, "--build-arg")
		cmd.Args = append(cmd.Args, k)
	}
	cmd.Args = append(cmd.Args, "--no-cache")
	cmd.Args = append(cmd.Args, "--pull")
	cmd.Args = append(cmd.Args, "--force-rm")
	cmd.Args = append(cmd.Args, "-t")
	cmd.Args = append(cmd.Args, utils.BaseImageName+r.Config.Name+":"+r.ImageTag)
	cmd.Args = append(cmd.Args, "--shm-size=512m")
	cmd.Args = append(cmd.Args, "-f")
	cmd.Args = append(cmd.Args, "-")
	cmd.Args = append(cmd.Args, ".")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = r.Stdin
	if err := utils.CmdRunner(cmd).Run(); err != nil {
		return err
	}
	return nil
}

type DockerRunner struct {
	Config      *config.Config
	Ctx         *context.Context
	ExtraEnv    []string
	ExtraFlags  []string
	Rm          bool
	ContainerId string
	CustomImage string
	Cmd         []string
	Stdin       io.Reader
	SkipPorts   bool
	DryRun      bool
	Restart     bool
	Detatch     bool
	Hostname    string
}

func (r *DockerRunner) Run() error {
	cmd := exec.CommandContext(*r.Ctx, utils.DockerPath, "run")

	// Detatch signifies we do not want to supervise
	if !r.Detatch {
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		cmd.Cancel = func() error {
			if runtime.GOOS == "darwin" {
				runCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
				stopCmd := exec.CommandContext(runCtx, utils.DockerPath, "stop", r.ContainerId)
				utils.CmdRunner(stopCmd).Run()
				cancel()
			}
			return unix.Kill(-cmd.Process.Pid, unix.SIGINT)
		}
	}
	cmd.Env = r.Config.EnvArray(true)

	if r.DryRun {
		// multi-line env doesn't work super great from CLI, but we can print out the rest.
		for k, v := range r.Config.Env {
			if !strings.Contains(v, "\n") {
				cmd.Args = append(cmd.Args, "--env")
				cmd.Args = append(cmd.Args, k+"="+shellwords.Escape(v))
			}
		}
	} else {
		for k, _ := range r.Config.Env {
			cmd.Args = append(cmd.Args, "--env")
			cmd.Args = append(cmd.Args, k)
		}
	}

	// Order is important here, we add extra env after config's env to override anything set in env.
	for _, e := range r.ExtraEnv {
		cmd.Args = append(cmd.Args, "--env")
		cmd.Args = append(cmd.Args, e)
	}
	for k, v := range r.Config.Labels {
		cmd.Args = append(cmd.Args, "--label")
		cmd.Args = append(cmd.Args, k+"="+v)
	}
	if !r.SkipPorts {
		for _, v := range r.Config.Expose {
			if strings.Contains(v, ":") {
				cmd.Args = append(cmd.Args, "-p")
				cmd.Args = append(cmd.Args, v)
			} else {
				cmd.Args = append(cmd.Args, "--expose")
				cmd.Args = append(cmd.Args, v)
			}
		}
	}
	for _, v := range r.Config.Volumes {
		cmd.Args = append(cmd.Args, "-v")
		cmd.Args = append(cmd.Args, v.Volume.Host+":"+v.Volume.Guest)
	}
	for _, v := range r.Config.Links {
		cmd.Args = append(cmd.Args, "--link")
		cmd.Args = append(cmd.Args, v.Link.Name+":"+v.Link.Alias)
	}
	cmd.Args = append(cmd.Args, "--shm-size=512m")
	if r.Rm {
		cmd.Args = append(cmd.Args, "--rm")
	}
	if r.Restart {
		cmd.Args = append(cmd.Args, "--restart=always")
	} else {
		cmd.Args = append(cmd.Args, "--restart=no")
	}
	if r.Detatch {
		cmd.Args = append(cmd.Args, "-d")
	}
	cmd.Args = append(cmd.Args, "-i")

	// Docker args override settings above
	for _, f := range r.Config.DockerArgs() {
		cmd.Args = append(cmd.Args, f)
	}
	for _, f := range r.ExtraFlags {
		cmd.Args = append(cmd.Args, f)
	}
	cmd.Args = append(cmd.Args, "-h")
	cmd.Args = append(cmd.Args, r.Hostname)
	cmd.Args = append(cmd.Args, "--name")
	cmd.Args = append(cmd.Args, r.ContainerId)
	if len(r.CustomImage) > 0 {
		cmd.Args = append(cmd.Args, r.CustomImage)
	} else {
		cmd.Args = append(cmd.Args, r.Config.RunImage())
	}

	for _, c := range r.Cmd {
		cmd.Args = append(cmd.Args, c)
	}

	if !r.Detatch {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = r.Stdin
	}
	runner := utils.CmdRunner(cmd)
	if r.DryRun {
		fmt.Println(cmd)
	} else {
		if err := runner.Run(); err != nil {
			return err
		}
	}
	return nil
}

type DockerPupsRunner struct {
	Config         *config.Config
	PupsArgs       string
	SavedImageName string
	ExtraEnv       []string
	Ctx            *context.Context
	ContainerId    string
}

func (r *DockerPupsRunner) Run() error {
	rm := false
	// remove : in case docker tag is blank, and use default latest tag
	r.SavedImageName = strings.TrimRight(r.SavedImageName, ":")
	if r.SavedImageName == "" {
		rm = true
	}
	defer func(rm bool) {
		if !rm {
			time.Sleep(utils.CommitWait)
			runCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			cmd := exec.CommandContext(runCtx, utils.DockerPath, "rm", "-f", r.ContainerId)
			utils.CmdRunner(cmd).Run()
			cancel()
		}
	}(rm)
	commands := []string{"/bin/bash",
		"-c",
		"/usr/local/bin/pups --stdin " + r.PupsArgs}

	runner := DockerRunner{Config: r.Config,
		Ctx:         r.Ctx,
		ExtraEnv:    r.ExtraEnv,
		Rm:          rm,
		ContainerId: r.ContainerId,
		Cmd:         commands,
		Stdin:       strings.NewReader(r.Config.Yaml()),
		SkipPorts:   true, //pups runs don't need to expose ports
	}

	if err := runner.Run(); err != nil {
		return err
	}

	if len(r.SavedImageName) > 0 {
		time.Sleep(utils.CommitWait)
		cmd := exec.Command("docker",
			"commit",
			"--change",
			"LABEL org.opencontainers.image.created=\""+time.Now().Format(time.RFC3339)+"\"",
			"--change",
			"CMD [\""+r.Config.BootCommand()+"\"]",
			r.ContainerId,
			r.SavedImageName,
		)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		fmt.Fprintln(utils.Out, cmd)
		if err := utils.CmdRunner(cmd).Run(); err != nil {
			return err
		}
	}
	return nil
}
