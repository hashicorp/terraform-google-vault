package test

import (
	"os"
	"testing"
)

func TestVaultClusterEnterpriseWithUbuntuImage(t *testing.T) {
	t.Parallel()
	runVaultEnterpriseClusterTest(t, "googlecompute", "ubuntu", getUrlFromEnv(t, "VAULT_PACKER_TEMPLATE_VAR_CONSUL_DOWNLOAD_URL"), getUrlFromEnv(t, "VAULT_PACKER_TEMPLATE_VAR_VAULT_DOWNLOAD_URL"))
}

// To test this on CircleCI you need two URLs set as environment variables (VAULT_PACKER_TEMPLATE_VAR_CONSUL_DOWNLOAD_URL
// & VAULT_PACKER_TEMPLATE_VAR_VAULT_DOWNLOAD_URL) so the Vault & Consul Enterprise versions can be downloaded. You would
// also need to set these two variables locally to run the tests. The reason behind this is to prevent the actual url
// from being visible in the code and logs.

// To test this on CircleCI you need a url set as an environment variable, VAULT_AMI_TEMPLATE_VAR_DOWNLOAD_URL
// which you would also have to set locally if you want to run this test locally.
// The reason is to prevent the actual url from being visible on code and logs
func getUrlFromEnv(t *testing.T, key string) string {
	url := os.Getenv(key)
	if url == "" {
		t.Fatalf("Please set the environment variable: %s\n", key)
	}
	return url
}
