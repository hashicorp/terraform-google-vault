package test

import (
	"testing"
)

func TestVaultClusterWithUbuntuImage(t *testing.T) {
	t.Parallel()
	runVaultPublicClusterTest(t, "googlecompute", "ubuntu")
}
