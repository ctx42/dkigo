package dkigo

import (
	"strings"
	"testing"

	"github.com/ctx42/testing/pkg/assert"
	"github.com/ctx42/testkit/pkg/oskit"
)

func Test_Dockerfile_testGoProxy(t *testing.T) {
	// --- Given ---
	dkf := oskit.ReadFileStr(t, "Dockerfile")

	// --- When ---
	_, have, found := strings.Cut(dkf, "\nFROM src-test AS test\n")

	// --- Then ---
	assert.True(t, found)
	assert.NotContain(t, "\nFROM ", have)
	assert.Contain(t, "\nARG C42_GOPROXY=\"\"\n", have)
	assert.Contain(t, "\nARG C42_GOSUMDB=\"\"\n", have)
	want := "" +
		"\nENV GOPROXY=\"$C42_GOPROXY\" \\\n" +
		"    GOSUMDB=\"$C42_GOSUMDB\"\n"
	assert.Contain(t, want, have)
}

func Test_Dockerfile_scriptsExecutable(t *testing.T) {
	// --- Given ---
	dkf := oskit.ReadFileStr(t, "Dockerfile")

	// --- When ---
	have := strings.Count(dkf, "\nCOPY --chmod=0755 scripts/")

	// --- Then ---
	assert.Equal(t, 4, have)
	assert.NotContain(t, "\nCOPY scripts/", dkf)
}

func Test_Dockerfile_projectCA(t *testing.T) {
	// Only "project-ca" may read the whole project context: the images mount
	// /ca from it, so their layers are cached on the certificates alone.

	// --- Given ---
	dkf := oskit.ReadFileStr(t, "Dockerfile")
	mntCA := "\nRUN --mount=type=bind,from=project-ca,source=/ca,"

	// --- When ---
	hPrj := strings.Count(dkf, "\nRUN --mount=type=bind,from=project,")
	hCA := strings.Count(dkf, mntCA)

	// --- Then ---
	assert.Equal(t, 1, hPrj)
	assert.Equal(t, 2, hCA)
	assert.Contain(t, "\nFROM scratch AS project\n", dkf)
	assert.Contain(t, "\nFROM $C42_BLD_IMG_BASE AS project-ca\n", dkf)
	assert.Contain(t, "cp \"$@\" /etc/pki/ca-trust/source/anchors/", dkf)
}

func Test_Dockerfile_gitSSHHosts(t *testing.T) {
	// --- Given ---
	dkf := oskit.ReadFileStr(t, "Dockerfile")

	// --- When ---
	have := strings.Count(dkf, "\nARG C42_BLD_GIT_SSH_HOSTS\n")

	// --- Then ---
	assert.Equal(t, 3, have)
	assert.NotContain(t, "github.com:", dkf)
	assert.NotContain(t, "bitbucket.org", dkf)
	want := "ssh-keyscan -t rsa \"$@\" >> /etc/ssh/ssh_known_hosts"
	assert.Contain(t, want, dkf)
}

func Test_Dockerfile_golintConfig(t *testing.T) {
	// --- Given ---
	dkf := oskit.ReadFileStr(t, "Dockerfile")

	// --- When ---
	have := strings.Count(dkf, "\nARG C42_BLD_GOLINT_CONFIG\n")

	// --- Then ---
	assert.Equal(t, 1, have)
	assert.NotContain(t, "xdev", dkf)
	assert.Contain(t, "wget \"$src\" -O $C42_CTR_ROOT/.golangci.yml", dkf)
	assert.Contain(t, "cp /tmp/golint/.golangci.yml $C42_CTR_ROOT/", dkf)
}
