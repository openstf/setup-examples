## Smartphone Test Farm Setup Examples

This repository contains setup examples of [openstf/stf](https://github.com/openstf/stf) on [various hosts](#supported-hosts) using [Vagrant](https://www.vagrantup.com/) with [VirtualBox](https://www.virtualbox.org/) provider.

## Supported Hosts

## Requirements
- [VirtualBox](https://www.virtualbox.org/) >= 5.0.0
- [Vagrant](https://www.vagrantup.com/) >= 1.7.3

## Setup

```sh
git clone https://github.com/openstf/setup-examples.git stf-setup-examples
cd stf-setup-examples
```

## Run Rethinkdb Cluster

```sh
cd ./db
vagrant up
```
Above command will
- Download **ubuntu/trusty64** image if image is not present (*this may take time depending on internet speed*)
- Launch Ubuntu VM and set its IP to `$rethinkdb_host_ip` configured in [Configuration File](config.rb) (**Default: 198.162.50.11**)
- Install and run rethinkdb server

You can confirm if rethinkdb is up by visiting rethinkdb admin console (http://198.162.50.11:8080 or http://RETHINKDB_HOST_IP:8080)
