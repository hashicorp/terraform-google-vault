package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	// PackerVarGcpProjectID represents the Project ID variable in the Packer template
	PackerVarGcpProjectID = "project_id"

	// PackerVarGcpZone represents the Zone variable in the Packer template
	PackerVarGcpZone = "zone"

	PackerVarCaPublicKey       = "ca_public_key_path"
	PackerVarTlsPublicKey      = "tls_public_key_path"
	PackerVarTlsPrivateKey     = "tls_private_key_path"
	PackerVarConsulDownloadUrl = "CONSUL_DOWNLOAD_URL"
	PackerVarVaultDownloadUrl  = "VAULT_DOWNLOAD_URL"

	SavedTlsCert = "TlsCert"
)

// Use Packer to build the Image in the given Packer template, with the given build name and return the Image ID.
func buildImage(t *testing.T, packerTemplatePath string, packerBuildName string, gcpProjectID string, gcpZone string) string {
	options := &packer.Options{
		Template: packerTemplatePath,
		Only:     packerBuildName,
		Vars: map[string]string{
			PackerVarGcpProjectID: gcpProjectID,
			PackerVarGcpZone:      gcpZone,
		},
	}

	return packer.BuildArtifact(t, options)
}

func buildImageWithDownloadEnv(t *testing.T, packerTemplatePath string, packerBuildName string, gcpProjectID string, gcpZone string, tlsCert TlsCert, consulDownloadUrl string, vaultDownloadUrl string) string {
	options := &packer.Options{
		Template: packerTemplatePath,
		Only:     packerBuildName,
		Vars: map[string]string{
			PackerVarGcpProjectID:  gcpProjectID,
			PackerVarGcpZone:       gcpZone,
			PackerVarCaPublicKey:   tlsCert.CAPublicKeyPath,
			PackerVarTlsPublicKey:  tlsCert.PublicKeyPath,
			PackerVarTlsPrivateKey: tlsCert.PrivateKeyPath,
		},
		Env: map[string]string{
			PackerVarConsulDownloadUrl: consulDownloadUrl,
			PackerVarVaultDownloadUrl:  vaultDownloadUrl,
		},
	}

	return packer.BuildArtifact(t, options)
}

func saveTLSCert(t *testing.T, testFolder string, tlsCert TlsCert) {
	test_structure.SaveTestData(t, test_structure.FormatTestDataPath(testFolder, SavedTlsCert), tlsCert)
}

func loadTLSCert(t *testing.T, testFolder string) TlsCert {
	var tlsCert TlsCert
	test_structure.LoadTestData(t, test_structure.FormatTestDataPath(testFolder, SavedTlsCert), &tlsCert)
	return tlsCert
}
