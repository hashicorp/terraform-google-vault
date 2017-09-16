# Nginx Run Script

This folder contains a script for configuring and running Nginx on a Vault [Google Cloud](https://cloud.google.com/)
server. This script has been tested on the following operating systems:

* Ubuntu 16.04

There is a good chance it will work on other flavors of Debian as well.




## Quick start

This script assumes you installed it, plus all of its dependencies (including nginx itself), using the [install-nginx 
module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-nginx). The default install path is `/opt/nginx/bin`, so to configure and start nginx, you run: 

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

See the [startup-script-vault.sh](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public/startup-script-vault.sh) example for fully-working
sample code.



## Command line Arguments

The `run-nginx` script accepts the following arguments. All arguments are optional. See the script for default values.

| Argument | Description | Default | 
| ------------------ | ------------| ------- | 
| `--port`           | The port on which the HTTP server<br>accepts inbound connections | `8000` |
| `--proxy-pass-url` | The URL to which all inbound requests<br>will be forwarded. | `https://127.0.0.1:8200/v1/sys/health?standbyok=true`| 
| `--pid-folder`     | The local folder that should contain<br>the PID file to be used by nginx. | `/var/run/nginx` | 
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

`run-vault` generates a configuration file for nginx in `/opt/nginx/config/nginx.conf` that configures nginx to forward
all inbound HTTP requests, regardless of their path or URL, to the HTTPS endpoint for the Vault health check.

 

