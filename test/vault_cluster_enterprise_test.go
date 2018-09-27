package test

import (
	"os"
	"testing"
)

func TestVaultClusterEnterpriseWithUbuntuImage(t *testing.T) {
	t.Parallel()
	runVaultEnterpriseClusterTest(t, "googlecompute", "ubuntu", os.Getenv("VAULT_PACKER_TEMPLATE_VAR_CONSUL_DOWNLOAD_URL"), os.Getenv("VAULT_PACKER_TEMPLATE_VAR_VAULT_DOWNLOAD_URL"))
}
