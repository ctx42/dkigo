// Command scmver prints the version of the dkigo images as shell assignments
// for bin/build.sh and bin/push.sh to evaluate:
//
//	C42_SCM_REV='v0.5.0-dev.3.dirty+g7f93fb4'
//	C42_SCM_HASH='7f93fb4'
//	img_tag='v0.5.0-dev.3.dirty_g7f93fb4'
//	is_release='0'
//
// The version is the one gmtask derives for every ctx42 project, so an image
// is tagged exactly as a binary built by gomake would be stamped. See
// https://github.com/ctx42/gitaid/blob/master/docs/versioning.md for the
// scheme, and C42_BLD_BUMP to override the bump read off the commits.
//
// Only a release moves the `latest` tag, and a release here is narrower than
// gitaid's: a clean checkout sitting exactly on a version tag that is not
// itself a pre-release, so cutting v1.0.0-rc.1 leaves `latest` where it was.
//
// Usage:
//
//	scmver [repository-dir]
//
// The directory defaults to the current working directory.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/Masterminds/semver/v3"
	"github.com/ctx42/gmtask/pkg/gmdkr"
	"github.com/ctx42/gmtask/pkg/gmgo"
	"github.com/ctx42/ring/pkg/ring"
	"github.com/ctx42/xdef/pkg/xdef"
)

// ErrTooManyArgs is returned when more than one repository is given.
var ErrTooManyArgs = errors.New("too many arguments")

func main() {
	rng := ring.New(ring.WithArgs(os.Args[1:]))
	if err := run(context.Background(), rng); err != nil {
		_, _ = fmt.Fprintf(rng.Stderr(), "scmver: %s\n", err)
		os.Exit(1)
	}
}

// run writes the shell assignments for the repository named by the only
// argument in rng, or for the current working directory without one.
//
// The values are quoted but not escaped: a SemVer version and a hex hash
// cannot hold a single quote.
func run(ctx context.Context, rng *ring.Ring) error {
	args := rng.Args()
	if len(args) > 1 {
		return ErrTooManyArgs
	}
	var repo string
	if len(args) == 1 {
		repo = args[0]
	}

	ver, err := gmgo.ProjectVersion(ctx, rng, repo, "")
	if err != nil {
		return fmt.Errorf("derive version: %w", err)
	}

	isRelease := "0"
	if ver.Release {
		tag, err := semver.NewVersion(ver.Tag)
		if err != nil {
			return fmt.Errorf("%s: %w", ver.Tag, err)
		}
		if tag.Prerelease() == "" {
			isRelease = "1"
		}
	}

	format := "%s='%s'\n%s='%s'\nimg_tag='%s'\nis_release='%s'\n"
	_, err = fmt.Fprintf(
		rng.Stdout(),
		format,
		xdef.EnvScmRev, ver.Rev,
		xdef.EnvScmHash, ver.Hash,
		gmdkr.ImgTag(ver.Rev),
		isRelease,
	)
	return err
}
