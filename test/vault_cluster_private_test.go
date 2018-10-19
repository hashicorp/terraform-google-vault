package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"path/filepath"
	"strings"
	"testing"
)

func TestIntegrationVaultOpenSourcePrivateClusterUbuntu(t *testing.T) {
	t.Parallel()

	testVaultPrivateCluster(t, "ubuntu-16")
}

func testVaultPrivateCluster(t *testing.T, osName string) {
	exampleDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/vault-cluster-private")
	vaultImageDir := filepath.Join(exampleDir, "examples", "vault-consul-image")
	vaultImagePath := filepath.Join(vaultImageDir, "vault-consul.json")

	test_structure.RunTestStage(t, "build_image", func() {
		projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
		region := gcp.GetRandomRegion(t, projectId, nil, nil)
		zone := gcp.GetRandomZoneForRegion(t, projectId, region)

		test_structure.SaveString(t, exampleDir, SAVED_GCP_PROJECT_ID, projectId)
		test_structure.SaveString(t, exampleDir, SAVED_GCP_REGION_NAME, region)
		test_structure.SaveString(t, exampleDir, SAVED_GCP_ZONE_NAME, zone)

		tlsCert := generateSelfSignedTlsCert(t)
		saveTLSCert(t, vaultImageDir, tlsCert)

		imageID := buildVaultImage(t, vaultImagePath, osName, projectId, zone, tlsCert)
		test_structure.SaveArtifactID(t, exampleDir, imageID)
	})

	defer test_structure.RunTestStage(t, "teardown", func() {
		projectID := test_structure.LoadString(t, exampleDir, SAVED_GCP_PROJECT_ID)
		imageName := test_structure.LoadArtifactID(t, exampleDir)

		image := gcp.FetchImage(t, projectID, imageName)
		image.DeleteImage(t)

		tlsCert := loadTLSCert(t, vaultImageDir)
		cleanupTLSCertFiles(tlsCert)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		projectId := test_structure.LoadString(t, exampleDir, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, exampleDir, SAVED_GCP_REGION_NAME)
		imageID := test_structure.LoadArtifactID(t, exampleDir)

		// GCP only supports lowercase names for some resources
		uniqueID := strings.ToLower(random.UniqueId())

		consulClusterName := fmt.Sprintf("consul-test-%s", uniqueID)
		vaultClusterName := fmt.Sprintf("vault-test-%s", uniqueID)

		test_structure.SaveString(t, exampleDir, SAVED_CONSUL_CLUSTER_NAME, consulClusterName)
		test_structure.SaveString(t, exampleDir, SAVED_VAULT_CLUSTER_NAME, vaultClusterName)

		terraformOptions := &terraform.Options{
			TerraformDir: exampleDir,
			Vars: map[string]interface{}{
				TFVAR_NAME_GCP_PROJECT_ID:                     projectId,
				TFVAR_NAME_GCP_REGION:                         region,
				TFVAR_NAME_CONSUL_SERVER_CLUSTER_NAME:         consulClusterName,
				TFVAR_NAME_CONSUL_SOURCE_IMAGE:                imageID,
				TFVAR_NAME_CONSUL_SERVER_CLUSTER_MACHINE_TYPE: "g1-small",
				TFVAR_NAME_VAULT_CLUSTER_NAME:                 vaultClusterName,
				TFVAR_NAME_VAULT_SOURCE_IMAGE:                 imageID,
				TFVAR_NAME_VAULT_CLUSTER_MACHINE_TYPE:         "g1-small",
			},
		}

		test_structure.SaveTerraformOptions(t, exampleDir, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	// We skip the validation stage for now because, by design, we have no way of reaching this cluster.
	// TODO: Add a test that launches a "Bastion Host" that allows us to reach the Vault cluster
}