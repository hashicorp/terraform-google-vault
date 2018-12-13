package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	TFVAR_NAME_CLIENT_NAME    = "web_client_name"
	TFVAR_NAME_EXAMPLE_SECRET = "example_secret"

	TFOUT_WEB_CLIENT_PUBLIC_IP = "web_client_public_ip"

	EXAMPLE_SECRET = "42"
)

func runVaultIamAuthTest(t *testing.T) {
	exampleDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/vault-cluster-authentication-iam")

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		terraform.Destroy(t, terraformOptions)
	})

	defer test_structure.RunTestStage(t, "log", func() {
		//ToDo: Modify log retrieval to go through a bastion host
		//      Requires adding feature to terratest
		//writeVaultLogs(t, "vaultAuthIam", exampleDir)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		projectId := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_PROJECT_ID)
		region := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_REGION_NAME)
		imageID := test_structure.LoadString(t, WORK_DIR, SAVED_OPEN_SOURCE_VAULT_IMAGE)

		// GCP only supports lowercase names for some resources
		uniqueID := strings.ToLower(random.UniqueId())

		terraformOptions := &terraform.Options{
			TerraformDir: exampleDir,
			Vars: map[string]interface{}{
				TFVAR_NAME_GCP_PROJECT_ID:                     projectId,
				TFVAR_NAME_GCP_REGION:                         region,
				TFVAR_NAME_CONSUL_SERVER_CLUSTER_NAME:         fmt.Sprintf("consul-test-%s", uniqueID),
				TFVAR_NAME_CONSUL_SOURCE_IMAGE:                imageID,
				TFVAR_NAME_CONSUL_SERVER_CLUSTER_MACHINE_TYPE: "g1-small",
				TFVAR_NAME_VAULT_CLUSTER_NAME:                 fmt.Sprintf("vault-test-%s", uniqueID),
				TFVAR_NAME_VAULT_SOURCE_IMAGE:                 imageID,
				TFVAR_NAME_VAULT_CLUSTER_MACHINE_TYPE:         "g1-small",
				TFVAR_NAME_CLIENT_NAME:                        fmt.Sprintf("vault-client-test-%s", uniqueID),
			},
		}

		test_structure.SaveTerraformOptions(t, exampleDir, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		testRequestSecret(t, terraformOptions, EXAMPLE_SECRET)
	})
}

func testRequestSecret(t *testing.T, terraformOptions *terraform.Options, expectedResponse string) {
	webClientPublicIp := terraform.OutputRequired(t, terraformOptions, TFOUT_WEB_CLIENT_PUBLIC_IP)
	url := fmt.Sprintf("http://%s:%s", webClientPublicIp, "8080")
	http_helper.HttpGetWithRetry(t, url, 200, expectedResponse, 30, 10*time.Second)
}
