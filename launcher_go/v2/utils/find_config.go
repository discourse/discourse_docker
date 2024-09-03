package utils

import (
	"bytes"
	"flag"
	"io/ioutil"
	"os"
	"strings"
)

// Find config names for autocomplete, given the current --conf-dir argument.
func FindConfigNames() []string {
	compLine := os.Getenv("COMP_LINE")
	flagLine := []string{}
	found := false
	// the flag package wants a valid flag first
	// drop all COMP_LINE args until we find something that starts with --conf-dir
	for _, s := range strings.Fields(compLine) {
		if found {
			flagLine = append(flagLine, s)
		}
		if strings.HasPrefix(s, "--conf-dir") {
			flagLine = append(flagLine, s)
			found = true
		}
	}
	flags := flag.NewFlagSet("f", flag.ContinueOnError)
	//squelch helptext
	flags.SetOutput(&bytes.Buffer{})
	confDirArg := flags.String("conf-dir", "./containers", "conf dir")
	flags.Parse(flagLine)

	// search in the current conf dir for any files
	confDir := strings.TrimRight(*confDirArg, "/") + "/"
	confFiles := []string{}
	files, err := ioutil.ReadDir(confDir)
	if err == nil {
		for _, file := range files {
			if !file.IsDir() {
				if strings.HasSuffix(file.Name(), ".yml") {
					confName, _ := strings.CutSuffix(file.Name(), ".yml")
					confFiles = append(confFiles, confName)
				} else if strings.HasSuffix(file.Name(), ".yaml") {
					confName, _ := strings.CutSuffix(file.Name(), ".yaml")
					confFiles = append(confFiles, confName)
				}
			}
		}
	}
	return confFiles
}
