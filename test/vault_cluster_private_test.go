package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

func runVaultPrivateClusterTest(t *testing.T, osName string) {
	exampleDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/vault-cluster-private")

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		terraform.Destroy(t, terraformOptions)
	})

	defer test_structure.RunTestStage(t, "log", func() {
		writeVaultLogs(t, "vaultPublicCluster", exampleDir)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		projectId := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_REGION_NAME)
		imageID := test_structure.LoadArtifactID(t, WORK_DIR)

		// GCP only supports lowercase names for some resources
		uniqueID := strings.ToLower(random.UniqueId())

		consulClusterName := fmt.Sprintf("consul-test-%s", uniqueID)
		vaultClusterName := fmt.Sprintf("vault-test-%s", uniqueID)

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

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		projectId := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_REGION_NAME)
		instanceGroupId := terraform.OutputRequired(t, terraformOptions, TFOUT_INSTANCE_GROUP_ID)

		sshUserName := "terratest"
		keyPair := ssh.GenerateRSAKeyPair(t, 2048)
		saveKeyPair(t, exampleDir, keyPair)
		addKeyPairToInstancesInGroup(t, projectId, region, instanceGroupId, keyPair, sshUserName)

		cluster := initializeAndUnsealVaultCluster(t, projectId, region, instanceGroupId, sshUserName, keyPair)
		testVaultUsesConsulForDns(t, cluster)
	})
}
