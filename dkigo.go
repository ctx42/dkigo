package dkigo

import (
	"bytes"
	"embed"
	"maps"

	"github.com/ctx42/dotenv/pkg/dotenv"
)

// prjCfg represents project configuration as a map.
var prjCfg = make(map[string]string)

// Embedded files.
//
//go:embed configs/project.conf
var embedded embed.FS

func init() {
	rawProjCfg, err := embedded.ReadFile("configs/project.conf")
	if err != nil {
		panic(err)
	}
	if err = dotenv.Parse(prjCfg, bytes.NewReader(rawProjCfg)); err != nil {
		panic(err)
	}
}

// CfgLookup returns project configuration key. Returns empty string and false
// if the key does not exist, otherwise it returns the key value and true.
func CfgLookup(key string) (string, bool) {
	if val, ok := prjCfg[key]; ok {
		return val, true
	}
	return "", false
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
func CfgAll() map[string]string { return maps.Clone(prjCfg) }
