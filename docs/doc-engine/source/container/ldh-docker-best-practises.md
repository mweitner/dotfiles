# LDH - Docker Best Practises

Following works on using Docker engine on development host supporting development tasks.

References:

* <https://docs.docker.com/>
* <https://projectatomic.io/docs/docker-image-author-guidance/>

# Clean docker installation

As of recent problems with mixed docker installation on my ubuntu 22.04 system with native docker and snap docker installation, following describes the clean up and clean installation of one docker installation.


:::info
**Why Use Native Docker Installation Instead of Snap on Development PCs**

* **Full Filesystem Access:** Native Docker (installed via apt) can access all system paths (e.g., /opt, /srv), while Snap Docker is strictly confined to your home directory due to security sandboxing.
* **Better Compatibility:** Many development tools, CI/CD scripts, and volume mounts expect unrestricted access, which Snap cannot provide.
* **Fewer Permission Issues:** Native Docker avoids common mount and permission errors seen with Snap, especially when working with shared or system folders.
* **Up-to-date Features:** The official Docker packages are updated more frequently and support the latest Docker Compose and Buildx plugins.
* **Community Support:** Most Docker documentation and community support assume the native installation, making troubleshooting easier.

**Recommendation:**\nFor development environments, always use the native Docker installation from the official repositories or your distribution's package manager for maximum compatibility and fewer headaches.

:::

## Cleanup

### Remove Docker Snap

```javascript
$ sudo snap remove docker
#force
$ sudo snap remove --purge docker
```

### Remove Native Docker

```javascript
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  docker-ce-rootless-extras
sudo apt-get autoremove
```

### Remove Old Docker Data

This step is optional but recommended for a truly clean slate. It will remove all old images, containers, and volumes. Warning: This will delete all your local Docker data.

```javascript
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

## Native Installation

I am using native docker installation to prevent the snap more isolated installation, which would cause additional complexity and problem regarding container runtime restrictions like permissions etc.

## Fedora 43 Native Installation

For Fedora development hosts, use native Docker CE packages and avoid mixed runtimes.

Quick setup from dotfiles:

```bash
/home/ldcwem0/dotfiles/shell/setup-docker-fedora-native.sh --apply-daemon-config
```

Manual setup:

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

Apply LLP-safe network ranges to avoid conflicts with internal hosts like `lis-github.liebherr.com`:

```bash
sudo install -m 0755 -d /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
    "bip": "100.127.232.1/25",
    "fixed-cidr": "100.127.232.0/25",
    "default-address-pools": [
        {
            "base": "100.127.232.128/25",
            "size": 29
        }
    ]
}
EOF
sudo systemctl restart docker
```

Verify:

```bash
docker --version
docker compose version
```

Important: log out and back in (or reboot) after adding user to the `docker` group.

### Install Native Docker

Now, install the official, native Docker Engine.

* **Update your system and install necessary packages:**

```javascript
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
```

* **Add Docker's GPG key:**

```javascript
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

* **Add the Docker repository to your** `**apt**` **sources:**

