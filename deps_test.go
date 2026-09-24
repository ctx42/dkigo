package dkigo

// Pin gomake, whose version project.conf names, so go.mod records it and
// Test_moduleVersions_tabular can check the two agree. Importing it from a
// test file keeps it out of the binaries of packages importing dkigo. The
// gmtask version it checks as well is pinned by cmd/scmver, which uses it.
import _ "github.com/ctx42/gomake/pkg/gomake"
