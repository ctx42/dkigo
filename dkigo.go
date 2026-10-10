// Package dkigo exposes the configuration the dkigo Docker images are built
// with: the base images, the Dockerfile targets, the pinned tool versions, and
// the container paths, read from the embedded configs/project.conf. The gomake
// and gmtask versions come from the go.mod requirements instead, so a release
// of either only has to update go.mod.
//
// An environment variable named like a configuration key overrides that key's
// value, an empty value included; variables the configuration does not declare
// are ignored. This lets an organization point the registry keys at its own
// registry. Overrides apply after variable expansion, so overriding
// C42_REG_HOST leaves C42_REG_REPO unchanged. The environment is read once, on
// the first call to any function in the package.
//
// Import it as github.com/ctx42/dkigo:
//
//	goVer := dkigo.CfgGet("C42_BLD_GO_VERSION") // e.g. "1.26.2"
//	for key, val := range dkigo.CfgAll() {
//		fmt.Printf("--build-arg\n%s=%s\n", key, val)
//	}
package dkigo

import (
	"bufio"
	"bytes"
	"embed"
	"fmt"
	"maps"
	"os"
	"strings"
	"sync"

	"github.com/ctx42/dotenv/pkg/dotenv"
)

// prjCfg returns the project configuration with the process environment
// overrides applied, built on the first call.
var prjCfg = sync.OnceValue(func() map[string]string {
	return parseCfg(os.Environ())
})

//go:embed configs/project.conf go.mod
var embedded embed.FS

// modVersions maps the configuration keys holding a module version to the
// path of the module whose go.mod requirement gives the value.
var modVersions = map[string]string{
	"C42_BLD_GOMAKE_VERSION": "github.com/ctx42/gomake",
	"C42_BLD_GMTASK_VERSION": "github.com/ctx42/gmtask",
}

// parseCfg parses the embedded project configuration, adds the module
// versions [modVersions] names from the embedded go.mod, and applies the
// overrides from env, given in [os.Environ] form. It panics when the embedded
// files cannot be read or parsed, or go.mod lacks a requirement.
func parseCfg(env []string) map[string]string {
	rawProjCfg, err := embedded.ReadFile("configs/project.conf")
	if err != nil {
		panic(err)
	}
	cfg := make(map[string]string)
	if err = dotenv.Parse(cfg, bytes.NewReader(rawProjCfg)); err != nil {
		panic(err)
	}
	rawMod, err := embedded.ReadFile("go.mod")
	if err != nil {
		panic(err)
	}
	for key, pth := range modVersions {
		ver, ok := requiredVersion(rawMod, pth)
		if !ok {
			panic(fmt.Errorf("go.mod does not require %s", pth))
		}
		cfg[key] = ver
	}
	dotenv.Override(cfg, env)
	return cfg
}

// requiredVersion returns the version the go.mod file content mod requires of
// the module at pth, and whether it requires it. Both the single-line and the
// block form of the require directive are read; other directives, replace
// blocks included, are skipped.
func requiredVersion(mod []byte, pth string) (string, bool) {
	var block string
	scn := bufio.NewScanner(bytes.NewReader(mod))
	for scn.Scan() {
		fields := strings.Fields(scn.Text())
		switch {
		case len(fields) == 0:
			continue

		case len(fields) == 2 && fields[1] == "(":
			block = fields[0]
			continue

		case fields[0] == ")":
			block = ""
			continue

		case block == "" && fields[0] == "require":
			fields = fields[1:]

		case block != "require":
			continue
		}
		if len(fields) >= 2 && fields[0] == pth {
			return fields[1], true
		}
	}
	return "", false
}

// CfgLookup returns the value of the project configuration key.
func CfgLookup(key string) (string, bool) {
	val, ok := prjCfg()[key]
	return val, ok
}

// CfgGet returns the value of the project configuration key.
//
// Returns an empty string if the key does not exist.
func CfgGet(key string) string {
	val, _ := CfgLookup(key)
	return val
}

// CfgAll returns all project configuration keys and their values.
//
// It returns a copy of the original map.
func CfgAll() map[string]string { return maps.Clone(prjCfg()) }
