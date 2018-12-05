package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	TFVAR_NAME_AUTOUNSEAL_KEY_PROJECT     = "vault_auto_unseal_key_project_id"
	TFVAR_NAME_AUTOUNSEAL_KEY_REGION      = "vault_auto_unseal_key_region"
	TFVAR_NAME_AUTOUNSEAL_KEY_RING_NAME   = "vault_auto_unseal_key_ring"
	TFVAR_NAME_AUTOUNSEAL_CRYPTO_KEY_NAME = "vault_auto_unseal_crypto_key_name"
	TFVAR_NAME_SERVICE_ACCOUNT_NAME       = "service_account_name"

	AUTOUNSEAL_KEY_REGION      = "global"
	AUTOUNSEAL_KEY_RING_NAME   = "vault-cluster-automated-tests"
	AUTOUNSEAL_CRYPTO_KEY_NAME = "circle-ci"
	SERVICE_ACCOUNT_NAME       = "circle-ci"
)

// Test the Vault enterprise cluster example by:
//
// 1. Copy the code in this repo to a temp folder so tests on the Terraform code can run in parallel without the
//    state files overwriting each other.
// 2. Build the Cloud Image in the vault-consul-image example with the given build name and the enterprise packages
// 3. Deploy that Image using the example Terraform code
// 4. TODO - SSH to a Vault node and check if Vault enterprise is installed properly
// 5. SSH into a Vault node and initialize the Vault cluster
// 6. SSH to each other Vault node, restart vault and test that it is unsealed
// 7.  SSH to a Vault node and make sure you can communicate with the nodes via Consul-managed DNS
func runVaultEnterpriseClusterTest(t *testing.T) {
	exampleDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/vault-cluster-enterprise")

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		terraform.Destroy(t, terraformOptions)
	})

	defer test_structure.RunTestStage(t, "log", func() {
		//ToDo: Modify log retrieval to go through bastion host
		//      Requires adding feature to terratest
		//writeVaultLogs(t, "vaultEnterpriseCluster", exampleDir)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		projectId := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_REGION_NAME)
		imageID := test_structure.LoadString(t, WORK_DIR, SAVED_ENTERPRISE_VAULT_IMAGE)

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
				TFVAR_NAME_BASTION_SERVER_NAME:                fmt.Sprintf("bastion-test-%s", uniqueID),
				TFVAR_NAME_AUTOUNSEAL_KEY_PROJECT:             projectId,
				TFVAR_NAME_AUTOUNSEAL_KEY_REGION:              AUTOUNSEAL_KEY_REGION,
				TFVAR_NAME_AUTOUNSEAL_KEY_RING_NAME:           AUTOUNSEAL_KEY_RING_NAME,
				TFVAR_NAME_AUTOUNSEAL_CRYPTO_KEY_NAME:         AUTOUNSEAL_CRYPTO_KEY_NAME,
				TFVAR_NAME_SERVICE_ACCOUNT_NAME:               SERVICE_ACCOUNT_NAME,
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

		bastionName := terraform.OutputRequired(t, terraformOptions, TFVAR_NAME_BASTION_SERVER_NAME)
		bastionInstance := gcp.FetchInstance(t, projectId, bastionName)
		bastionInstance.AddSshKey(t, sshUserName, keyPair.PublicKey)
		bastionHost := ssh.Host{
			Hostname:    bastionInstance.GetPublicIp(t),
			SshUserName: sshUserName,
			SshKeyPair:  keyPair,
		}

		cluster := testVaultInitializeAutoUnseal(t, projectId, region, instanceGroupId, sshUserName, keyPair, &bastionHost)
		testVaultUsesConsulForDns(t, cluster, &bastionHost)
	})
}

func testVaultInitializeAutoUnseal(t *testing.T, projectId string, region string, instanceGroupId string, sshUserName string, sshKeyPair *ssh.KeyPair, bastionHost *ssh.Host) *VaultCluster {
	cluster := findVaultClusterNodes(t, projectId, region, instanceGroupId, sshUserName, sshKeyPair, bastionHost)

	verifyCanSsh(t, cluster, bastionHost)
	testVaultIsEnterprise(t, cluster.Leader, bastionHost)

	initializeVault(t, cluster, bastionHost)
	assertNodeStatus(t, cluster.Leader, bastionHost, Leader)

	//Testing that other members of cluster will be unsealed after restarting
	assertNodeStatus(t, cluster.Standby1, bastionHost, Sealed)
	restartVault(t, cluster.Standby1, bastionHost)
	assertNodeStatus(t, cluster.Standby1, bastionHost, Standby)

	assertNodeStatus(t, cluster.Standby2, bastionHost, Sealed)
	restartVault(t, cluster.Standby2, bastionHost)
	assertNodeStatus(t, cluster.Standby2, bastionHost, Standby)
	return cluster
}

func testVaultIsEnterprise(t *testing.T, targetHost ssh.Host, bastionHost *ssh.Host) {
	retry.DoWithRetry(t, "Testing Vault Version", 3, 5*time.Second, func() (string, error) {
		output, err := runCommand(t, bastionHost, &targetHost, "vault --version")
		if !strings.Contains(output, "+ent") {
			return "", fmt.Errorf("This vault package is not the expected enterprise version. Actual version: %s", output)
		}
		return "", err
	})
}

func restartVault(t *testing.T, targetHost ssh.Host, bastionHost *ssh.Host) {
	retry.DoWithRetry(t, "Restarting vault", 3, 5*time.Second, func() (string, error) {
		output, err := runCommand(t, bastionHost, &targetHost, "sudo supervisorctl restart vault")
		logger.Logf(t, "Vault Restarting output: %s", output)
		return output, err
	})
}
