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
	IMAGE_EXAMPLE_PATH = "../examples/vault-consul-ami/vault-consul.json"
	WORK_DIR           = "./"
)

type testCase struct {
	Name string                   // Name of the test
	Func func(*testing.T, string) // Function that runs the test
}

type packerBuild struct {
	SaveName           string // Name of the test data save file
	PackerBuildName    string // Name of the packer build
	useEnterpriseVault bool   // Use Vault Enterprise or not
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

var packerBuilds = []packerBuild{
	{
		"OpenSourceVaultOnUbuntu16ImageID",
		"ubuntu16-image",
		false,
	},
	{
		"OpenSourceVaultOnUbuntu18ImageID",
		"ubuntu18-image",
		false,
	},
	{
		"EnterpriseVaultOnUbuntu16ImageID",
		"ubuntu16-image",
		true,
	},
	{
		"EnterpriseVaultOnUbuntu18ImageID",
		"ubuntu18-image",
		true,
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
		// GCP sets quotas at a low limit for In-use IP addresses and CPUs which fail the tests
		// these have to be requested manually for each region and will break tests every time
		// a new region is introduced. For this reason, I am limiting the tests to us-east1
		region := gcp.GetRandomRegion(t, projectId, []string{"us-east1"}, nil)
		zone := gcp.GetRandomZoneForRegion(t, projectId, region)

		test_structure.SaveString(t, WORK_DIR, SAVED_GCP_PROJECT_ID, projectId)
		test_structure.SaveString(t, WORK_DIR, SAVED_GCP_REGION_NAME, region)
		test_structure.SaveString(t, WORK_DIR, SAVED_GCP_ZONE_NAME, zone)

		tlsCert := generateSelfSignedTlsCert(t)
		saveTLSCert(t, WORK_DIR, tlsCert)

		packerImageOptions := map[string]*packer.Options{}
		for _, packerBuildItem := range packerBuilds {
			packerImageOptions[packerBuildItem.SaveName] = composeImageOptions(t, packerBuildItem.PackerBuildName, WORK_DIR, packerBuildItem.useEnterpriseVault, vaultDownloadUrl)
		}

		imageIds := packer.BuildArtifacts(t, packerImageOptions)
		for imageKey, imageId := range imageIds {
			test_structure.SaveString(t, WORK_DIR, imageKey, imageId)
		}
	})

	defer test_structure.RunTestStage(t, "delete_images", func() {
		projectID := test_structure.LoadString(t, WORK_DIR, SAVED_GCP_PROJECT_ID)

		for _, packerBuildItem := range packerBuilds {
			deleteVaultImage(t, WORK_DIR, projectID, packerBuildItem.SaveName)
		}

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
		for _, packerBuildItem := range packerBuilds {
			packerBuildItem := packerBuildItem
			t.Run(fmt.Sprintf("%sWith%s", testCase.Name, packerBuildItem.SaveName), func(t *testing.T) {
				t.Parallel()
				testCase.Func(t, packerBuildItem.SaveName)
			})
		}
	}
}
