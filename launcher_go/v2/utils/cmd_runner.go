package utils

import (
	"os/exec"
)

type ICmdRunner interface {
	Run() error
	Output() ([]byte, error)
}

type ExecCmdRunner struct {
	Cmd *exec.Cmd
}

func (r *ExecCmdRunner) Run() error {
	return r.Cmd.Run()
}

func (r *ExecCmdRunner) Output() ([]byte, error) {
	return r.Cmd.Output()
}

func NewExecCmdRunner(cmd *exec.Cmd) ICmdRunner {
	return &ExecCmdRunner{Cmd: cmd}
}

var CmdRunner = NewExecCmdRunner