```javascript
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

* **Update the package index and install Docker Engine, CLI, and Compose:**
  * docker.io brings in all required packages including proper containerd etc., so no need for extra docker-ce docker-ce-cli, or container.io.

```javascript
sudo apt-get update
$ sudo apt-get install docker.io docker-buildx-plugin docker-compose-plugin
```

### Manage Docker as a Non-Root User

By default, you have to use `sudo` to run Docker commands. To run them without `sudo`, add your user to the `docker` group.

```javascript
sudo usermod -aG docker $USER
```

After running this command, **log out and log back in** for the changes to take effect.

### Configure the Docker Network

Now that you have a clean native installation, you can apply the `daemon.json` configuration to prevent the network IP conflict you identified earlier.

* Create or edit the `daemon.json` file. This file is located at `/etc/docker/daemon.json` for native installations.
  * Add your network configuration to the file:

    ```javascript
    $ cat /etc/docker/daemon.json
    {
      "bip": "100.127.232.1/25",
      "fixed-cidr": "100.127.232.0/25"
    }
    
    ```

    Current on ubuntu machine with some changes from KI and back some changes from martin d.:
  * ```bash
    √ ldcwem0@ldcnb-ldcwem0: ~$ cat /etc/docker/daemon.json
    {
      "bip": "100.127.232.1/25",
      "fixed-cidr": "100.127.232.0/25",
      "default-address-pools": [
        {
          "base": "100.127.232.128/25",
          "size": 29
        }
      ]
    }
    
    ```
* Restart the Docker service to apply the new settings:

  ```javascript
  sudo systemctl restart docker
  ```

After completing these steps, you will have a clean, native Docker installation configured to avoid the network conflict with your company's GitHub server. You should now be able to run `docker-compose` commands without the `Cannot connect` error.

## Summary

verify docker installation native only:

```javascript
$ which docker && snap list | grep docker
/usr/bin/docker

$ docker --version
Docker version 28.2.2, build 28.2.2-0ubuntu1~22.04.1
```

Docker compose is installed as plugin and the command is not docker-compose but docker compose:

```javascript
$ docker compose version
Docker Compose version v5.0.1
```

# How to solve github liebherr ip Routing?

There is known issue about lis-github installation and its ip usage conflicting with default docker network.

Session with Martin D.

* Date: 02.10.2025

General chat:

> mach mal ein:
>
> docker network inspect bridge
>
> \
> host lis-github.liebherr.com
>
>  
>
> ip route li
>
> docker network ls
>
> ip link set dev 
>
> ip route add 

## Problem Analysis - 1

Go through docker networks and find out which one conflicts with 172.18…. network?

* docker network ls → list all docker networks
* for each docker inspect <network_name> → see if network conflicts?

```javascript
$ ip route li
default via 10.146.72.1 dev enxf4ee08caae80 proto dhcp metric 101
default via 10.146.72.1 dev wlan0 proto dhcp metric 600
10.146.72.0/23 dev enxf4ee08caae80 proto kernel scope link src 10.146.72.26 metric 101
10.146.72.0/23 dev wlan0 proto kernel scope link src 10.146.72.39 metric 600
100.127.0.0/16 dev wg-iot-testbed proto static scope link metric 50
100.127.232.0/25 dev docker0 proto kernel scope link src 100.127.232.1 linkdown
172.17.0.0/16 dev br-76bb234b1a04 proto kernel scope link src 172.17.0.1 linkdown
172.18.0.0/16 dev br-06d0edb89471 proto kernel scope link src 172.18.0.1
172.18.0.0/16 dev br-06d0edb89471 proto kernel scope link src 172.18.0.1 metric 425
172.19.0.0/16 dev br-0b7db18e7a89 proto kernel scope link src 172.19.0.1 linkdown
192.168.3.0/24 dev enx00e04c680221 proto kernel scope link src 192.168.3.1
192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1 linkdown
                                                                                                                                                          
$ docker network ls
NETWORK ID     NAME                       DRIVER    SCOPE
2c2dc8822030   bridge                     bridge    local
76bb234b1a04   ci_default                 bridge    local
5d2d127273bd   host                       host      local
0b7db18e7a89   mosquitto_broker_default   bridge    local
831c57624a0f   none                       null      local
                                                                                                                                                          
$ docker inspect mosquitto_broker_default
[
    {
        "Name": "mosquitto_broker_default",
        "Id": "0b7db18e7a89359064fe0c4253fb2ad0d69dd74dc7398c81e18c1cef389bdd02",
        "Created": "2025-10-01T17:27:18.216382183+02:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv4": true,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.19.0.0/16",
                    "Gateway": "172.19.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {
            "com.docker.compose.config-hash": "72b3cf2c3984e124731a19588b1621425c937af69ae71f13e9ac632ed578f517",
            "com.docker.compose.network": "default",
            "com.docker.compose.project": "mosquitto_broker",
            "com.docker.compose.version": "2.33.1"
        }
    }
]
                                                                                                                                                          
