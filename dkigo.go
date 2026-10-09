// Package dkigo exposes the configuration the dkigo Docker images are built
// with: the base images, the Dockerfile targets, the pinned tool versions, and
// the container paths, read from the embedded configs/project.conf.
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
	"sync"

	"github.com/ctx42/dotenv/pkg/dotenv"
)

// prjCfg returns the project configuration, parsed on the first call. It
// panics when the embedded configuration cannot be read or parsed.
var prjCfg = sync.OnceValue(func() map[string]string {
	rawProjCfg, err := embedded.ReadFile("configs/project.conf")
	if err != nil {
		panic(err)
	}
	cfg := make(map[string]string)
	if err = dotenv.Parse(cfg, bytes.NewReader(rawProjCfg)); err != nil {
		panic(err)
	}
	return cfg
})

// Embedded files.
//
//go:embed configs/project.conf
var embedded embed.FS

// CfgLookup returns project configuration key. Returns empty string and false
// if the key does not exist, otherwise it returns the key value and true.
func CfgLookup(key string) (string, bool) {
	val, ok := prjCfg()[key]
	return val, ok
}

// CfgGet returns project configuration key.
//
// Returns empty string if the key does not exist.
func CfgGet(key string) string {
	val, _ := CfgLookup(key)
	return val
}

// CfgAll returns all project configuration keys.
//
// It returns copy of the original map.
func CfgAll() map[string]string { return maps.Clone(prjCfg()) }
