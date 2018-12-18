package test

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/packer"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	IMAGE_EXAMPLE_PATH            = "../examples/vault-consul-ami/vault-consul.json"
	WORK_DIR                      = "./"
	PACKER_BUILD_NAME             = "ubuntu-16"
	SAVED_OPEN_SOURCE_VAULT_IMAGE = "ImageOpenSourceVault"
	SAVED_ENTERPRISE_VAULT_IMAGE  = "ImageEnterpriseVault"
)

type testCase struct {
	Name string           // Name of the test
	Func func(*testing.T) // Function that runs the test
}

var testCases = []testCase{
	{
		"TestVaultPrivateCluster",
		runVaultPrivateClusterTest,
	},
	{
		"TestVaultPublicCluster",
		runVaultPublicClusterTest,
	},
	{
		"TestVaultEnterpriseClusterAutoUnseal",
		runVaultEnterpriseClusterTest,
	},
	{
		"TestVaultIamAuthentication",
		runVaultIamAuthTest,
	},
	{
		"TestVaultGceAuthentication",
		runVaultGceAuthTest,
	},
}

// To test this on CircleCI you need two URLs set a environment variables(VAULT_PACKER_TEMPLATE_VAR_VAULT_DOWNLOAD_URL)
// so the Vault Enterprise versions can be downloaded. You would also need to set these two variables locally to run the
// tests. The reason behind this is to prevent the actual url from being visible in the code and logs.
func TestMainVaultCluster(t *testing.T) {
	t.Parallel()

	test_structure.RunTestStage(t, "build_images", func() {
		vaultDownloadUrl := getUrlFromEnv(t, "VAULT_PACKER_TEMPLATE_VAR_VAULT_DOWNLOAD_URL")

		projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
		region := gcp.GetRandomRegion(t, projectId, nil, nil)
		zone := gcp.GetRandomZoneForRegion(t, projectId, region)

		test_structure.SaveString(t, WORK_DIR, SAVED_GCP_PROJECT_ID, projectId)
		test_structure.SaveString(t, WORK_DIR, SAVED_GCP_REGION_NAME, region)
		test_structure.SaveString(t, WORK_DIR, SAVED_GCP_ZONE_NAME, zone)

		tlsCert := generateSelfSignedTlsCert(t)
		saveTLSCert(t, WORK_DIR, tlsCert)

		packerImageOptions := map[string]*packer.Options{
			SAVED_OPEN_SOURCE_VAULT_IMAGE: composeImageOptions(t, PACKER_BUILD_NAME, WORK_DIR, ""),
			SAVED_ENTERPRISE_VAULT_IMAGE:  composeImageOptions(t, PACKER_BUILD_NAME, WORK_DIR, vaultDownloadUrl),
		}

		imageIds := packer.BuildArtifacts(t, packerImageOptions)
		test_structure.SaveString(t, WORK_DIR, SAVED_OPEN_SOURCE_VAULT_IMAGE, imageIds[SAVED_OPEN_SOURCE_VAULT_IMAGE])
		test_structure.SaveString(t, WORK_DIR, SAVED_ENTERPRISE_VAULT_IMAGE, imageIds[SAVED_ENTERPRISE_VAULT_IMAGE])
	})

	defer test_structure.RunTestStage(t, "delete_images", func() {
		projectID := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_PROJECT_ID)

		deleteVaultImage(t, WORK_DIR, projectID, SAVED_OPEN_SOURCE_VAULT_IMAGE)
		deleteVaultImage(t, WORK_DIR, projectID, SAVED_ENTERPRISE_VAULT_IMAGE)

		tlsCert := loadTLSCert(t, WORK_DIR)
		cleanupTLSCertFiles(tlsCert)
	})

	t.Run("group", func(t *testing.T) {
		runAllTests(t)
	})
}

func runAllTests(t *testing.T) {
	rand.Seed(time.Now().UnixNano())
	for _, testCase := range testCases {
		// This re-assignment necessary, because the variable testCase is defined and set outside the forloop.
		// As such, it gets overwritten on each iteration of the forloop. This is fine if you don't have concurrent code in the loop,
		// but in this case, because you have a t.Parallel, the t.Run completes before the test function exits,
		// which means that the value of testCase might change.
		// More information at:
		// "Be Careful with Table Driven Tests and t.Parallel()"
		// https://gist.github.com/posener/92a55c4cd441fc5e5e85f27bca008721
		testCase := testCase
		t.Run(fmt.Sprintf("%sWithUbuntu", testCase.Name), func(t *testing.T) {
			t.Parallel()
			testCase.Func(t)
		})
	}
}
