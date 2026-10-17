## v0.10.0 (Sat, 17 Oct 2026 18:18:12 UTC)
- fix(docker)!: give any user of the test image a writable home.

## v0.9.3 (Sat, 17 Oct 2026 16:37:21 UTC)
- perf(docker): cache the CA trust layers on the certificates alone.

## v0.9.2 (Sat, 17 Oct 2026 13:32:41 UTC)
- fix(deps): require gomake v0.31.2 and gmtask v0.19.0 in go.mod.
- test: keep Test_parseCfg independent of pinned versions.

## v0.9.1 (Sat, 17 Oct 2026 10:26:51 UTC)
- build(deps): update gomake to v0.31.2 and gmtask to v0.19.0.

## v0.9.0 (Fri, 16 Oct 2026 21:08:47 UTC)
- fix(docker): copy container scripts with mode 0755.
- build(deps): update dotenv to v0.7.0.
- feat!: apply config overrides before variable expansion.
- docs: describe the override order of the Go package.
- feat(cfgenv): add command printing the build configuration.
- feat(bin)!: resolve the build configuration with cmd/cfgenv.
- docs: describe building images from your own project.
- feat(docker): trust the building project's CA certificates.
- feat(docker): configure the git hosts reached over SSH.
- docs: explain how gomake names the images.
- feat(docker): configure the shared golangci-lint configuration.

## v0.8.2 (Fri, 16 Oct 2026 13:25:21 UTC)
- build(deps): update gmtask to v0.17.0.

## v0.8.1 (Fri, 16 Oct 2026 11:52:39 UTC)
- build: set gomake and gmtask versions in project.conf again.

## v0.8.0 (Fri, 16 Oct 2026 11:42:08 UTC)
- feat(docker): set GOPROXY and GOSUMDB in the test image.

## v0.7.3 (Thu, 15 Oct 2026 15:12:57 UTC)
- build: take gomake and gmtask versions from go.mod.
- chore(deps): update dependencies.

## v0.7.2 (Sat, 10 Oct 2026 19:56:32 UTC)
- build(deps): update gomake to v0.30.3 and gmtask to v0.15.3.

## v0.7.1 (Sat, 10 Oct 2026 19:32:47 UTC)
- build(deps): update 8 ctx42 dependencies.

## v0.7.0 (Sat, 10 Oct 2026 14:01:01 UTC)
- feat: override project.conf keys from the environment.

## v0.6.0 (Fri, 09 Oct 2026 20:14:37 UTC)

## v0.5.1 (Fri, 09 Oct 2026 19:01:33 UTC)
- build(deps): bump gomake to v0.30.0 and gmtask to v0.12.0.
- docs: add the dkigo package overview.
- fix(scmver): wrap the error writing the assignments.
- test(scmver): unset C42_BLD_BUMP in the not-a-repository case.
- refactor: parse the project configuration on first use.
- refactor: return the map lookup directly in CfgLookup.
- refactor(scmver): unexport the too-many-arguments error.
- test(scmver): pass t.Context() inline to run.
- test(scmver): inline the expected not-a-repository error.
- test(scmver): shorten the pre-release subtest name.
- docs: say the Cfg functions return values, not keys.
- docs: drop godoc that restates the code.
- test: fix the existing and missing key subtest names.
- refactor(scmver): parse the release tag with semver.MustParse.
- test(scmver): cover a failed write of the assignments.
- build(deps): bump gomake to v0.30.1.
- docs: install the gomake and gmtask versions the project pins.

## v0.5.0 (Mon, 28 Sep 2026 10:48:31 UTC)
- refactor(build)!: align env variable names with xdef.
- build(deps): bump gomake to v0.27.1 and gmtask to v0.8.0.
- build!: derive image versions from gmtask via cmd/scmver.
- docs: describe the cmd/scmver image versioning.
- build(deps): bump gmtask to v0.9.0.
- build: tidy the Dockerfile.
- docs: recommend gomake for building the images.
- feat(build): push latest from push.sh for releases.

## v0.4.0 (Wed, 15 Jul 2026 18:58:17 UTC)
- chore(deps): bump gmtask to v0.6.0.

## v0.3.0 (Wed, 15 Jul 2026 08:13:44 UTC)
- chore(deps): bump gmtask and testing versions.

## v0.2.0 (Tue, 14 Jul 2026 14:10:38 UTC)
- feat(build): tag release images as latest.

## v0.1.0 (Tue, 14 Jul 2026 13:40:09 UTC)
- Initial commit.
- feat: add base images for CTX42 Go projects.

