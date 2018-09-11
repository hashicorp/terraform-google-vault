# Nginx Install Script

This folder contains a script for installing the [nginx](https://nginx.org) binary on a server. This script is motivated
by the need to expose an HTTP health check endpoint for Vault while requiring that all other Vault endpoints are accessible
via HTTPS only. This need arises from a [Google Cloud limitation](
https://github.com/terraform-providers/terraform-provider-google/issues/18) where only HTTP Health Checks can be associated
with a Target Pool, not HTTPS Health Checks.  
 
You can use this script, along with the [run-nginx script](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-nginx) it installs, to create a [Google Image](
https://cloud.google.com/compute/docs/images) that runs nginx alongside Vault.

This script has been tested on the following operating systems:

* Ubuntu 16.04

There is a good chance it will work on other flavors of Debian as well.

## Why nginx?

Our use case requires that we setup a simple HTTP forwarding proxy, so we had several options available to us. 

We considered using the [Python SimpleHttpServer](https://docs.python.org/2/library/simplehttpserver.html) because we
can expect many OS's to come pre-installed with Python. However, anecdotal experience taught us that this server may fail
when receiving more than one request per second, so this was eliminated as being too brittle.

We considered using the [HTTP Daemon included in the BusyBox package](https://wiki.openwrt.org/doc/howto/http.httpd),
which has a minimal footprint and is optimized for embedded systems. But BusyBox httpd is not well-documented and not
widely used, making it more likely to fall prey to a vulnerability.

So we settled on nginx, a massively popular, mature http server as giving us a nice balance of usability, familiarity,
performance, and minimal security exposure. The major downside of nginx for our use case is that Nginx comes built in 
with its own [process management](https://www.nginx.com/blog/inside-nginx-how-we-designed-for-performance-scale/), however
we wish to have Nginx managed by our preferred process supervisor, supervisord. Getting nginx to work with supervisord
is somewhat cumbersome, but ultimately gives us a clean management model.

## Quick start

To install the Nginx binary, use `git` to clone this repository at a specific tag (see the [releases page](
../../../../releases) for all available tags) and run the `install-nginx` script:

```
git clone --branch <VERSION> https://github.com/hashicorp/terraform-google-vault.git
terraform-google-vault/modules/install-nginx/install-nginx --version 0.5.4
```

The `install-nginx` script will install the nginx binary and the [run-nginx script](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-nginx).
You can then run the `run-nginx` script when the server is booting to configure nginx for use with supervisord and as a
simple HTTP proxy, and start the service.

We recommend running the `install-nginx` script as part of a [Packer](https://www.packer.io/) template to create a
Vault [Google Image](https://cloud.google.com/compute/docs/images) (see the [vault-consul-image example](
/examples/vault-consul-image) for sample code). You can then deploy the Image across a Managed Instance Group using the 
[vault-cluster module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) (see the [vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) and 
[vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) examples for fully-working sample code).




## Command line Arguments

The `install-nginx` script accepts the following REQUIRED arguments:

* `signing-key PATH`: Verify the integrity of the nginx debian packages using the PGP key located at PATH.

The `install-nginx` script accepts the following OPTIONAL arguments:

* `path DIR`: Install nginx into folder DIR.
* `user USER`: The install dirs will be owned by user USER.
* `pid-folder DIR`: The PID file created and managed by Nginx will live in DIR.

Example:

```
install-nginx --signing-key /path/to/nginx-signing-key
```



## How it works

The `install-nginx` script does the following:

1. [Create a user and folders for nginx](#create-a-user-and-folders-for-nginx)
1. [Create PID folder for nginx](#create-the-pid-folder-for-nginx)
1. [Download nginx binary](#download-nginx-binary)
1. [Install nginx](#install-nginx)


### Create a user and folders for nginx

Create an OS user named `ngninx`. Create the following folders, all owned by user `nginx`:

* `/opt/nginx`: base directory for nginx data (configurable via the `--path` argument).
* `/opt/nginx/bin`: directory for nginx binaries.
* `/opt/nginx/config`: directory where nginx looks up configuration.
* `/opt/nginx/log`: directory where the nginx will store log files. Note that these logs pertain to "nginx startup"
  and "nginx shutdown." For nginx usage logs, see `/var/log/nginx`.

### Create the PID folder for nginx 

Because Nginx manages its own processes, it creates a file (usually in `/var/run`) that stores the ID of the nginx process.
But `/var/run` is only writable by the `root` user, so we create a special folder owned by the `nginx` user where this
file can be written. But since `/var/run` is mounted with a `tmpfs` file system, this entire directory will be cleared 
on boot, so the proper way to create this folder isn't to create it now, but to write an instruction that will run on 
boot that will create the desired folder. 

### Download nginx binary

Download the latest stable nginx package from the debian apt repo maintained by nginx, and extract the binary `nginx`
from it.

### Install nginx

Place the `nginx` binary in `/opt/nginx/bin` and make it accessible in the `PATH`. 


## Why use Git to install this code?

We needed an easy way to install these scripts that satisfied a number of requirements, including working on a variety 
of operating systems and supported versioning. Our current solution is to use `git`, but this may change in the future.
See [Package Managers](https://github.com/hashicorp/terraform-aws-consul/blob/master/_docs/package-managers.md) for
a full discussion of the requirements, trade-offs, and why we picked `git`.
