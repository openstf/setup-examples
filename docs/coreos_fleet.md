# Deploy STF Using CoreOS and Fleet

## Requirements
- Install [fleetctl client](https://coreos.com/fleet/docs/latest/launching-containers-fleet.html)
  - On OS X, you can install it using `brew install fleetctl`.
- Make sure that rethinkdb is running by following [these instructions](../README.md#run-rethinkdb-cluster)

## Configuration

### Add hosts
Add below line in your `/etc/hosts`, so that VMs can resolve the domain.

```
172.17.8.101 stf.mydomain.org
```

### Add usb filters
In order to access real devices from VMs, it is necessary to create usb filters. Update [Vagrantfile](../coreos/Vagrantfile) for this. Instructions are written in file itself.

### Start CoreOS Cluster

```sh
cd coreos
vagrant up
```
Above command will do
- Download **CoreOS** image if image is not present (*this may take time depending on internet speed*)
- Launch 3 instances of CoreOS VM.
- You can check if all the instances are running using `vagrant global-status` command


### Configuring fleetctl
Next, we will be launching services inside CoreOS cluster using fleetctl. In order to use fleet client from OS X, we need to export a global variable called FLEETCTL_ENDPOINT. This endpoint will tell fleetctl running on OS X to talk with fleet daemon running inside one of the guest OS.

```sh
export FLEETCTL_ENDPOINT=http://172.17.8.101:2379
```
Using core-01 guest OS.

Now, run `fleetctl list-machines` command, You will see something like below

```sh
MACHINE     IP           METADATA
0f666d32... 172.17.8.103 role=devside
3dfaef6c... 172.17.8.102 role=appside
dc387247... 172.17.8.101 role=nginx
```

Some points to note down here. I have assigned three different role for three different machines. It is not necessary. It is just one of the thousands ways to deploy.

nginx role means that nginx will be running on host with 172.17.8.101. That is why during [Configuration](#configuration) we set this IP in `/etc/hosts` file. Appside and Devside IP addresses will be used in triproxies.

Now, your CoreOS cluster is ready to deploy STF Components.

### Deploy STF
STF comes with various independent components. I have written unit files for each unit in [unit_files](../coreos/unit_files) folder. To know more about these unit files and what is their role, please [see this](https://github.com/openstf/stf/blob/master/doc/DEPLOYMENT.md).

#### Submit services to fleet

```sh
fleetctl submit ./unit_files/*
```

Above command will submit all the services to fleet. You will see these kind of logs.

```sh
Unit adbd.service
Unit nginx.service inactive
Unit rethinkdb-proxy-28015.service
Unit stf-app@.service inactive
Unit stf-auth@.service inactive
Unit stf-migrate.service inactive
Unit stf-processor@.service inactive
Unit stf-provider@.service inactive
Unit stf-reaper.service inactive
Unit stf-storage-plugin-apk@.service inactive
Unit stf-storage-plugin-image@.service inactive
Unit stf-storage-temp@.service inactive
Unit stf-triproxy-app.service inactive
Unit stf-triproxy-dev.service inactive
Unit stf-websocket@.service inactive
```
#### Start services

1. Run adbd and rethindkdb-proxy-28015 services and wait till all the containers are running.
```sh
fleetctl start adbd rethinkdb-proxy-28015
```

You can check the status using `fleetctl list-units` command

2. Create database using stf-migrate service

```sh
fleetctl start stf-migrate
```

3. Run other services
```sh
fleetctl start stf-app@3100                   \
               stf-auth@3200                  \
               stf-storage-plugin-apk@3300    \
               stf-storage-plugin-image@3400  \
               stf-storage-temp@3500          \
               stf-websocket@3600             \
               stf-provider@{1..3}            \
               stf-processor@{1..3}           \
               stf-triproxy-dev               \
               stf-triproxy-app               \
               stf-reaper                     \
```

4. Now all your services are running, except nginx. For nginx, you need to reconfigure nginx.conf file in core-01 host.

First, note down the IP Address of various services running in cluster by running `fleetctl list-units` command. Note down IP Address for following services.
- stf-app
- stf-auth
- stf-storage-plugin-apk
- stf-storage-plugin-image
- stf-storage-temp
- stf-websocket
- provider@1
- provider@2
- provider@3

login into core-01 host and edit nginx.conf
```sh
vagrant ssh core-01
sudo vim /srv/nginx/nginx.conf
```
Update nginx with correct IP address in upstream part.

Now, you are ready to launch nginx service. Logout from VM and run below command.

```sh
fleetctl start nginx
```

Now open browser and open http://stf.mydomain.org. You should be able to see STF login page.

Enjoy STF!
