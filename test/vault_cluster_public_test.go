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

// Terratest saved value names
const SAVED_GCP_PROJECT_ID = "GcpProjectId"
const SAVED_GCP_REGION_NAME = "GcpRegionName"
const SAVED_GCP_ZONE_NAME = "GcpZoneName"

// Terraform module vars
const TFVAR_NAME_GCP_PROJECT_ID = "gcp_project_id"
const TFVAR_NAME_GCP_REGION = "gcp_region"

const TFVAR_NAME_VAULT_CLUSTER_NAME = "vault_cluster_name"
const TFVAR_NAME_VAULT_SOURCE_IMAGE = "vault_source_image"
const TFVAR_NAME_VAULT_CLUSTER_MACHINE_TYPE = "vault_cluster_machine_type"

const TFVAR_NAME_CONSUL_SOURCE_IMAGE = "consul_server_source_image"
const TFVAR_NAME_CONSUL_SERVER_CLUSTER_NAME = "consul_server_cluster_name"
const TFVAR_NAME_CONSUL_SERVER_CLUSTER_MACHINE_TYPE = "consul_server_machine_type"

func TestIntegrationVaultOpenSourcePublicClusterUbuntu(t *testing.T) {
	t.Parallel()

	testVaultPublicCluster(t, "ubuntu-16")
}

func testVaultPublicCluster(t *testing.T, osName string) {
	exampleDir := test_structure.CopyTerraformFolderToTemp(t, "../", ".")
	vaultImageDir := filepath.Join(exampleDir, "examples", "vault-consul-image")
	vaultImagePath := filepath.Join(vaultImageDir, "vault-consul.json")

	test_structure.RunTestStage(t, "build_image", func() {
		gcpProjectId := gcp.GetGoogleProjectIDFromEnvVar(t)
		gcpRegion := gcp.GetRandomRegion(t, gcpProjectId, nil, nil)
		gcpZone := gcp.GetRandomZoneForRegion(t, gcpProjectId, gcpRegion)

		test_structure.SaveString(t, exampleDir, SAVED_GCP_PROJECT_ID, gcpProjectId)
		test_structure.SaveString(t, exampleDir, SAVED_GCP_REGION_NAME, gcpRegion)
		test_structure.SaveString(t, exampleDir, SAVED_GCP_ZONE_NAME, gcpZone)

		tlsCert := generateSelfSignedTlsCert(t)
		saveTLSCert(t, vaultImageDir, tlsCert)

		imageID := buildVaultImage(t, vaultImagePath, osName, gcpProjectId, gcpZone, tlsCert)
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
		gcpProjectId := test_structure.LoadString(t, exampleDir, SAVED_GCP_PROJECT_ID)
		gcpRegion := test_structure.LoadString(t, exampleDir, SAVED_GCP_REGION_NAME)

		// GCP only supports lowercase names for some resources
		uniqueID := strings.ToLower(random.UniqueId())
		imageID := test_structure.LoadArtifactID(t, exampleDir)

		terraformOptions := &terraform.Options{
			TerraformDir: exampleDir,
			Vars: map[string]interface{}{
				TFVAR_NAME_GCP_PROJECT_ID:                     gcpProjectId,
				TFVAR_NAME_GCP_REGION:                         gcpRegion,
				TFVAR_NAME_VAULT_CLUSTER_NAME:                 fmt.Sprintf("vault-test-%s", uniqueID),
				TFVAR_NAME_VAULT_SOURCE_IMAGE:                 imageID,
				TFVAR_NAME_VAULT_CLUSTER_MACHINE_TYPE:         "g1-small",
				TFVAR_NAME_CONSUL_SERVER_CLUSTER_NAME:         fmt.Sprintf("consul-test-%s", uniqueID),
				TFVAR_NAME_CONSUL_SOURCE_IMAGE:                imageID,
				TFVAR_NAME_CONSUL_SERVER_CLUSTER_MACHINE_TYPE: "g1-small",
			},
		}
		test_structure.SaveTerraformOptions(t, exampleDir, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		// TODO: Fill this in.
	})
}