$ docker inspect ci_default
[
    {
        "Name": "ci_default",
        "Id": "76bb234b1a044c7f1bb5b1c65b359e2799cfd09439ded9fb272c7c770a8af8af",
        "Created": "2024-07-17T13:59:59.897613547+02:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv4": true,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {
            "com.docker.compose.network": "default",
            "com.docker.compose.project": "ci",
            "com.docker.compose.version": "2.27.0"
        }
    }
]
                                                                                                                                                          
$ docker inspect host
[
    {
        "Name": "host",
        "Id": "5d2d127273bd1de9929d67390ff4616adbf2fb7e867e30af9ef0e1fcfaaada17",
        "Created": "2022-12-12T15:52:52.369897959+01:00",
        "Scope": "local",
        "Driver": "host",
        "EnableIPv4": true,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": null
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]
                                                                                                                                                          
$ docker inspect bridge
[
    {
        "Name": "bridge",
        "Id": "2c2dc88220301809d98db791252624a41d41d591a04789fc5265f47a8930f605",
        "Created": "2025-10-01T10:14:28.369426118+02:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv4": true,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "100.127.232.0/25",
                    "IPRange": "100.127.232.0/25",
                    "Gateway": "100.127.232.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]
                                                                                                                                                          
$ docker inspect none
[
    {
        "Name": "none",
        "Id": "831c57624a0f18365a37dc1417ec0db16a1e48652b2f4b4a12326d02b877972b",
        "Created": "2022-12-12T15:52:52.36452107+01:00",
        "Scope": "local",
        "Driver": "null",
        "EnableIPv4": true,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": null
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]
```

Result none conflicted so there must be something else in docker context?

## Problem Analysis - 2

There is docker-proxy daemon running most likely triggered by my cmtools/mosquitto_broker docker-compose:

This cause the ip conflict with 172.18… network

```javascript
$ ps ax |grep docker
   3035 ?        Ssl    0:28 dockerd --group docker --exec-root=/run/snap.docker --data-root=/var/snap/docker/common/var-lib-docker --pidfile=/run/snap.docker/docker.pid --config-file=/var/snap/docker/3265/config/daemon.json
   3112 ?        Ssl    1:19 containerd --config /run/snap.docker/containerd/containerd.toml
  63129 ?        Sl     0:09 /snap/docker/3265/bin/containerd-shim-runc-v2 -namespace moby -id f92b9e73100e01858ce051e727407c05fd20e64a1230120d35f0dedf7a13acbc -address /run/snap.docker/containerd/containerd.sock
  63132 ?        Sl     0:09 /snap/docker/3265/bin/containerd-shim-runc-v2 -namespace moby -id d21a9f900cb1719b55dca3524661e42b7ce58df53f76d17e8b38876cdc3ac15a -address /run/snap.docker/containerd/containerd.sock
  63241 ?        Sl     0:00 /snap/docker/3265/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8884 -container-ip 172.18.0.2 -container-port 8883 -use-listen-fd
  63248 ?        Sl     0:00 /snap/docker/3265/bin/docker-proxy -proto tcp -host-ip :: -host-port 8884 -container-ip 172.18.0.2 -container-port 8883 -use-listen-fd
  63271 ?        Sl     0:00 /snap/docker/3265/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 1884 -container-ip 172.18.0.3 -container-port 1883 -use-listen-fd
  63279 ?        Sl     0:00 /snap/docker/3265/bin/docker-proxy -proto tcp -host-ip :: -host-port 1884 -container-ip 172.18.0.3 -container-port 1883 -use-listen-fd
 341932 ?        Ssl    0:13 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
2637327 pts/6    S+     0:00 grep docker
```

Martin tinks:

> Do a pc reboot maybe the docker-proxy is a left over from docker-compose command in context of cmtools/mosquitto_broker

## Solution

Make sure docker never uses conflicting network 172.18…

This was done already by martins help defining docker config at:

* /etc/docker/daemon.json

```javascript
$ cat /etc/docker/daemon.json
{
  "bip": "100.127.232.1/25",
  "fixed-cidr": "100.127.232.0/25"
}
```

## Alternative Solution - Add route

```javascript
$ docker network ls
NETWORK ID     NAME         DRIVER    SCOPE
2c2dc8822030   bridge       bridge    local
76bb234b1a04   ci_default   bridge    local
5d2d127273bd   host         host      local
831c57624a0f   none         null      local
                                                                                                                                                          
$ cat /etc/docker/daemon.json
{
  "bip": "100.127.232.1/25",
  "fixed-cidr": "100.127.232.0/25"
}

$ host lis-github.liebherr.com
lis-github.liebherr.com has address 172.18.6.136

$ ip route li
default via 10.146.72.1 dev enxf4ee08caae80 proto dhcp metric 101
default via 10.146.72.1 dev wlan0 proto dhcp metric 600
10.146.72.0/23 dev enxf4ee08caae80 proto kernel scope link src 10.146.72.26 metric 101
10.146.72.0/23 dev wlan0 proto kernel scope link src 10.146.72.39 metric 600
100.127.0.0/16 dev wg-iot-testbed proto static scope link metric 50
100.127.232.0/25 dev docker0 proto kernel scope link src 100.127.232.1 linkdown
172.17.0.0/16 dev br-76bb234b1a04 proto kernel scope link src 172.17.0.1 linkdown
192.168.3.0/24 dev enx00e04c680221 proto kernel scope link src 192.168.3.1
192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1 linkdown
```

Solution add route:

```javascript
$ sudo ip route add 172.18.6.136/32 via 10.146.72.1
```

# HowTo Mandatory Build Args?

One option to  verify mandatory build arguments is using shell script language with RUN command:

```javascript
RUN set -ex \
    && if [ -z "${YP_PROJECT_DIR}" ]; then echo 'YP_PROJECT_DIR must be set. Exiting.'; exit 1; fi \
    && if [ -z "${YP_BUILD_DL_DIR}" ]; then echo 'YP_BUILD_DL_DIR must be set. Exiting.'; exit 1; fi \
    && if [ -z "${YP_BUILD_SSTATE_DIR}" ]; then echo 'YP_BUILD_SSTATE_DIR must be set. Exiting.'; exit 1; fi \
    && export DEBIAN_FRONTEND="noninteractive" \
    && apt-get update && apt-get upgrade -y && apt-get install -y locales tzdata \
```

several if conditions:

* make sure syntax is correct with 1 =:
*  

```javascript
...
  && if [ "test" = "test" ]; then echo "equal"; fi
```

# User Management

## Do not use root user

because it is a security thread, as the container has than full permission. For example, as root user you are able to mount the host's rootfs and do whatever you like to do. The only privilege needed on host is to run the container, which is possible if you are sudoer or in docker group.

* <https://weitner.getoutline.com/doc/ldh-docker-best-practises-uLs1mh8hvj/edit#h-define-explicit-working-user-none-root>

## Define explicit working user (none root)

The docker command USER <username> switches to a specific user during build time and at the end of Dockerfile at runtime. The working directory, is specified by WORKDIR command.

```javascript
$ cat Dockerfile
...
USER root
RUN mkdir -p /home/myuser
RUN useradd -u ${host_uid} -g ${build_group} --home-dir /home/myuser \
  --no-create-home --shell /bin/bash myuser
RUN chown -R myuser:${build_group} /home/myuser

USER myuser
SHELL ["/bin/bash"]
WORKDIR /home/myuser

$ docker run ...
myuser@30e69b6908f9:~$
```

## Workdir

The WORKDIR is the folder the container starts into. If nothing is defined it is the root "/".

If there is explicite working user with home folder, take that home folder as default:

```javascript
WORKDIR /home/myuser
```

Note: some applications rely on home folder, therefor it prevents problems with such applications/tools.