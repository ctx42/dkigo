package dkigo

// Pin the modules whose versions project.conf names, so go.mod records them
// and Test_moduleVersions_tabular can check the two agree. Importing them from
// a test file keeps them out of the binaries of packages importing dkigo.
import (
	_ "github.com/ctx42/gmtask/pkg/gmprj"
	_ "github.com/ctx42/gomake/pkg/gomake"
)
