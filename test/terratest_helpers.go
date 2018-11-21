package test

import (
	"fmt"
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
const PACKER_VAR_CONSUL_DOWNLOAD_URL = "CONSUL_DOWNLOAD_URL"
const PACKER_VAR_VAULT_DOWNLOAD_URL = "VAULT_DOWNLOAD_URL"

const PACKER_TEMPLATE_PATH = "../examples/vault-consul-image/vault-consul.json"

const SAVED_TLS_CERT = "TlsCert"
const SAVED_KEYPAIR = "KeyPair"

// Use Packer to build the Image in the given Packer template, with the given build name and return the Image ID.
func buildVaultImage(t *testing.T, packerBuildName string, testDir string) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, nil)
	zone := gcp.GetRandomZoneForRegion(t, projectId, region)

	test_structure.SaveString(t, testDir, SAVED_GCP_PROJECT_ID, projectId)
	test_structure.SaveString(t, testDir, SAVED_GCP_REGION_NAME, region)
	test_structure.SaveString(t, testDir, SAVED_GCP_ZONE_NAME, zone)

	tlsCert := generateSelfSignedTlsCert(t)
	saveTLSCert(t, testDir, tlsCert)

	options := &packer.Options{
		Template: PACKER_TEMPLATE_PATH,
		Only:     packerBuildName,
		Vars: map[string]string{
			PACKER_VAR_GCP_PROJECT_ID:  projectId,
			PACKER_VAR_GCP_ZONE:        zone,
			PACKER_VAR_CA_PUBLIC_KEY:   tlsCert.CAPublicKeyPath,
			PACKER_VAR_TLS_PUBLIC_KEY:  tlsCert.PublicKeyPath,
			PAKCER_VAR_TLS_PRIVATE_KEY: tlsCert.PrivateKeyPath,
		},
	}

	imageID := packer.BuildArtifact(t, options)
	test_structure.SaveArtifactID(t, testDir, imageID)
}

func deleteVaultImage(t *testing.T, testDir string) {
	projectID := test_structure.LoadString(t, testDir, SAVED_GCP_PROJECT_ID)
	imageName := test_structure.LoadArtifactID(t, testDir)

	image := gcp.FetchImage(t, projectID, imageName)
	image.DeleteImage(t)

	tlsCert := loadTLSCert(t, testDir)
	cleanupTLSCertFiles(tlsCert)
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

func addKeyPairToInstancesInGroup(t *testing.T, projectId string, region string, instanceGroupId string, keyPair *ssh.KeyPair, sshUserName string) []*gcp.Instance {
	instanceGroup := gcp.FetchRegionalInstanceGroup(t, projectId, region, instanceGroupId)
	instances := getInstancesFromGroup(t, projectId, instanceGroup)

	for _, instance := range instances {
		instance.AddSshKey(t, sshUserName, keyPair.PublicKey)
	}
	return instances
}

func getInstancesFromGroup(t *testing.T, projectId string, instanceGroup *gcp.RegionalInstanceGroup) []*gcp.Instance {
	instances := []*gcp.Instance{}

	retry.DoWithRetry(t, "Getting instances", 10, 10*time.Second, func() (string, error) {
		instances = instanceGroup.GetInstances(t, projectId)

		if len(instances) != 3 {
			return "", fmt.Errorf("Expected to get three instances, but got %d: %v", len(instances), instances)
		}
		return "", nil
	})

	return instances
}
