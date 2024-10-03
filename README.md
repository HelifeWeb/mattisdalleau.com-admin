# HDCI

Deployment of traefik, portainer, docker-registry and Drone-CI.

## Requirements

- A domain name (Hosted on Cloudflare)
- A server with a public IP address
- 2GB of RAM minimum (Pipeline takes 1.3GB of RAM)
- A github account
- Docker and docker-compose installed on your server
- git

For now it will not generate the DNS records for you, but it will create the certificates.

## What it deploys

- Traefik (The reverse proxy that will handle the SSL certificates and the routing)
- Portainer (A docker management UI)
- Docker-Registry (A private docker registry)
- Drone-CI (A CI/CD tool)
- Watchtower (A tool that will update your containers when a new image is available)
- Whoami-Service (A simple service that will return the IP address of the request to test the deployment)

## How to use it

The main goal of this deployment is to be able to deploy a simple CI/CD for your server prod using lightweight tools that are easy to use.

The main idea is to have a git repository with your code, and a git repository with your deployment configuration.

Drone-CI is expected to build images and push them to the registry for all the projects you want to deploy.

Then the repository with the deployment configuration will be used to deploy the images.

If an image is updated, the pipeline will be triggered and the new image will be deployed automatically using Watchtower.

## Setup

### 1. Clone this repository

```bash
git clone git@github.com:HelifeWasTaken/hdci.git
```

### 2. Register drone as an application on github by following this guide

[Drone Github Provider Docs](https://docs.drone.io/server/provider/github/)

The callback URL should be `https://drone.<your-domain>/login`

Please then store your client ID and client secret in a safe place, you will need them later.

### 3. Get your Cloudflare API key

[Create a Cloudflare Token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)

### 4. Generate the env file for the deployment

You can use the `generate_env.sh` script to generate the `.env` file for drone.

```bash
./generate_env.sh # To see all required parameters
```

### 5. Make sure your DNS records are set up correctly

You need to have the following DNS records at least:

```txt
A record: <your-domain> -> <your-server-ip>
CNAME record: drone.<your-domain> -> <your-domain>
CNAME record: registry.<your-domain> -> <your-domain>
CNAME record: whoami.<your-domain> -> <your-domain>
```

### 6. Deploy the stack

```bash
docker-compose up -d
```

### 7. Test the deployment by connecting

You can test in order:

- whoami
- drone

Make also sure that your portainer service is not exposed wihtout auth

Then if you do not care to turn off the other ports of your machine it would be a good idea to only allow `80 443 22` ports

```bash
# if you use ufw you can use this script to allow only 80/443/22 and disallow everything else
for i in $(ufw status numbered | grep -oP '^\[\d+\].*?(?=\s+\[)|^\[\d+\].*'); do ufw delete $i; done
ufw allow 80
ufw allow 443
ufw allow 22
ufw enable
```

Note:
If docker login is not possible, install these package

```bash
sudo apt install dbus-x11 gnupg2 pass
```

For mac users because mac does weird things in SSH?? It somehow needs x11 forwarding for docker login as you can see above so DISPLAY forwarding is required
```bash
export DISPLAY=0.0
```

For easy to deploy VPNs [openvpn](https://github.com/angristan/openvpn-install)

## Recommended environment example

This environment takes into account that you won't use NFS share for the database and that the VM's are supposedly close to each other for low latency.

The HOST VM for the `portainer, traefik, registry, drone-ci`. It deploys all the service on the local docker but are part of the docker `traefik network`.

The DatabaseVMs handling databases backups and storage and is connected to the DatabaseNetwork through the swarm.

The Worker VM... Thoses containers are not supposed to use static data and focus solely on quering the databases for processing and storing info.

Of course more networks may be used to manage better information

DroneCI should build image and push it to the registry.

Portainer should handle how the deployments are being processed.

This graph implicitly consider that all containers are lied to their local docker socket but for graph simplicity only shows containers that actually use the docker socket for docker commands

```mermaid
flowchart RL

    subgraph DNSResolver
        direction LR;
        Cloudflare
        ...
    end

    subgraph Cloud
        direction LR;
        SSH
        GoogleCloud
        AWS
        ..
    end

    subgraph ControllerVM
        direction TB;

        DockerSwarmService((Docker Swarm Service))

        subgraph SwarmNetwork
            DatabaseNetwork{Database Network}
            TraefikNetwork{Traefik Network}
        end

        DockerSwarmService <--> SwarmNetwork

        HostVMDockerSocket{{Docker Socket}}
        Traefik[[Traefik Container]]
        DroneServer[[Drone Server Container]]
        DroneServerRunner[[Drone Server Runner Container]]
        Portainer[[Portainer Container]]
        Registry[[Registry Container]]

        HostVMDockerSocket <--> DockerSwarmService

        Traefik <--> HostVMDockerSocket
        Traefik <--> TraefikNetwork

        TraefikNetwork<-->DroneServer
        TraefikNetwork<--> HostVMDockerSocket 

        TraefikNetwork<-->DroneServer

        DroneServer<-->DroneServerRunner
        DroneServerRunner<-->HostVMDockerSocket

        TraefikNetwork<-->Registry

        TraefikNetwork<-->Portainer

        Portainer <--> HostVMDockerSocket
    end

    subgraph DatabaseVM
        direction LR;

        DatabaseVMSocketDocker{{Docker Socket}}
        DatabaseService1Container[(Database Container)]
        DatabaseService2Container[(Database Container)]
        DatabaseService3Container[(Database Container)]
        DatabaseService4Container[(Database Container)]

        DatabaseVMSocketDocker <--> DockerSwarmService

        DatabaseService1Container <--> DatabaseNetwork
        DatabaseService2Container <--> DatabaseNetwork
        DatabaseService3Container <--> DatabaseNetwork
        DatabaseService4Container <--> DatabaseNetwork

        BackupService <--> DatabaseNetwork
    end

    subgraph ExampleWorkerVM1
        direction LR;

        Worker1DockerSocket{{Docker Socket}}
        Worker1Service1[[Worker WEB UI Replica 1]]
        Worker1Service2[[Worker API Replica 1]]

        Worker1DockerSocket <--> DockerSwarmService

        Worker1Service1 <--> TraefikNetwork
        Worker1Service1 <--> DatabaseNetwork

        Worker1Service2 <--> TraefikNetwork
        Worker1Service2 <--> DatabaseNetwork
    end

    subgraph ExampleWorkerVM2
        direction LR;

        Worker2DockerSocket{{Docker Socket}}
        Worker2Service1[[Worker WEB UI Replica 2]]
        Worker2Service2[[Worker API Replica 2]]
        Worker2Service3[[Worker API Replica 3]]

        Worker2DockerSocket <--> DockerSwarmService

        Worker2Service1 <--> TraefikNetwork
        Worker2Service1 <--> DatabaseNetwork

        Worker2Service2 <--> TraefikNetwork
        Worker2Service2 <--> DatabaseNetwork

        Worker2Service3 <--> DatabaseNetwork
        Worker2Service3 <--> TraefikNetwork
    end

    subgraph Clients
        direction TB;
        DistantClient1
        DistantClient2
        DistantClient3
        DistantClient4
    end

    Traefik <--> DNSResolver

    BackupService <--> Cloud

    DistantClient1 <--> DNSResolver
    DistantClient2 <--> DNSResolver
    DistantClient3 <--> DNSResolver
    DistantClient4 <--> DNSResolver
```
