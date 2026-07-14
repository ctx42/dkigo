package dkigo

import (
	"testing"

	"github.com/ctx42/testing/pkg/assert"
	"github.com/ctx42/xdef/pkg/xdef"
)

func Test_CfgLookup(t *testing.T) {
	t.Run("exiting key", func(t *testing.T) {
		// --- When ---
		have, exists := CfgLookup(xdef.EnvRegRepo)

		// --- Then ---
		assert.Equal(t, "ghcr.io/ctx42", have)
		assert.True(t, exists)
	})

	t.Run("not exiting key", func(t *testing.T) {
		// --- When ---
		have, exists := CfgLookup("__not_existing__")

		// --- Then ---
		assert.Equal(t, "", have)
		assert.False(t, exists)
	})
}

func Test_CfgGet(t *testing.T) {
	t.Run("exiting key", func(t *testing.T) {
		// --- When ---
		have := CfgGet(xdef.EnvRegRepo)

		// --- Then ---
		assert.Equal(t, "ghcr.io/ctx42", have)
	})

	t.Run("not exiting key", func(t *testing.T) {
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
	want := map[string]string{
		xdef.EnvBldImgBase:              "almalinux:9.8-minimal",
		"C42_BLD_IMG_MICRO":             "almalinux/9-micro:9.8",
		xdef.EnvRegHost:                 "ghcr.io",
		xdef.EnvRegScheme:               "https",
		xdef.EnvRegRepo:                 "ghcr.io/ctx42",
		xdef.EnvBldTargets:              "base,test",
		xdef.EnvCtrProjectRoot:          "/ctx42/project",
		xdef.EnvCtrRoot:                 "/ctx42",
		xdef.EnvGoPrivate:               "",
		xdef.EnvGoProxy:                 "",
		xdef.EnvGoSumDB:                 "",
		xdef.EnvCtrEntrypoint:           "/ctx42/entrypoint",
		xdef.EnvCtrBin:                  "/ctx42/bin",
		"C42_BLD_DOCKER_BUILDX_VERSION": "v0.35.0",
		"C42_BLD_DOCKER_CLI_VERSION":    "29.6.1",
		"C42_BLD_GMTASK_VERSION":        "v0.4.0",
		"C42_BLD_TINI_VERSION":          "v0.19.0",
		"C42_BLD_GOBIN":                 "/ctx42/go-bin",
		"C42_BLD_GOCACHE":               "/ctx42/go-cache",
		"C42_BLD_GOLANGCI_LINT_VERSION": "v2.12.2",
		"C42_BLD_GOLINT_CACHE":          "/ctx42/go-cache-lint",
		"C42_BLD_GOMAKE_VERSION":        "v0.23.0",
		"C42_BLD_GOPATH":                "/ctx42/go",
		"C42_BLD_GO_VERSION":            "1.26.2",
		"C42_BLD_XDEV_VERSION":          "v0.1.0",
	}
	assert.Equal(t, want, have)
}
