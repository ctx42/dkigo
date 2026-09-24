package main

import (
	"testing"

	"github.com/ctx42/gmtask/pkg/gmgo"
	"github.com/ctx42/ring/pkg/ring"
	"github.com/ctx42/ring/pkg/ring/ringtest"
	"github.com/ctx42/testing/pkg/assert"
	"github.com/ctx42/testkit/pkg/prjkit"
)

func Test_run(t *testing.T) {
	t.Run("release", func(t *testing.T) {
		// --- Given ---
		ctx := t.Context()

		prj := prjkit.New(t, t.TempDir())
		prj.CreateFileWith("file0 1", "file0.txt")
		cm := prj.GitInitAddAll("v0.4.0")
		prj.Close()

		tst := ringtest.New(t).WetStdout()
		rng := tst.Ring(prj.Root())
		rng.EnvUnset(gmgo.EnvBldBump)

		// --- When ---
		err := run(ctx, rng)

		// --- Then ---
		assert.NoError(t, err)
		want := "" +
			"C42_SCM_REV='v0.4.0'\n" +
			"C42_SCM_HASH='" + cm.Hash + "'\n" +
			"img_tag='v0.4.0'\n" +
			"is_release='1'\n"
		assert.Equal(t, want, tst.Stdout())
	})

	t.Run("development build", func(t *testing.T) {
		// --- Given ---
		ctx := t.Context()

		prj := prjkit.New(t, t.TempDir())
		prj.CreateFileWith("file0 1", "file0.txt")
		prj.GitInitAddAll("v0.4.0")
		prj.CreateFileWith("file0 2", "file0.txt")
		cm := prj.GitCommit("", "feat: a feature")
		prj.Close()

		tst := ringtest.New(t).WetStdout()
		rng := tst.Ring(prj.Root())
		rng.EnvUnset(gmgo.EnvBldBump)

		// --- When ---
		err := run(ctx, rng)

		// --- Then ---
		assert.NoError(t, err)
		want := "" +
			"C42_SCM_REV='v0.5.0-dev.1+g" + cm.Hash + "'\n" +
			"C42_SCM_HASH='" + cm.Hash + "'\n" +
			"img_tag='v0.5.0-dev.1_g" + cm.Hash + "'\n" +
			"is_release='0'\n"
		assert.Equal(t, want, tst.Stdout())
	})

	t.Run("pre-release tag is not a release", func(t *testing.T) {
		// --- Given ---
		ctx := t.Context()

		prj := prjkit.New(t, t.TempDir())
		prj.CreateFileWith("file0 1", "file0.txt")
		cm := prj.GitInitAddAll("v1.0.0-rc.1")
		prj.Close()

		tst := ringtest.New(t).WetStdout()
		rng := tst.Ring(prj.Root())
		rng.EnvUnset(gmgo.EnvBldBump)

		// --- When ---
		err := run(ctx, rng)

		// --- Then ---
		assert.NoError(t, err)
		want := "" +
			"C42_SCM_REV='v1.0.0-rc.1'\n" +
			"C42_SCM_HASH='" + cm.Hash + "'\n" +
			"img_tag='v1.0.0-rc.1'\n" +
			"is_release='0'\n"
		assert.Equal(t, want, tst.Stdout())
	})

	t.Run("bump from the environment", func(t *testing.T) {
		// --- Given ---
		ctx := t.Context()

		prj := prjkit.New(t, t.TempDir())
		prj.CreateFileWith("file0 1", "file0.txt")
		prj.GitInitAddAll("v1.4.0")
		prj.CreateFileWith("file0 2", "file0.txt")
		cm := prj.GitCommit("", "fix: a defect")
		prj.Close()

		tst := ringtest.New(t).WetStdout()
		rng := tst.Ring(prj.Root())
		rng.EnvSet(gmgo.EnvBldBump, "major")

		// --- When ---
		err := run(ctx, rng)

		// --- Then ---
		assert.NoError(t, err)
		want := "" +
			"C42_SCM_REV='v2.0.0-dev.1+g" + cm.Hash + "'\n" +
			"C42_SCM_HASH='" + cm.Hash + "'\n" +
			"img_tag='v2.0.0-dev.1_g" + cm.Hash + "'\n" +
			"is_release='0'\n"
		assert.Equal(t, want, tst.Stdout())
	})

	t.Run("error - not a git repository", func(t *testing.T) {
		// --- Given ---
		ctx := t.Context()
		rng := ring.New(ring.WithArgs([]string{t.TempDir()}))

		// --- When ---
		err := run(ctx, rng)

		// --- Then ---
		want := "derive version: not a git repository"
		assert.ErrorContain(t, want, err)
	})

	t.Run("error - too many arguments", func(t *testing.T) {
		// --- Given ---
		ctx := t.Context()
		rng := ring.New(ring.WithArgs([]string{"a", "b"}))

		// --- When ---
		err := run(ctx, rng)

		// --- Then ---
		assert.ErrorIs(t, ErrTooManyArgs, err)
	})
}
