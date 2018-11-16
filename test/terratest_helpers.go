package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

// PACKER_VAR_GCP_PROJECT_ID represents the Project ID variable in the Packer template
const PACKER_VAR_GCP_PROJECT_ID = "project_id"

// PACKER_VAR_GCP_ZONE represents the Zone variable in the Packer template
const PACKER_VAR_GCP_ZONE = "zone"

const PACKER_VAR_CA_PUBLIC_KEY = "ca_public_key_path"
const PACKER_VAR_TLS_PUBLIC_KEY = "tls_public_key_path"
const PAKCER_VAR_TLS_PRIVATE_KEY = "tls_private_key_path"
const PACKER_VAR_CONSUL_DOWNLOAD_URL = "CONSUL_DOWNLOAD_URL"
const PACKER_VAR_VAULT_DOWNLOAD_URL = "VAULT_DOWNLOAD_URL"

const PACKER_TEMPLATE_PATH = "../examples/vault-consul-image/vault-consul.json"

const SAVED_TLS_CERT = "TlsCert"

// Use Packer to build the Image in the given Packer template, with the given build name and return the Image ID.
func buildVaultImage(t *testing.T, packerTemplatePath string, packerBuildName string, gcpProjectID string, gcpZone string, tlsCert TlsCert) string {
	options := &packer.Options{
		Template: packerTemplatePath,
		Only:     packerBuildName,
		Vars: map[string]string{
			PACKER_VAR_GCP_PROJECT_ID:  gcpProjectID,
			PACKER_VAR_GCP_ZONE:        gcpZone,
			PACKER_VAR_CA_PUBLIC_KEY:   tlsCert.CAPublicKeyPath,
			PACKER_VAR_TLS_PUBLIC_KEY:  tlsCert.PublicKeyPath,
			PAKCER_VAR_TLS_PRIVATE_KEY: tlsCert.PrivateKeyPath,
		},
	}

	return packer.BuildArtifact(t, options)
}

func saveTLSCert(t *testing.T, testFolder string, tlsCert TlsCert) {
	test_structure.SaveTestData(t, test_structure.FormatTestDataPath(testFolder, SAVED_TLS_CERT), tlsCert)
}

func loadTLSCert(t *testing.T, testFolder string) TlsCert {
	var tlsCert TlsCert
	test_structure.LoadTestData(t, test_structure.FormatTestDataPath(testFolder, SAVED_TLS_CERT), &tlsCert)
	return tlsCert
}
