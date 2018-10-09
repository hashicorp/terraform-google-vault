package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/robmorgan/terratest/modules/random"
)

const (
	// RepoRoot represents the root of the project.
	RepoRoot = "../"

	PackerTemplatePath         = "../examples/vault-consul-image/vault-consul.json"
	VaultClusterPrivatePath    = "examples/vault-cluster-private"
	VaultClusterPublicPath     = "examples/vault-cluster-public"
	VaultClusterEnterprisePath = "examples/vault-cluster-enterprise"

	VaultClusterExampleVarProject = "gcp_project"
	VaultClusterExampleVarRegion  = "gcp_region"
	VaultClusterExampleVarZone    = "gcp_zone"

	VaultClusterExampleVarVaultSourceImage         = "vault_source_image"
	VaultClusterExampleVarConsulSourceImage        = "consul_server_source_image"
	VaultClusterExampleVarVaultClusterMachineType  = "vault_cluster_machine_type"
	VaultClusterExampleVarConsulClusterMachineType = "consul_server_machine_type"

	VaultClusterAllowedInboundCidrBlockHttpApi = "allowed_inbound_cidr_blocks_api"
	VaultClusterExampleCreateKmsCryptoKey      = "create_kms_crypto_key"
	VaultClusterExampleKmsCryptoKeyName        = "kms_crypto_key_name"
	VaultClusterExampleKmsCryptoKeyRingName    = "kms_crypto_key_ring_name"
	VaultClusterExampleVarVaultClusterName     = "vault_cluster_name"
	VaultClusterExampleVarConsulClusterName    = "consul_server_cluster_name"

	VaultClusterExampleVarAutoUnsealProject     = "vault_auto_unseal_project_id"
	VaultClusterExampleVarAutoUnsealRegion      = "vault_auto_unseal_region"
	VaultClusterExampleVarAutoUnsealKeyRingName = "vault_auto_unseal_key_ring"
	VaultClusterExampleVarAutoUnsealCryptoKey   = "vault_auto_unseal_crypto_key"
	VaultClusterExampleVarSecret                = "example_secret"

	// Terratest var names
	GCPProjectIdVarName = "GCPProjectID"
	GCPRegionVarName    = "GCPRegion"
	GCPZoneVarName      = "GCPZone"
)

// Test the Vault private cluster example by:
//
// 1. Copy the code in this repo to a temp folder so tests on the Terraform code can run in parallel without the
//    state files overwriting each other.
// 2. Build the Image in the vault-consul-image example with the given build name
// 3. Deploy that Image using the example Terraform code
// 4. SSH to a Vault node and initialize the Vault cluster
// 5. SSH to each Vault node and unseal it
// 6. SSH to a Vault node and make sure you can communicate with the nodes via Consul-managed DNS
func runVaultPrivateClusterTest(t *testing.T, packerBuildName string, sshUserName string) {
	// TODO - wip
}

// Test the Vault public cluster example by:
//
// 1. Copy the code in this repo to a temp folder so tests on the Terraform code can run in parallel without the
//    state files overwriting each other.
// 2. Build the Image in the vault-consul-image example with the given build name
// 3. Deploy that Image using the example Terraform code
// 4. SSH to a Vault node and initialize the Vault cluster
// 5. SSH to each Vault node and unseal it
// 6. Connect to the Vault cluster via the ELB
func runVaultPublicClusterTest(t *testing.T, packerBuildName string, sshUserName string) {
	// TODO - wip
}

