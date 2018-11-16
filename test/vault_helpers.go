package test

import (
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/hashicorp/vault/api"
)

type VaultCluster struct {
	Leader     ssh.Host
	Standby1   ssh.Host
	Standby2   ssh.Host
	UnsealKeys []string
}

func (c *VaultCluster) GetSshHosts() []ssh.Host {
	return []ssh.Host{c.Leader, c.Standby1, c.Standby2}
}

// From: https://www.vaultproject.io/api/system/health.html
type VaultStatus int

const (
	Leader        VaultStatus = 200
	Standby                   = 429
	Uninitialized             = 501
	Sealed                    = 503
)

// Initialize the Vault cluster and unseal each of the nodes by connecting to them over SSH and executing Vault
// commands. The reason we use SSH rather than using the Vault client remotely is we want to verify that the
// self-signed TLS certificate is properly configured on each server so when you're on that server, you don't
// get errors about the certificate being signed by an unknown party.
// Adapted from https://github.com/hashicorp/terraform-aws-vault/blob/141f57642215820ff758200fe63b3a52d7017061/test/vault_helpers.go#L507
func initializeAndUnsealVaultCluster(t *testing.T, projectId string, region string, vaultClusterName string, sshUserName string, sshKeyPair *ssh.KeyPair) *VaultCluster {
	cluster := findVaultClusterNodes(t, projectId, region, vaultClusterName, sshUserName, sshKeyPair)

	verifyCanSsh(t, cluster)
	assertAllNodesBooted(t, cluster)
	initializeVault(t, cluster)

	assertNodeStatus(t, cluster.Leader, Sealed)
	unsealNode(t, cluster.Leader, cluster.UnsealKeys)
	assertNodeStatus(t, cluster.Leader, Leader)

	assertNodeStatus(t, cluster.Standby1, Sealed)
	unsealNode(t, cluster.Standby1, cluster.UnsealKeys)
	assertNodeStatus(t, cluster.Standby1, Standby)

	assertNodeStatus(t, cluster.Standby2, Sealed)
	unsealNode(t, cluster.Standby2, cluster.UnsealKeys)
	assertNodeStatus(t, cluster.Standby2, Standby)

	return cluster
}

// Find the nodes in the given Vault Instance Group and return them in a VaultCluster struct
func findVaultClusterNodes(t *testing.T, projectId string, region string, vaultClusterName string, sshUserName string, sshKeyPair *ssh.KeyPair) *VaultCluster {
	vaultInstanceGroup := gcp.FetchRegionalInstanceGroup(t, projectId, region, vaultClusterName)
	publicIps := vaultInstanceGroup.GetPublicIps(t, projectId)

	if len(publicIps) != 3 {
		t.Fatalf("Expected to get three IP addresses for Vault cluster, but got %d: %v", len(publicIps), publicIps)
	}

	return &VaultCluster{
		Leader: ssh.Host{
			Hostname:    publicIps[0],
			SshUserName: sshUserName,
			SshKeyPair:  sshKeyPair,
		},

		Standby1: ssh.Host{
			Hostname:    publicIps[1],
			SshUserName: sshUserName,
			SshKeyPair:  sshKeyPair,
		},

		Standby2: ssh.Host{
			Hostname:    publicIps[2],
			SshUserName: sshUserName,
			SshKeyPair:  sshKeyPair,
		},
	}
}

// Wait until we can connect to each of the Vault cluster EC2 Instances
func verifyCanSsh(t *testing.T, cluster *VaultCluster) {
	for _, host := range cluster.GetSshHosts() {
		if host.Hostname != "" {

			maxRetries := 30
			sleepBetweenRetries := 10 * time.Second
			description := fmt.Sprintf("Attempting SSH connection to %s\n", host.Hostname)

			retry.DoWithRetry(t, description, maxRetries, sleepBetweenRetries, func() (string, error) {
				return "", ssh.CheckSshConnectionE(t, host)
			})
		}
	}
}

// Wait until the Vault servers are booted the very first time on the Compute Instances. As a simple solution, we simply
// wait for the leader to boot and assume if it's up, the other nodes will be, too.
func assertAllNodesBooted(t *testing.T, cluster *VaultCluster) {
	for _, node := range cluster.GetSshHosts() {
		if node.Hostname != "" {
			logger.Logf(t, "Waiting for Vault to boot the first time on host %s. Expecting it to be in uninitialized status (%d).", node.Hostname, int(Uninitialized))
			assertNodeStatus(t, node, Uninitialized)
		}
	}
}

// Initialize the Vault cluster, filling in the unseal keys in the given vaultCluster struct
func initializeVault(t *testing.T, vaultCluster *VaultCluster) {
	logger.Logf(t, "Initializing the cluster")
	output := ssh.CheckSshCommand(t, vaultCluster.Leader, "vault operator init")
	vaultCluster.UnsealKeys = parseUnsealKeysFromVaultInitResponse(t, output)
}

// Unseal the given Vault host using the given unseal keys
func unsealNode(t *testing.T, host ssh.Host, unsealKeys []string) {
	unsealCommands := []string{}
	for _, unsealKey := range unsealKeys {
		unsealCommands = append(unsealCommands, fmt.Sprintf("vault operator unseal %s", unsealKey))
	}

	unsealCommand := strings.Join(unsealCommands, " && ")

	logger.Logf(t, "Unsealing Vault on host %s", host.Hostname)
	ssh.CheckSshCommand(t, host, unsealCommand)
}

