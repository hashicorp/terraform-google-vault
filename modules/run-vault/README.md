# Vault Run Script

This folder contains a script for configuring and running Vault on an [Google Cloud](https://cloud.google.com) server. This
script has been tested on the following operating systems:

* Ubuntu 16.04

There is a good chance it will work on other flavors of Debian as well.




## Quick start

This script assumes you installed it, plus all of its dependencies (including Vault itself), using the [install-vault
module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault). The default install path is `/opt/vault/bin`, so to start Vault in server mode, you
run:

```
/opt/vault/bin/run-vault --gcs-bucket my-bucket --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem
```

This will:

1. Generate a Vault configuration file called `default.hcl` in the Vault config dir (default: `/opt/vault/config`).
   See [Vault configuration](#vault-configuration) for details on what this configuration file will contain and how
   to override it with your own configuration.

1. Generate a [Supervisor](http://supervisord.org/) configuration file called `run-vault.conf` in the Supervisor
   config dir (default: `/etc/supervisor/conf.d`) with a command that will run Vault:
   `vault server -config=/opt/vault/config`.

1. Tell Supervisor to load the new configuration file, thereby starting Vault.

We recommend using the `run-vault` command as part of the [Startup Script](https://cloud.google.com/compute/docs/startupscript),
so that it executes when the Compute Instance is first booting. After running `run-vault` on that initial boot, the
`supervisord` configuration will automatically restart Vault if it crashes or the Compute Instance reboots.

See the [vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) and
[vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) examples for fully-working sample code.




## Command line Arguments

The `run-vault` script accepts the following **REQUIRED** arguments:

| Argument | Description | Default |
| ---------| ----------- | ------- |
| `--gcs-bucket` | The name of the Google Cloud Storage Bucket<br>where Vault data should be stored. ||
| `--tls-cert-file` | Specifies the path to the certificate for TLS.<br>To use a CA certificate, concatenate the<br>primary certificate and the CA certificate together. ||
| `--tls-key-file` | Specifies the path to the private key for the certificate. ||

The `run-vault` script accepts the following **OPTIONAL** arguments:

| Argument | Description | Default |
| ---------| ----------- | ------- |
| `--gcp-creds-file` | The file path on the Compute Instance of a<br>JSON file that stores credentials for a<br>GCP Service Account that has read-write access<br>to the configured GCS Bucket. ||
| `--port` | The port for Vault to listen on. | `8200` |
| `--cluster-port` | The port for Vault to listen on for<br>server-to-server requests. | `--port` + 1 |
| `--config-dir` | The path to the Vault config folder. | absolute path of `../config`,<br>relative to the `run-vault` script itself. |
| `--bin-dir` | The path to the folder with Vault binary. | absolute path of the parent<br>folder of this script. |
| `--log-dir` | The path to the Vault log folder. | absolute path of `../log`,<br>relative to this script. |
| `--log-level` | The log verbosity to use with Vault. | `info` |
| `--user` | The user to run Vault as. | owner of `config-dir`. |
| `--skip-vault-config` | If this flag is set, don't generate a Vault<br>configuration file. This is useful if<br>you have a custom configuration file<br>and don't want to use any of<br>the default settings from `run-vault`. ||

Example:

```
/opt/vault/bin/run-vault --gcs-bucket my-vault-bucket --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem
```




## Vault configuration

`run-vault` generates a configuration file for Vault called `default.hcl` that tries to figure out reasonable
defaults for a Vault cluster in Google Cloud. Check out the [Vault Configuration Files
documentation](https://www.vaultproject.io/docs/configuration/index.html) for what configuration settings are
available.


### Default configuration

`run-vault` sets the following configuration values by default:

* [api_addr](https://www.vaultproject.io/docs/configuration/index.html#api_addr):
  Set to `https://<PRIVATE_IP>:<PORT>` where `PRIVATE_IP` is the Instance's private IP fetched from
  [Metadata](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html) and `PORT` is
  the value passed to `--port`.
* [cluster_addr](https://www.vaultproject.io/docs/configuration/storage/consul.html#cluster_addr):
  Set to `https://<PRIVATE_IP>:<CLUSTER_PORT>` where `PRIVATE_IP` is the Instance's private IP and `CLUSTER_PORT` is
  the value passed to `--cluster-port`.

* [storage](https://www.vaultproject.io/docs/configuration/index.html#storage): Configure GCS as the storage backend
  with the following settings:

     * [bucket](https://www.vaultproject.io/docs/configuration/storage/google-cloud.html#bucket): Set to the `--gcs-bucket`
       parameter.

* [ha_storage](https://www.vaultproject.io/docs/configuration/index.html#ha_storage): Configure Consul as the [high
  availability](https://www.vaultproject.io/docs/concepts/ha.html) storage backend with the following settings:

    * [address](https://www.vaultproject.io/docs/configuration/storage/consul.html#address): Set the address to
      `127.0.0.1:8500`. This is based on the assumption that the Consul agent is running on the same server.
    * [scheme](https://www.vaultproject.io/docs/configuration/storage/consul.html#scheme): Set to `http` since our
      connection is to a Consul agent running on the same server.
    * [path](https://www.vaultproject.io/docs/configuration/storage/consul.html#path): Set to `vault/`.
    * [service](https://www.vaultproject.io/docs/configuration/storage/consul.html#service): Set to `vault`.
    * [redirect_addr](https://www.vaultproject.io/docs/configuration/storage/consul.html#redirect_addr):
      Set to `https://<PRIVATE_IP>:<CLUSTER_PORT>` where `PRIVATE_IP` is the Instance's private IP and `CLUSTER_PORT` is
      the value passed to `--cluster-port`.

* [listener](https://www.vaultproject.io/docs/configuration/index.html#listener): Configure a [TCP
  listener](https://www.vaultproject.io/docs/configuration/listener/tcp.html) with the following settings:

    * [address](https://www.vaultproject.io/docs/configuration/listener/tcp.html#address): Bind to `0.0.0.0:<PORT>`
      where `PORT` is the value passed to `--port`.
    * [cluster_address](https://www.vaultproject.io/docs/configuration/listener/tcp.html#cluster_address): Bind to
      `0.0.0.0:<CLUSTER_PORT>` where `CLUSTER` is the value passed to `--cluster-port`.
    * [tls_cert_file](https://www.vaultproject.io/docs/configuration/listener/tcp.html#tls_cert_file): Set to the
      `--tls-cert-file` parameter.
    * [tls_key_file](https://www.vaultproject.io/docs/configuration/listener/tcp.html#tls_key_file): Set to the
      `--tls-key-file` parameter.


### Overriding the configuration

To override the default configuration, simply put your own configuration file in the Vault config folder (default:
`/opt/vault/config`), but with a name that comes later in the alphabet than `default.hcl` (e.g.
`my-custom-config.hcl`). Vault will load all the `.hcl` configuration files in the config dir and merge them together
in alphabetical order, so that settings in files that come later in the alphabet will override the earlier ones.

For example, to set a custom `cluster_name` setting, you could create a file called `name.hcl` with the
contents:

```hcl
cluster_name = "my-custom-name"
```

If you want to override *all* the default settings, you can tell `run-vault` not to generate a default config file
at all using the `--skip-vault-config` flag:

```
/opt/vault/bin/run-vault --gcs-bucket my-vault-bucket --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem --skip-vault-config
```




## How do you handle encryption?

Vault uses TLS to encrypt all data in transit. To configure encryption, you must do the following:

1. [Provide TLS certificates](#provide-tls-certificates)
1. [Consul encryption](#consul-encryption)


### Provide TLS certificates

When you execute the `run-vault` script, you need to provide the paths to the public and private keys of a TLS
certificate:

```
/opt/vault/bin/run-vault --gcs-bucket my-vault-bucket --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem
```

See the [private-tls-cert module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/private-tls-cert) for information on how to generate a TLS certificate.


### Consul encryption

Since this Vault Module uses Consul as a high availability storage backend, you may want to enable encryption for
Consul too. Note that Vault encrypts any data *before* sending it to a storage backend, so this isn't strictly
necessary, but may be a good extra layer of security.

By default, the Vault server nodes communicate with a local Consul agent running on the same server over (unencrypted)
HTTP. However, you can configure those agents to talk to the Consul servers using TLS. Check out the [official Consul
encryption docs](https://www.consul.io/docs/agent/encryption.html) and the Consul GCP Module [How do you handle
encryption docs](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/run-consul#how-do-you-handle-encryption)
for more info.
