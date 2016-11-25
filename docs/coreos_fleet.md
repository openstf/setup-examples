# Deploy STF Using CoreOS and Fleet

## Requirements
- Install [fleetctl client](https://coreos.com/fleet/docs/latest/launching-containers-fleet.html)
  - On OS X, you can install it using `brew install fleetctl`.
- Make sure that rethinkdb is running by following [these instructions](../README.md#create-rethinkdb-cluster)

## Configuration

### Add usb filters
In order to access real devices from VMs, it is necessary to create usb filters. Update [Vagrantfile](../coreos/Vagrantfile) for this. Instructions are written in file itself.

1. Connect the android device or devices to your OS X and check if they are properly connected by running `adb devices`
2. Get vendor_id and product_id of devices using `VBoxManage list usbhost` command. It will display something like this

  ```
  UUID:               e7757772-3030-44a3-ac14-00e53e9e32f8
  VendorId:           0x0fce (0FCE)
  ProductId:          0x519e (519E)
  Revision:           2.50 (0250)
  Port:               2
  USB version/speed:  0/High
  Manufacturer:       Sony
  Product:            SOL23
  SerialNumber:       CB5125LBYM
  Address:            p=0x519e;v=0x0fce;s=0x0001f3695ada4522;l=0x14200000
  Current State:      Busy
  ```

3. Uncomment the usbfilter line in [Vagrantfile](../coreos/Vagrantfile) and rewrite it like this.

  From:
  ```sh
  v.customize ['usbfilter', 'add', '0', '--target', :id, '--name', $ANY_NAME, '--vendorid', $VENDOR_ID, '--productid', $PRODUCT_ID]
  ```
  To:
  ```sh
  v.customize ['usbfilter', 'add', '0', '--target', :id, '--name', 'Sony SOL23', '--vendorid', '0x0fce', '--productid', '0x519e']
  ```

  In case you have more devices, add additional filters for them.

  Ref:
    * https://www.virtualbox.org/manual/ch03.html#idp47384979772560
    * http://spin.atomicobject.com/2014/03/21/smartcard-virtualbox-vm/

### Start CoreOS Cluster

Now we can start our CoreOS cluster using below command.

```sh
cd ./coreos; vagrant up
```

Above command will do
- Download **CoreOS** image if image is not present (*this may take time depending on internet speed*)
- Launch 3 instances of CoreOS VM and set IP `172.17.8.101`, `172.17.8.102` & `172.17.8.103` fixed IP to these VMs
- Finish cloud configuration and set fleet metadata
- You can check if all the instances are running using `vagrant global-status` command


### Configuring fleetctl
Next, we will be launching STF components in docker containers inside CoreOS cluster using fleetctl. In order to use fleet client from OS X, we need to export a global variable called FLEETCTL_ENDPOINT. This endpoint will tell fleetctl running on OS X to talk with fleet daemon running inside one of the guest OS.

```sh
export FLEETCTL_ENDPOINT=http://172.17.8.101:2379
```

Now, run `fleetctl list-machines` command, You will see something like below

```sh
MACHINE     IP           METADATA
0f666d32... 172.17.8.103 role=devside
3dfaef6c... 172.17.8.102 role=appside
dc387247... 172.17.8.101 role=nginx
```

Some points to note down here. I have assigned three different role to these VMs. It is not necessary. It is just one of the thousands ways to deploy.

nginx role means that nginx will be running on host with 172.17.8.101. By fixing nginx load balancer IP, it becomes easier to write fleet [unit files](../coreos/unit_files). Appside and Devside IP addresses will be used in appside and devside triproxies. Refer [here](https://github.com/openstf/stf/blob/master/doc/DEPLOYMENT.md#stf-triproxy-appservice) and [here](https://github.com/openstf/stf/blob/master/doc/DEPLOYMENT.md#stf-triproxy-devservice) if you don't know what are these.

Now, your CoreOS cluster is ready to deploy STF Components.

### Deploy STF
STF comes with various independent components. I have written unit files for each unit in [unit_files](../coreos/unit_files) folder. To know more about these unit files and what is their role, please [see this](https://github.com/openstf/stf/blob/master/doc/DEPLOYMENT.md).

#### Submit services to fleet

```sh
fleetctl submit ./unit_files/*
```

Above command will submit all the services to fleet. You will see logs something like this.

```sh
Unit adbd.service
Unit nginx.service inactive
Unit rethinkdb-proxy-28015.service
Unit stf-api@.service inactive
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

1. First, start adbd and rethindkdb-proxy-28015 services and wait till all the containers are running.
  ```sh
  fleetctl start adbd rethinkdb-proxy-28015
  ```

  You can check the status using `fleetctl list-units` command. Be patient, it will take time because it is downloading docker images for the first time.

2. Create database using stf-migrate service
  Now, it is time to create database. `stf-migrate` unit will do this.

  ```sh
  fleetctl start stf-migrate
  ```

  stf-migrate is a oneshot unit. Once it is finished, it's status will be dead. You can unload it using below command once it is finished.

  ```sh
  fleetctl unload stf-migrate
  ```

3. Run other services
  ```sh
  fleetctl start stf-app@3100                   \
                 stf-auth@3200                  \
                 stf-storage-plugin-apk@3300    \
                 stf-storage-plugin-image@3400  \
                 stf-storage-temp@3500          \
                 stf-websocket@3600             \
                 stf-api@3700
                 stf-provider@{1..3}            \
                 stf-processor@{1..3}           \
                 stf-triproxy-dev               \
                 stf-triproxy-app               \
                 stf-reaper                     \
  ```

4. Now all your services are running, except nginx. For nginx, you need to reconfigure nginx.conf to set upstream endpoints.

  First, note down the IP Address of various services running in cluster by running `fleetctl list-units` command. Note down IP Address for following services.
  - stf-app
  - stf-auth
  - stf-storage-plugin-apk
  - stf-storage-plugin-image
  - stf-storage-temp
  - stf-websocket
  - stf-api
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

Now open browser and open http://172.17.8.101. You should be able to see STF login page.

**Optional** In case, if you want to use your domain name instead of IP Address for STF URL. Do following things.

1. Register host in your `/etc/hosts` file.

  Add this in `/etc/hosts` file

  ```
  172.17.8.101  stf.example.org
  ```

2. Change `--storage-url`, `--app-url` & `--auth-url` in unit files with domain name.
3. Restart updated services. And now you should be able to see STF on http://stf.example.org

Enjoy STF!
