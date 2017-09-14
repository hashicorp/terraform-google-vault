# Nginx Run Script

This folder contains a script for configuring and running Nginx on a Vault [Google Cloud](https://cloud.google.com/)
server. This script has been tested on the following operating systems:

* Ubuntu 16.04

There is a good chance it will work on other flavors of Debian as well.




## Quick start

This script assumes you installed it, plus all of its dependencies (including nginx itself), using the [install-nginx 
module](/modules/install-nginx). The default install path is `/opt/nginx/bin`, so to configure and start nginx, you run: 

```
/opt/vault/bin/run-nginx --port 8000
``` 

This will:

1. Generate an nginx configuration file called `nginx.conf` in the nginx config dir (default: `/opt/nginx/config`).
   See [nginx configuration](#nginx-configuration) for details on what this configuration file will contain.
   
1. Generate a [Supervisor](http://supervisord.org/) configuration file called `run-nginx.conf` in the Supervisor
   config dir (default: `/etc/supervisor/conf.d`) with a command that will run nginx:  
   `/opt/nginx/bin/nginx -c $nginx_config_dir/nginx.conf`.

1. Tell Supervisor to load the new configuration file, thereby starting nginx.

We recommend using the `run-nginx` command as part of the [Startup Script](https://cloud.google.com/compute/docs/startupscript),
so that it executes when the Compute Instance is first booting. After running `run-nginx` on that initial boot, the 
`supervisord` configuration will automatically restart nginx if it crashes or the Compute Instance reboots.

See the [startup-script-vault.sh](/examples/vault-cluster-public/startup-script-vault.sh) example for fully-working
sample code.



## Command line Arguments

The `run-nginx` script accepts the following arguments. All arguments are optional. See the script for default values.

| Argument | Description | Default | 
| ------------------ | ------------| ------- | 
| `--port`           | The port on which the HTTP server accepts inbound connections | `8000` |
| `--proxy-pass-url` | The URL to which all inbound requests will be forwarded. | `https://127.0.0.1:8200/v1/sys/health?standbyok=true`| 
| `--pid-folder`     | The local folder that should contain the PID file to be used by nginx. | `/var/run/nginx` | 
| `--config-dir`     | The path to the nginx config folder. | absolute path of `../config`, relative to this script |
| `--bin-dir`        | The path to the folder with the nginx binary. | absolute path of the parent folder of this script |
| `--log-dir`        | The path to the Vault log folder. | absolute path of `../log`, relative to this script. | 
| `--log-level`      | The log verbosity to use with Nginx. | `info` |
| `--user`           | The user to run nginx as. | owner of `--config-dir` |

Example:

```
/opt/vault/bin/run-nginx --port 8000
```




## Nginx configuration

`run-vault` generates a configuration file for Vault called `default.hcl` that tries to figure out reasonable 
defaults for a Vault cluster in AWS. Check out the [Vault Configuration Files 
documentation](https://www.vaultproject.io/docs/configuration/index.html) for what configuration settings are
available.
  
  
### Default configuration

`run-vault` sets the following configuration values by default:

* [storage](https://www.vaultproject.io/docs/configuration/index.html#storage): Configure S3 as the storage backend
  with the following settings:
 
     * [bucket](https://www.vaultproject.io/docs/configuration/storage/s3.html#bucket): Set to the `--s3-bucket`
       parameter.
     * [region](https://www.vaultproject.io/docs/configuration/storage/s3.html#region): Set to the `--s3-bucket-region` 
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
      Set to `https://<PRIVATE_IP>:<CLUSTER_PORT>` where `PRIVATE_IP` is the Instance's private IP fetched from
      [Metadata](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html) and `CLUSTER_PORT` is
      the value passed to `--cluster-port`.  
    * [cluster_addr](https://www.vaultproject.io/docs/configuration/storage/consul.html#cluster_addr): 
      Set to `https://<PRIVATE_IP>:<CLUSTER_PORT>` where `PRIVATE_IP` is the Instance's private IP fetched from
      [Metadata](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html) and `CLUSTER_PORT` is
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
/opt/vault/bin/run-vault --s3-bucket my-vault-bucket --s3-bucket-region us-east-1 --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem --skip-vault-config
```




## How do you handle encryption?

Vault uses TLS to encrypt all data in transit. To configure encryption, you must do the following:

1. [Provide TLS certificates](#provide-tls-certificates)
1. [Consul encryption](#consul-encryption)


### Provide TLS certificates

When you execute the `run-vault` script, you need to provide the paths to the public and private keys of a TLS 
certificate:

```
/opt/vault/bin/run-vault --s3-bucket my-vault-bucket --s3-bucket-region us-east-1 --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem
```

See the [private-tls-cert module](/modules/private-tls-cert) for information on how to generate a TLS certificate.


### Consul encryption

Since this Vault Blueprint uses Consul as a high availability storage backend, you may want to enable encryption for 
Consul too. Note that Vault encrypts any data *before* sending it to a storage backend, so this isn't strictly 
necessary, but may be a good extra layer of security.

By default, the Vault server nodes communicate with a local Consul agent running on the same server over (unencrypted) 
HTTP. However, you can configure those agents to talk to the Consul servers using TLS. Check out the [official Consul 
encryption docs](https://www.consul.io/docs/agent/encryption.html) and the Consul AWS Blueprint [How do you handle 
encryption docs](https://github.com/gruntwork-io/consul-aws-blueprint/tree/master/modules/run-consul#how-do-you-handle-encryption)
for more info.


 

