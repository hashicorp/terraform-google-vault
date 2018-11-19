package test

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
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

// Terraform Outputs
const TFOUT_INSTANCE_GROUP_ID = "instance_group_id"

func TestIntegrationVaultOpenSourcePublicClusterUbuntu(t *testing.T) {
	t.Parallel()

	testVaultPublicCluster(t, "ubuntu-16")
}

func testVaultPublicCluster(t *testing.T, osName string) {
	exampleDir := test_structure.CopyTerraformFolderToTemp(t, "../", ".")

	test_structure.RunTestStage(t, "build_image", func() {
		projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
		region := gcp.GetRandomRegion(t, projectId, nil, nil)
		zone := gcp.GetRandomZoneForRegion(t, projectId, region)

		test_structure.SaveString(t, exampleDir, SAVED_GCP_PROJECT_ID, projectId)
		test_structure.SaveString(t, exampleDir, SAVED_GCP_REGION_NAME, region)
		test_structure.SaveString(t, exampleDir, SAVED_GCP_ZONE_NAME, zone)

		tlsCert := generateSelfSignedTlsCert(t)
		saveTLSCert(t, exampleDir, tlsCert)

		imageID := buildVaultImage(t, PACKER_TEMPLATE_PATH, osName, projectId, zone, tlsCert)
		test_structure.SaveArtifactID(t, exampleDir, imageID)
	})

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		terraform.Destroy(t, terraformOptions)
	})

	defer test_structure.RunTestStage(t, "delete_image", func() {
		projectID := test_structure.LoadString(t, exampleDir, SAVED_GCP_PROJECT_ID)
		imageName := test_structure.LoadArtifactID(t, exampleDir)

		image := gcp.FetchImage(t, projectID, imageName)
		image.DeleteImage(t)

		tlsCert := loadTLSCert(t, exampleDir)
		cleanupTLSCertFiles(tlsCert)
	})

	defer test_structure.RunTestStage(t, "log", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		keyPair := loadKeyPair(t, exampleDir)
		projectId := test_structure.LoadString(t, exampleDir, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, exampleDir, SAVED_GCP_REGION_NAME)
		instanceGroupId := terraform.OutputRequired(t, terraformOptions, TFOUT_INSTANCE_GROUP_ID)
		instanceGroup := gcp.FetchRegionalInstanceGroup(t, projectId, region, instanceGroupId)
		instances := instanceGroup.GetInstances(t, projectId)

		vaultStdOutLogFilePath := "/opt/vault/log/vault-stdout.log"
		vaultStdErrLogFilePath := "/opt/vault/log/vault-error.log"
		sysLogFilePath := "/var/log/syslog"

		instanceIdToLogs := map[string]map[string]string{}
		for _, instance := range instances {
			instanceName := instance.Name
			instanceIdToLogs[instanceName] = getFilesFromInstance(t, instance, &keyPair, vaultStdOutLogFilePath, vaultStdErrLogFilePath, sysLogFilePath)

			localDestDir := filepath.Join("/tmp/logs/", "vaultClusterPublic", instanceName)
			if !files.FileExists(localDestDir) {
				os.MkdirAll(localDestDir, 0755)
			}
			writeLogFile(t, instanceIdToLogs[instanceName][vaultStdOutLogFilePath], filepath.Join(localDestDir, "vault-stdout.log"))
			writeLogFile(t, instanceIdToLogs[instanceName][vaultStdErrLogFilePath], filepath.Join(localDestDir, "vault-error.log"))
			writeLogFile(t, instanceIdToLogs[instanceName][sysLogFilePath], filepath.Join(localDestDir, "syslog"))
		}
	})

	test_structure.RunTestStage(t, "deploy", func() {
		projectId := test_structure.LoadString(t, exampleDir, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, exampleDir, SAVED_GCP_REGION_NAME)
		imageID := test_structure.LoadArtifactID(t, exampleDir)

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
		projectId := test_structure.LoadString(t, exampleDir, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, exampleDir, SAVED_GCP_REGION_NAME)
		instanceGroupId := terraform.OutputRequired(t, terraformOptions, TFOUT_INSTANCE_GROUP_ID)

		sshUserName := "terratest"
		keyPair := ssh.GenerateRSAKeyPair(t, 2048)
		saveKeyPair(t, exampleDir, keyPair)
		addKeyPairToInstancesInGroup(t, projectId, region, instanceGroupId, keyPair, sshUserName)

		cluster := initializeAndUnsealVaultCluster(t, projectId, region, instanceGroupId, sshUserName, keyPair)
		testVault(t, cluster.Leader.Hostname)
	})
}
