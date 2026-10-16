// Command cfgenv prints the configuration the dkigo images are built with as
// shell assignments for bin/build.sh and bin/push.sh to evaluate:
//
//	C42_BLD_GO_VERSION='1.26.2'
//	C42_REG_REPO='ghcr.io/ctx42'
//
// It reads configs/project.conf and applies the environment the way gomake
// does: a variable named like a key in the file overrides that key's value
// before variable expansion, so a value referring to an overridden key
// follows it, and variables the file does not declare are ignored. One
// "[dkigo] override KEY=value" line per overridden key goes to standard error.
//
// Usage:
//
//	cfgenv [repository-dir]
//
// The directory defaults to the current working directory.
package main

import (
	"errors"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/ctx42/dotenv/pkg/dotenv"
	"github.com/ctx42/ring/pkg/ring"
)

// cfgPath is the path of the configuration relative to the repository root.
const cfgPath = "configs/project.conf"

// errTooManyArgs is returned when more than one repository is given.
var errTooManyArgs = errors.New("too many arguments")

func main() {
	env := ring.WithEnv(os.Environ())
	rng := ring.New(env, ring.WithArgs(os.Args[1:]))
	if err := run(rng); err != nil {
		_, _ = fmt.Fprintf(rng.Stderr(), "cfgenv: %s\n", err)
		os.Exit(1)
	}
}

// run writes the assignments for the repository named by the only argument
// in rng, or for the current working directory without one, applying the
// environment of rng.
func run(rng *ring.Ring) error {
	args := rng.Args()
	if len(args) > 1 {
		return errTooManyArgs
	}
	root := "."
	if len(args) == 1 {
		root = args[0]
	}

	pth := filepath.Join(root, cfgPath)
	fil, err := os.Open(pth) //nolint:gosec
	if err != nil {
		return err
	}
	defer func() { _ = fil.Close() }()

	var lay dotenv.Layers
	if err = lay.Read(fil); err != nil {
		return fmt.Errorf("%s: %w", pth, err)
	}
	cfg, keys := lay.Expand(rng.EnvAll())

	for _, key := range keys {
		format := "[dkigo] override %s=%s\n"
		_, _ = fmt.Fprintf(rng.Stderr(), format, key, cfg[key])
	}
	for _, key := range slices.Sorted(maps.Keys(cfg)) {
		_, err = fmt.Fprintf(rng.Stdout(), "%s=%s\n", key, quote(cfg[key]))
		if err != nil {
			return fmt.Errorf("write assignments: %w", err)
		}
	}
	return nil
}

// quote returns val as a single-quoted shell word; a single quote in val
// closes the quoting, is escaped, and reopens it.
func quote(val string) string {
	return "'" + strings.ReplaceAll(val, "'", `'\''`) + "'"
}
