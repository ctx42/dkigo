// Package dkigo exposes the configuration the dkigo Docker images are built
// with: the base images, the Dockerfile targets, the pinned tool versions, and
// the container paths, read from the embedded configs/project.conf.
//
// An environment variable named like a configuration key overrides that key's
// value, an empty value included; variables the configuration does not declare
// are ignored. This lets an organization point the registry keys at its own
// registry. Overrides apply before variable expansion, so a value referring to
// an overridden key follows it: overriding C42_REG_HOST also moves
// C42_REG_REPO, and overriding C42_CTR_ROOT moves the paths derived from it.
// The environment is read once, on the first call to any function in the
// package.
//
// Import it as github.com/ctx42/dkigo:
//
//	goVer := dkigo.CfgGet("C42_BLD_GO_VERSION") // e.g. "1.26.2"
//	for key, val := range dkigo.CfgAll() {
//		fmt.Printf("--build-arg\n%s=%s\n", key, val)
//	}
package dkigo

import (
	"bytes"
	"embed"
	"maps"
	"os"
	"sync"

	"github.com/ctx42/dotenv/pkg/dotenv"
)

// prjCfg returns the project configuration with the process environment
// overrides applied, built on the first call.
var prjCfg = sync.OnceValue(func() map[string]string {
	return parseCfg(os.Environ())
})

//go:embed configs/project.conf
var embedded embed.FS

// parseCfg parses the embedded project configuration with the overrides from
// env, given in [os.Environ] form, applied before variable expansion. It
// panics when the embedded configuration cannot be read or parsed.
func parseCfg(env []string) map[string]string {
	rawProjCfg, err := embedded.ReadFile("configs/project.conf")
	if err != nil {
		panic(err)
	}
	var lay dotenv.Layers
	if err = lay.Read(bytes.NewReader(rawProjCfg)); err != nil {
		panic(err)
	}
	cfg, _ := lay.Expand(env)
	return cfg
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
