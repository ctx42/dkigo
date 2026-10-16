package main

import (
	"io/fs"
	"testing"

	"github.com/ctx42/dotenv/pkg/dotenv"
	"github.com/ctx42/ring/pkg/ring/ringtest"
	"github.com/ctx42/testing/pkg/assert"
	"github.com/ctx42/testkit/pkg/oskit"
)

func Test_run(t *testing.T) {
	t.Run("assignments", func(t *testing.T) {
		// --- Given ---
		root := t.TempDir()
		cfg := "" +
			"C42_HOST=ghcr.io\n" +
			"C42_REPO=$C42_HOST/ctx42\n" +
			"C42_SUMDB=\"sum.golang.org https://sum.acme.io\"\n"
		oskit.Write(t, cfg, oskit.MkdirAll(t, root, "configs"), "project.conf")

		tst := ringtest.New(t).WetStdout()
		rng := tst.Ring(root)

		// --- When ---
		err := run(rng)

		// --- Then ---
		assert.NoError(t, err)
		want := "" +
			"C42_HOST='ghcr.io'\n" +
			"C42_REPO='ghcr.io/ctx42'\n" +
			"C42_SUMDB='sum.golang.org https://sum.acme.io'\n"
		assert.Equal(t, want, tst.Stdout())
	})

	t.Run("environment overrides before expansion", func(t *testing.T) {
		// --- Given ---
		root := t.TempDir()
		cfg := "C42_HOST=ghcr.io\nC42_REPO=$C42_HOST/ctx42\n"
		oskit.Write(t, cfg, oskit.MkdirAll(t, root, "configs"), "project.conf")

		tst := ringtest.New(t).WetStdout().WetStderr()
		rng := tst.Ring(root)
		rng.EnvSet("C42_HOST", "registry.acme.io")
		rng.EnvSet("C42_NOT_DECLARED", "x")

		// --- When ---
		err := run(rng)

		// --- Then ---
		assert.NoError(t, err)
		want := "" +
			"C42_HOST='registry.acme.io'\n" +
			"C42_REPO='registry.acme.io/ctx42'\n"
		assert.Equal(t, want, tst.Stdout())
		want = "[dkigo] override C42_HOST=registry.acme.io\n"
		assert.Equal(t, want, tst.Stderr())
	})

	t.Run("current directory", func(t *testing.T) {
		// --- Given ---
		root := t.TempDir()
		cfg := "C42_A=a\n"
		oskit.Write(t, cfg, oskit.MkdirAll(t, root, "configs"), "project.conf")
		t.Chdir(root)

		tst := ringtest.New(t).WetStdout()
		rng := tst.Ring()

		// --- When ---
		err := run(rng)

		// --- Then ---
		assert.NoError(t, err)
		assert.Equal(t, "C42_A='a'\n", tst.Stdout())
	})

	t.Run("error - too many arguments", func(t *testing.T) {
		// --- Given ---
		rng := ringtest.New(t).Ring("a", "b")

		// --- When ---
		err := run(rng)

		// --- Then ---
		assert.ErrorIs(t, errTooManyArgs, err)
	})

	t.Run("error - no configuration", func(t *testing.T) {
		// --- Given ---
		rng := ringtest.New(t).Ring(t.TempDir())

		// --- When ---
		err := run(rng)

		// --- Then ---
		assert.ErrorIs(t, fs.ErrNotExist, err)
		assert.ErrorContain(t, "configs/project.conf", err)
	})

	t.Run("error - invalid configuration", func(t *testing.T) {
		// --- Given ---
		root := t.TempDir()
		dir := oskit.MkdirAll(t, root, "configs")
		pth := oskit.Write(t, "invalid\n", dir, "project.conf")
		rng := ringtest.New(t).Ring(root)

		// --- When ---
		err := run(rng)

		// --- Then ---
		assert.ErrorIs(t, dotenv.ErrInvLine, err)
		assert.ErrorEqual(t, pth+": dotenv: invalid config line: 1", err)
	})
}

func Test_quote_tabular(t *testing.T) {
	tt := []struct {
		testN string

		val  string
		want string
	}{
		{"empty", "", "''"},
		{"plain", "abc", "'abc'"},
		{"spaces", "a b", "'a b'"},
		{"dollar", "$HOME", "'$HOME'"},
		{"single quote", "it's", `'it'\''s'`},
	}

	for _, tc := range tt {
		t.Run(tc.testN, func(t *testing.T) {
			// --- When ---
			have := quote(tc.val)

			// --- Then ---
			assert.Equal(t, tc.want, have)
		})
	}
}
