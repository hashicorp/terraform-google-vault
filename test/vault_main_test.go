package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/test-structure"
)

const IMAGE_EXAMPLE_PATH = "../examples/vault-consul-ami/vault-consul.json"
const WORK_DIR = "./"
const PACKER_BUILD_NAME = "ubuntu-16"

type testCase struct {
	Name string                   // Name of the test
	Func func(*testing.T, string) // Function that runs test. Receives(t, packerOsName)
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
}

func TestMainVaultCluster(t *testing.T) {
	t.Parallel()

	test_structure.RunTestStage(t, "setup_image", func() {
		buildVaultImage(t, PACKER_BUILD_NAME, WORK_DIR)
	})

	defer test_structure.RunTestStage(t, "delete_image", func() {
		deleteVaultImage(t, WORK_DIR)
	})

	t.Run("group", func(t *testing.T) {
		runAllTests(t)
	})

}

func runAllTests(t *testing.T) {
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
			testCase.Func(t, PACKER_BUILD_NAME)
		})
	}
}