// Test the Vault enterprise cluster example by:
//
// 1. Copy the code in this repo to a temp folder so tests on the Terraform code can run in parallel without the
//    state files overwriting each other.
// 2. Build the Cloud Image in the vault-consul-image example with the given build name and the enterprise packages
// 3. Deploy that Image using the example Terraform code
// 4. TODO - SSH into a Vault node and initialize the Vault cluster
// 5. TODO - SSH to each Vault node and unseal it
// 6. TODO - SSH to a Vault node and make sure you can communicate with the nodes via Consul-managed DNS
// 7. TODO - SSH to a Vault node and check if Vault enterprise is installed properly
func runVaultEnterpriseClusterTest(t *testing.T, packerBuildName string, sshUserName string, consulDownloadURL string, vaultDownloadURL string) {
	exampleDir := test_structure.CopyTerraformFolderToTemp(t, RepoRoot, VaultClusterEnterprisePath)
	_ = sshUserName

	test_structure.RunTestStage(t, "build_image", func() {
		// Get the Project Id to use
		gcpProjectID := gcp.GetGoogleProjectIDFromEnvVar(t)

		// Pick a random GCP region to test in. This helps ensure your code works in all regions and zones.
		gcpRegion := gcp.GetRandomRegion(t, gcpProjectID, nil, nil)
		gcpZone := gcp.GetRandomZoneForRegion(t, gcpProjectID, gcpRegion)

		test_structure.SaveString(t, exampleDir, GCPProjectIdVarName, gcpProjectID)
		test_structure.SaveString(t, exampleDir, GCPRegionVarName, gcpRegion)
		test_structure.SaveString(t, exampleDir, GCPZoneVarName, gcpZone)

		tlsCert := generateSelfSignedTlsCert(t)
		saveTLSCert(t, exampleDir, tlsCert)

		// Make sure the Packer build completes successfully
		imageID := buildImageWithDownloadEnv(t, PackerTemplatePath, packerBuildName, gcpProjectID, gcpZone, tlsCert, consulDownloadURL, vaultDownloadURL)
		test_structure.SaveArtifactID(t, exampleDir, imageID)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		// GCP only supports lowercase names for some resources
		uniqueID := strings.ToLower(random.UniqueId())
		imageID := test_structure.LoadArtifactID(t, exampleDir)
		projectID := test_structure.LoadString(t, exampleDir, GCPProjectIdVarName)
		gcpRegion := test_structure.LoadString(t, exampleDir, GCPRegionVarName)
		gcpZone := test_structure.LoadString(t, exampleDir, GCPZoneVarName)

		//keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)
		//test_structure.SaveEc2KeyPair(t, examplesDir, keyPair)

		terraformOptions := &terraform.Options{
			TerraformDir: exampleDir,
			Vars: map[string]interface{}{
				//	VAR_CONSUL_CLUSTER_TAG_KEY: fmt.Sprintf("consul-test-%s", uniqueId),
				//	VAR_SSH_KEY_NAME:           keyPair.Name,
				VaultClusterExampleVarProject:                  projectID,
				VaultClusterExampleVarRegion:                   gcpRegion,
				VaultClusterExampleVarZone:                     gcpZone,
				VaultClusterExampleVarVaultClusterName:         fmt.Sprintf("vault-test-%s", uniqueID),
				VaultClusterExampleVarConsulClusterName:        fmt.Sprintf("consul-test-%s", uniqueID),
				VaultClusterExampleVarVaultClusterMachineType:  "n1-standard-1",
				VaultClusterExampleVarConsulClusterMachineType: "n1-standard-1",
				VaultClusterExampleVarConsulSourceImage:        imageID,
				VaultClusterExampleVarVaultSourceImage:         imageID,
				VaultClusterAllowedInboundCidrBlockHttpApi:     []string{"0.0.0.0/0"},
				VaultClusterExampleCreateKmsCryptoKey:          false,
				VaultClusterExampleKmsCryptoKeyName:            "vault-test",
				VaultClusterExampleKmsCryptoKeyRingName:        "global/gruntwork-test",
				VaultClusterExampleVarAutoUnsealProject:        projectID,
				VaultClusterExampleVarAutoUnsealRegion:         gcpRegion,
				VaultClusterExampleVarAutoUnsealKeyRingName:    "global/gruntwork-test",
				VaultClusterExampleVarAutoUnsealCryptoKey:      "vault-test",
				VaultClusterExampleVarSecret:                   fmt.Sprintf("example-secret-%s", uniqueID),
			},
		}
		test_structure.SaveTerraformOptions(t, exampleDir, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	defer test_structure.RunTestStage(t, "teardown", func() {
		projectID := test_structure.LoadString(t, exampleDir, GCPProjectIdVarName)
		imageName := test_structure.LoadArtifactID(t, exampleDir)
		image := gcp.FetchImage(t, projectID, imageName)
		defer image.DeleteImage(t)

		tlsCert := loadTLSCert(t, exampleDir)
		cleanupTLSCertFiles(tlsCert)
	})
}

// Delete the temporary self-signed cert files we created
func cleanupTLSCertFiles(tlsCert TlsCert) {
	os.Remove(tlsCert.CAPublicKeyPath)
	os.Remove(tlsCert.PrivateKeyPath)
	os.Remove(tlsCert.PublicKeyPath)
}
