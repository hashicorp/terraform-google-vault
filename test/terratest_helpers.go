package test

import (
	"fmt"
	"math/rand"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

// Terratest saved value names
const SAVED_GCP_PROJECT_ID = "GcpProjectId"
const SAVED_GCP_REGION_NAME = "GcpRegionName"
const SAVED_GCP_ZONE_NAME = "GcpZoneName"

// PACKER_VAR_GCP_PROJECT_ID represents the Project ID variable in the Packer template
const PACKER_VAR_GCP_PROJECT_ID = "project_id"

// PACKER_VAR_GCP_ZONE represents the Zone variable in the Packer template
const PACKER_VAR_GCP_ZONE = "zone"

const PACKER_VAR_CA_PUBLIC_KEY = "ca_public_key_path"
const PACKER_VAR_TLS_PUBLIC_KEY = "tls_public_key_path"
const PAKCER_VAR_TLS_PRIVATE_KEY = "tls_private_key_path"
const PACKER_VAR_VAULT_DOWNLOAD_URL = "VAULT_DOWNLOAD_URL"

const PACKER_TEMPLATE_PATH = "../examples/vault-consul-image/vault-consul.json"

const SAVED_TLS_CERT = "TlsCert"
const SAVED_KEYPAIR = "KeyPair"

// Checks if a required environment variable is set
func getUrlFromEnv(t *testing.T, key string) string {
	url := os.Getenv(key)
	if url == "" {
		t.Fatalf("Please set the environment variable: %s\n", key)
	}
	return url
}

// Compose packer image options
func composeImageOptions(t *testing.T, packerBuildName string, testDir string, vaultDownloadUrl string) *packer.Options {
	projectId := test_structure.LoadString(t, testDir, SAVED_GCP_PROJECT_ID)
	zone := test_structure.LoadString(t, testDir, SAVED_GCP_ZONE_NAME)
	tlsCert := loadTLSCert(t, WORK_DIR)

	return &packer.Options{
		Template: PACKER_TEMPLATE_PATH,
		Only:     packerBuildName,
		Vars: map[string]string{
			PACKER_VAR_GCP_PROJECT_ID:  projectId,
			PACKER_VAR_GCP_ZONE:        zone,
			PACKER_VAR_CA_PUBLIC_KEY:   tlsCert.CAPublicKeyPath,
			PACKER_VAR_TLS_PUBLIC_KEY:  tlsCert.PublicKeyPath,
			PAKCER_VAR_TLS_PRIVATE_KEY: tlsCert.PrivateKeyPath,
		},
		Env: map[string]string{
			PACKER_VAR_VAULT_DOWNLOAD_URL: vaultDownloadUrl,
		},
	}
}

func deleteVaultImage(t *testing.T, testDir string, projectId string, imageFileName string) {
	imageName := test_structure.LoadString(t, testDir, imageFileName)
	image := gcp.FetchImage(t, projectId, imageName)
	image.DeleteImage(t)
}

func saveTLSCert(t *testing.T, testFolder string, tlsCert TlsCert) {
	test_structure.SaveTestData(t, test_structure.FormatTestDataPath(testFolder, SAVED_TLS_CERT), tlsCert)
}

func loadTLSCert(t *testing.T, testFolder string) TlsCert {
	var tlsCert TlsCert
	test_structure.LoadTestData(t, test_structure.FormatTestDataPath(testFolder, SAVED_TLS_CERT), &tlsCert)
	return tlsCert
}

func saveKeyPair(t *testing.T, testFolder string, keyPair *ssh.KeyPair) {
	test_structure.SaveTestData(t, test_structure.FormatTestDataPath(testFolder, SAVED_KEYPAIR), keyPair)
}

func loadKeyPair(t *testing.T, testFolder string) ssh.KeyPair {
	var keyPair ssh.KeyPair
	test_structure.LoadTestData(t, test_structure.FormatTestDataPath(testFolder, SAVED_KEYPAIR), &keyPair)
	return keyPair
}

func getFilesFromInstance(t *testing.T, instance *gcp.Instance, keyPair *ssh.KeyPair, filePaths ...string) map[string]string {
	publicIp := instance.GetPublicIp(t)

	host := ssh.Host{
		SshUserName: "terratest",
		SshKeyPair:  keyPair,
		Hostname:    publicIp,
	}

	useSudo := false
	filesFromtInstance, err := ssh.FetchContentsOfFilesE(t, host, useSudo, filePaths...)
	if err != nil {
		logger.Logf(t, fmt.Sprintf("Error getting log file from instance: %s", err.Error()))
	}

	return filesFromtInstance
}

func writeLogFile(t *testing.T, buffer string, destination string) {
	logger.Logf(t, fmt.Sprintf("Writing log file to %s", destination))
	file, err := os.Create(destination)
	if err != nil {
		logger.Logf(t, fmt.Sprintf("Error creating log file on disk: %s", err.Error()))
	}
	defer file.Close()

	file.WriteString(buffer)
}

func addKeyPairToInstancesInGroup(t *testing.T, projectId string, region string, instanceGroupName string, keyPair *ssh.KeyPair, sshUserName string, expectedInstances int) []*gcp.Instance {
	instanceGroup := gcp.FetchRegionalInstanceGroup(t, projectId, region, instanceGroupName)
	instances := getInstancesFromGroup(t, projectId, instanceGroup, expectedInstances)

	for _, instance := range instances {
		instance.AddSshKey(t, sshUserName, keyPair.PublicKey)
	}
	return instances
}

func getInstancesFromGroup(t *testing.T, projectId string, instanceGroup *gcp.RegionalInstanceGroup, expectedInstances int) []*gcp.Instance {
	instances := []*gcp.Instance{}

	retry.DoWithRetry(t, "Getting instances", 30, 10*time.Second, func() (string, error) {
		instances = instanceGroup.GetInstances(t, projectId)

		if len(instances) != expectedInstances {
			return "", fmt.Errorf("Expected to get %d instances, but got %d: %v", expectedInstances, len(instances), instances)
		}
		return "", nil
	})

	return instances
}

func runCommand(t *testing.T, bastionHost *ssh.Host, targetHost *ssh.Host, command string) (string, error) {
	if bastionHost == nil {
		return ssh.CheckSshCommandE(t, *targetHost, command)
	}
	return ssh.CheckPrivateSshConnectionE(t, *bastionHost, *targetHost, command)
}

func getRandomCidr() string {
	return fmt.Sprintf("10.%d.%d.%d/28", rand.Intn(128), rand.Intn(256), rand.Intn(16)*16)
}
