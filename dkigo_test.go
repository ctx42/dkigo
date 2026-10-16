package dkigo

import (
	"os"
	"os/exec"
	"strings"
	"testing"

	"github.com/ctx42/testing/pkg/assert"
	"github.com/ctx42/xdef/pkg/xdef"
)

func Test_parseCfg(t *testing.T) {
	t.Run("no overrides", func(t *testing.T) {
		// --- When ---
		have := parseCfg(nil)

		// --- Then ---
		lintCfg := "" +
			"https://raw.githubusercontent.com/ctx42/xdev/" +
			"v0.1.0/.golangci.yml"
		want := map[string]string{
			xdef.EnvBldImgBase:              "almalinux:9.8-minimal",
			xdef.EnvBldImgRuntime:           "almalinux/9-micro:9.8",
			xdef.EnvRegHost:                 "ghcr.io",
			xdef.EnvRegScheme:               "https",
			xdef.EnvRegRepo:                 "ghcr.io/ctx42",
			xdef.EnvBldImgTargets:           "base,test",
			xdef.EnvCtrPrjRoot:              "/ctx42/project",
			xdef.EnvCtrRoot:                 "/ctx42",
			xdef.EnvGoPrivate:               "",
			xdef.EnvGoProxy:                 "",
			xdef.EnvGoSumDB:                 "",
			xdef.EnvCtrEntrypoint:           "/ctx42/entrypoint",
			xdef.EnvCtrBin:                  "/ctx42/bin",
			"C42_BLD_DOCKER_BUILDX_VERSION": "v0.35.0",
			"C42_BLD_DOCKER_CLI_VERSION":    "29.6.1",
			"C42_BLD_TINI_VERSION":          "v0.19.0",
			"C42_BLD_GOBIN":                 "/ctx42/go-bin",
			"C42_BLD_GOCACHE":               "/ctx42/go-cache",
			"C42_BLD_GMTASK_VERSION":        "v0.17.0",
			"C42_BLD_GOLANGCI_LINT_VERSION": "v2.12.2",
			"C42_BLD_GOLINT_CACHE":          "/ctx42/go-cache-lint",
			"C42_BLD_GOMAKE_VERSION":        "v0.31.1",
			"C42_BLD_GOPATH":                "/ctx42/go",
			"C42_BLD_GO_VERSION":            "1.26.2",
			"C42_BLD_XDEV_VERSION":          "v0.1.0",
			"C42_BLD_GOLINT_CONFIG":         lintCfg,
			"C42_BLD_GIT_SSH_HOSTS":         "github.com,bitbucket.org",
		}
		assert.Equal(t, want, have)
	})

	t.Run("environment overrides a module version", func(t *testing.T) {
		// --- Given ---
		env := []string{"C42_BLD_GOMAKE_VERSION=v9.9.9"}

		// --- When ---
		have := parseCfg(env)

		// --- Then ---
		assert.Equal(t, "v9.9.9", have["C42_BLD_GOMAKE_VERSION"])
	})

	t.Run("environment overrides declared key", func(t *testing.T) {
		// --- Given ---
		env := []string{
			xdef.EnvRegRepo + "=registry.acme.io/platform",
			xdef.EnvGoPrivate + "=github.com/acme",
		}

		// --- When ---
		have := parseCfg(env)

		// --- Then ---
		repo := "registry.acme.io/platform"
		assert.HasKeyValue(t, xdef.EnvRegRepo, repo, have)
		assert.HasKeyValue(t, xdef.EnvGoPrivate, "github.com/acme", have)
		assert.HasKeyValue(t, xdef.EnvRegHost, "ghcr.io", have)
	})

	t.Run("environment override moves derived keys", func(t *testing.T) {
		// --- Given ---
		env := []string{
			xdef.EnvRegHost + "=registry.acme.io",
			xdef.EnvCtrRoot + "=/vrinf",
		}

		// --- When ---
		have := parseCfg(env)

		// --- Then ---
		assert.HasKeyValue(t, xdef.EnvRegRepo, "registry.acme.io/ctx42", have)
		assert.HasKeyValue(t, "C42_BLD_GOPATH", "/vrinf/go", have)
		assert.HasKeyValue(t, xdef.EnvCtrBin, "/vrinf/bin", have)
	})

	t.Run("explicit derived key kept", func(t *testing.T) {
		// --- Given ---
		env := []string{
			xdef.EnvRegHost + "=registry.acme.io",
			xdef.EnvRegRepo + "=registry.acme.io/platform",
		}

		// --- When ---
		have := parseCfg(env)

		// --- Then ---
		repo := "registry.acme.io/platform"
		assert.HasKeyValue(t, xdef.EnvRegRepo, repo, have)
	})

	t.Run("empty environment value overrides", func(t *testing.T) {
		// --- Given ---
		env := []string{xdef.EnvRegRepo + "="}

		// --- When ---
		have := parseCfg(env)

		// --- Then ---
		assert.HasKeyValue(t, xdef.EnvRegRepo, "", have)
	})

	t.Run("undeclared environment variable ignored", func(t *testing.T) {
		// --- Given ---
		env := []string{"C42_NOT_DECLARED=value"}

		// --- When ---
		have := parseCfg(env)

		// --- Then ---
		assert.Equal(t, parseCfg(nil), have)
	})
}

func Test_CfgLookup(t *testing.T) {
	t.Run("existing key", func(t *testing.T) {
		// --- When ---
		have, exists := CfgLookup(xdef.EnvRegRepo)

		// --- Then ---
		assert.Equal(t, parseCfg(os.Environ())[xdef.EnvRegRepo], have)
		assert.True(t, exists)
	})

	t.Run("missing key", func(t *testing.T) {
		// --- When ---
		have, exists := CfgLookup("__not_existing__")

		// --- Then ---
		assert.Equal(t, "", have)
		assert.False(t, exists)
	})
}

func Test_CfgGet(t *testing.T) {
	t.Run("existing key", func(t *testing.T) {
		// --- When ---
		have := CfgGet(xdef.EnvRegRepo)

		// --- Then ---
		assert.Equal(t, parseCfg(os.Environ())[xdef.EnvRegRepo], have)
	})

	t.Run("missing key", func(t *testing.T) {
		// --- When ---
		have := CfgGet("__not_existing__")

		// --- Then ---
		assert.Equal(t, "", have)
	})
}

func Test_CfgAll(t *testing.T) {
	// --- When ---
	have := CfgAll()

	// --- Then ---
	assert.Equal(t, parseCfg(os.Environ()), have)
}

func Test_moduleVersions_tabular(t *testing.T) {
	tt := []struct {
		testN string

		mod string
		key string
	}{
		{"gmtask", "github.com/ctx42/gmtask", "C42_BLD_GMTASK_VERSION"},
		{"gomake", "github.com/ctx42/gomake", "C42_BLD_GOMAKE_VERSION"},
	}

	for _, tc := range tt {
		t.Run(tc.testN, func(t *testing.T) {
			// --- Given ---
			args := []string{"list", "-m", "-f", "{{.Version}}", tc.mod}
			cmd := exec.Command("go", args...)

			// --- When ---
			out, err := cmd.CombinedOutput()

			// --- Then ---
			assert.NoError(t, err, "%s", out)
			have := strings.TrimSpace(string(out))
			assert.Equal(t, parseCfg(nil)[tc.key], have)
		})
	}
}
