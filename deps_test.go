package dkigo

// Pin gomake, whose version the configuration takes from go.mod, so go.mod
// records it. Importing it from a test file keeps it out of the binaries of
// packages importing dkigo. gmtask is pinned by cmd/scmver, which uses it.
import _ "github.com/ctx42/gomake/pkg/gomake"
