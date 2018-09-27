package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	// RepoRoot represents the root of the project.
	RepoRoot = "../"

	PackerTemplatePath      = "../examples/vault-consul-image/vault-consul.json"
	VaultClusterPrivatePath = "examples/vault-cluster-private"

	// Terratest var names
	GCPProjectIdVarName = "GCPProjectID"
	GCPRegionVarName    = "GCPRegion"
	GCPZoneVarName      = "GCPZone"
)

// Test the Vault enterprise cluster example by:
//
// 1. Copy the code in this repo to a temp folder so tests on the Terraform code can run in parallel without the
//    state files overwriting each other.
// 2. Build the Cloud Image in the vault-consul-image example with the given build name and the enterprise package
// 3. Deploy that AMI using the example Terraform code
// 4. SSH to a Vault node and initialize the Vault cluster
// 5. SSH to each Vault node and unseal it
// 6. SSH to a Vault node and make sure you can communicate with the nodes via Consul-managed DNS
// 7. SSH to a Vault node and check if Vault enterprise is installed properly
func runVaultEnterpriseClusterTest(t *testing.T, packerBuildName string, sshUserName string, consulDownloadURL string, vaultDownloadURL string) {
	examplesDir := test_structure.CopyTerraformFolderToTemp(t, RepoRoot, VaultClusterPrivatePath)
	_ = sshUserName

	test_structure.RunTestStage(t, "build_image", func() {
		// Get the Project Id to use
		gcpProjectID := gcp.GetGoogleProjectIDFromEnvVar(t)

		// Pick a random GCP region to test in. This helps ensure your code works in all regions and zones.
		gcpRegion := gcp.GetRandomRegion(t, gcpProjectID, nil, nil)
		gcpZone := gcp.GetRandomZoneForRegion(t, gcpProjectID, gcpRegion)

		test_structure.SaveString(t, examplesDir, GCPProjectIdVarName, gcpProjectID)
		test_structure.SaveString(t, examplesDir, GCPRegionVarName, gcpRegion)
		test_structure.SaveString(t, examplesDir, GCPZoneVarName, gcpZone)

		tlsCert := generateSelfSignedTlsCert(t)
		saveTLSCert(t, examplesDir, tlsCert)

		// Make sure the Packer build completes successfully
		imageID := buildImageWithDownloadEnv(t, PackerTemplatePath, packerBuildName, gcpProjectID, gcpZone, tlsCert, consulDownloadURL, vaultDownloadURL)
		test_structure.SaveArtifactID(t, examplesDir, imageID)
	})

	defer test_structure.RunTestStage(t, "teardown", func() {
		projectID := test_structure.LoadString(t, examplesDir, GCPProjectIdVarName)
		imageName := test_structure.LoadArtifactID(t, examplesDir)
		image := gcp.FetchImage(t, projectID, imageName)
		defer image.DeleteImage(t)

		tlsCert := loadTLSCert(t, examplesDir)
		cleanupTLSCertFiles(tlsCert)
	})
}

// Delete the temporary self-signed cert files we created
func cleanupTLSCertFiles(tlsCert TlsCert) {
	os.Remove(tlsCert.CAPublicKeyPath)
	os.Remove(tlsCert.PrivateKeyPath)
	os.Remove(tlsCert.PublicKeyPath)
}
