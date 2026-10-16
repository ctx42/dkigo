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
	// --- Given ---
	dkf := oskit.ReadFileStr(t, "Dockerfile")

	// --- When ---
	have := strings.Count(dkf, "\nRUN --mount=type=bind,from=project,")

	// --- Then ---
	assert.Equal(t, 2, have)
	assert.Contain(t, "\nFROM scratch AS project\n", dkf)
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