// Parse an unseal key from a single line of the stdout of the vault init command, which should be of the format:
//
// Unseal Key 1: Gi9xAX9rFfmHtSi68mYOh0H3H2eu8E77nvRm/0fsuwQB
func parseUnsealKey(t *testing.T, str string) string {
	UnsealKeyRegex := regexp.MustCompile("^Unseal Key \\d: (.+)$")
	matches := UnsealKeyRegex.FindStringSubmatch(str)
	if len(matches) != 2 {
		t.Fatalf("Unexpected format for unseal key: %s", str)
	}
	return matches[1]
}

// Parse the unseal keys from the stdout returned from the vault init command.
//
// The format we're expecting is:
//
// Unseal Key 1: Gi9xAX9rFfmHtSi68mYOh0H3H2eu8E77nvRm/0fsuwQB
// Unseal Key 2: ecQjHmaXc79GtwJN/hYWd/N2skhoNgyCmgCfGqRMTPIC
// Unseal Key 3: LEOa/DdZDgLHBqK0JoxbviKByUAgxfm2dwK4y1PX6qED
// Unseal Key 4: ZY87ijsj9/f5fO7ufgr4yhPWU/2ZZM3BGuSQRDFZpwoE
// Unseal Key 5: MAiCaGrtikp4zU4XppC1A8IhKPXRlzj19+a3lcbCAVkF
func parseUnsealKeysFromVaultInitResponse(t *testing.T, vaultInitResponse string) []string {
	lines := strings.Split(vaultInitResponse, "\n")
	if len(lines) < 3 {
		t.Fatalf("Did not find at least three lines of in the vault init stdout: %s", vaultInitResponse)
	}

	// By default, Vault requires 3 unseal keys out of 5, so just parse those first three
	unsealKey1 := parseUnsealKey(t, lines[0])
	unsealKey2 := parseUnsealKey(t, lines[1])
	unsealKey3 := parseUnsealKey(t, lines[2])

	return []string{unsealKey1, unsealKey2, unsealKey3}
}

// Check that the given Vault node has the given status
func assertNodeStatus(t *testing.T, host ssh.Host, expectedStatus VaultStatus) {

	maxRetries := 30
	sleepBetweenRetries := 10 * time.Second
	description := fmt.Sprintf("Check that the Vault node %s has status %d", host.Hostname, int(expectedStatus))

	out := retry.DoWithRetry(t, description, maxRetries, sleepBetweenRetries, func() (string, error) {
		return checkStatus(t, host, expectedStatus)
	})

	logger.Logf(t, out)
}

// Check the status of the given Vault node and ensure it matches the expected status. Note that we use curl to do the
// status check so we can ensure that TLS certificates work for curl (and not just the Vault client).
func checkStatus(t *testing.T, host ssh.Host, expectedStatus VaultStatus) (string, error) {
	curlCommand := "curl -s -o /dev/null -w '%{http_code}' https://127.0.0.1:8200/v1/sys/health"
	logger.Logf(t, "Using curl to check status of Vault server %s: %s", host.Hostname, curlCommand)

	output, err := ssh.CheckSshCommandE(t, host, curlCommand)
	if err != nil {
		return "", err
	}
	status, err := strconv.Atoi(output)
	if err != nil {
		return "", err
	}

	if status == int(expectedStatus) {
		return fmt.Sprintf("Got expected status code %d", status), nil
	} else {
		return "", fmt.Errorf("Expected status code %d for host %s, but got %d", int(expectedStatus), host.Hostname, status)
	}
}

// Use the Vault client to connect to the Vault cluster via the public DNS entry, and make sure it works without
// Vault or TLS errors
func testVault(t *testing.T, domainName string) {

	maxRetries := 30
	sleepBetweenRetries := 10 * time.Second
	description := fmt.Sprintf("Testing Vault at domain name %s", domainName)

	vaultClient := createVaultClient(t, domainName)

	out := retry.DoWithRetry(t, description, maxRetries, sleepBetweenRetries, func() (string, error) {
		isInitialized, err := vaultClient.Sys().InitStatus()
		if err != nil {
			return "", err
		}
		if isInitialized {
			return "Successfully verified that Vault cluster is initialized!", nil
		} else {
			return "", fmt.Errorf("expected Vault cluster to be initialized, but it is not")
		}
	})

	logger.Logf(t, out)
}

// Create a Vault client configured to talk to Vault running at the given domain name
func createVaultClient(t *testing.T, domainName string) *api.Client {
	config := api.DefaultConfig()
	config.Address = fmt.Sprintf("https://%s", domainName)

	// The TLS cert we are using in this test does not have the ELB DNS name in it, so disable the TLS check
	clientTLSConfig := config.HttpClient.Transport.(*http.Transport).TLSClientConfig
	clientTLSConfig.InsecureSkipVerify = true

	client, err := api.NewClient(config)
	if err != nil {
		t.Fatalf("Failed to create Vault client: %v", err)
	}

	return client
}