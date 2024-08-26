package docker

import (
	"context"
	"github.com/discourse/discourse_docker/launcher_go/v2/config"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"golang.org/x/sys/unix"
	"io"
	"os"
	"os/exec"
	"syscall"
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
