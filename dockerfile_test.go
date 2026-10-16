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
