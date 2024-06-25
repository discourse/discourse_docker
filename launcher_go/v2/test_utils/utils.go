package test_utils

import (
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"os/exec"
)

var RanCmds []exec.Cmd
var CmdOutputResponse []byte
var CmdOutputError error

type FakeCmdRunner struct {
	Cmd *exec.Cmd
}

func (r FakeCmdRunner) Run() error {
	RanCmds = append(RanCmds, *r.Cmd)
	return CmdOutputError
}

func (r FakeCmdRunner) Output() ([]byte, error) {
	RanCmds = append(RanCmds, *r.Cmd)
	return CmdOutputResponse, CmdOutputError
}

// Swap out CmdRunner with a fake instance that also returns created ICmdRunners on a channel
// so tests can inspect commands after they're run
func CreateNewFakeCmdRunner() func(cmd *exec.Cmd) utils.ICmdRunner {
	RanCmds = []exec.Cmd{}
	CmdOutputResponse = []byte{}
	CmdOutputError = nil
	return func(cmd *exec.Cmd) utils.ICmdRunner {
		cmdRunner := &FakeCmdRunner{Cmd: cmd}
		return cmdRunner
	}
}
