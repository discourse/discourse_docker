### About

- [Docker](https://www.docker.io/) is an open source project to pack, ship and run any Linux application in a lighter weight, faster container than a traditional virtual machine.

- Docker makes it much easier to deploy [a Discourse forum](https://github.com/discourse/discourse) on your servers and keep it updated. For background, see [Sam's blog post](http://samsaffron.com/archive/2013/11/07/discourse-in-a-docker-container). 

- The templates and base image configure Discourse with the Discourse team's recommended optimal defaults. 


### IMPORTANT: Before You Start

1. Make sure you're running a **64 bit** version of either [Ubuntu 12.04 LTS](http://releases.ubuntu.com/precise/), [Ubuntu 13.04](http://releases.ubuntu.com/13.04/) or [Ubuntu 13.10](http://releases.ubuntu.com/13.10/).
1. Upgrade to the [latest version of Docker](http://docs.docker.io/en/latest/installation/ubuntulinux/).
1. Create a directory for Discourse Docker (the expected path is `/var/docker`): `install -g docker -m 2775 -d /var/docker`
1. Run the docker installation and launcher as **root** or a member of the **docker** group.
1. Add your user account to the docker group: `usermod -a -G docker yourusername` and re-login.

If you do not do any of the above, as RoboCop once said, ["there will be… trouble."](http://www.youtube.com/watch?v=XxarhampSNI) *Please double check the above list before proceeding!*

### Getting Started

The simplest way to get started is the  **standalone** template:

1. **Clone** this project from github into `/var/docker` on your server: `git clone https://github.com/discourse/discourse_docker.git /var/docker`
2. **Copy** the standalone sample into the containers directory: `cp samples/standalone.yml containers/app.yml`
3. **Edit** `containers/app.yml` with your environment specific information
  - [bindings](#expose)
  - [volumes](#volumes)
4. **Bootstrap** the image: `sudo ./launcher bootstrap app`
5. **Start** the image: `sudo ./launcher start app`

Note: you can add yourself to the Docker group if you wish to avoid `sudo` with `usermod -aG docker <your-user-name>`.

### Directory Structure

#### `/cids`

Contains container ids for currently running Docker containers. cids are Docker's "equivalent" of pids. Each container will have a unique git like hash.

#### `/containers`

This directory is for container definitions for your various Discourse containers. You are in charge of this directory, it ships empty.

#### `/samples`

Sample container definitions you may use to bootstrap your environment. You can copy and amend templates here into the containers directory.

#### `/shared`

Placeholder spot for shared volumes with various Discourse containers. You may elect to store certain persistent information outside of a container, in our case we keep various logfiles and upload directory outside. This allows you to rebuild containers easily without losing important information. Keeping uploads outside of the container allows you to share them between multiple web instances.

#### `/templates`

[pups](https://github.com/samsaffron/pups) managed pups templates you may use to bootstrap your environment.

#### `/image`

Dockerfile for both the base image `samsaffron/discourse_base` and discourse image `samsaffron/discourse`.

- `samsaffron/discourse_base` contains all the OS dependencies including sshd, runit, postgres, nginx, ruby.

- `samsaffron/discourse` builds on the base image and configures a discourse user and `/var/www/discourse` directory for the Discourse source.

The Docker repository will always contain the latest built version at: https://index.docker.io/u/samsaffron/discourse/ , you should not need to build the base image.

### Launcher

The base directory contains a single bash script which is used to manage containers. You can use it to "bootstrap" a new container, ssh in, start, stop and destroy a container.

```
Usage: launcher COMMAND CONFIG
Commands:
    start:      Start/initialize a container
    stop:       Stop a running container
    restart:    Restart a container
    destroy:    Stop and remove a container
    ssh:        Start a bash shell in a running container
    logs:       Docker logs for container
    bootstrap:  Bootstrap a container for the config based on a template
```


### Container Configuration

The beginning of the container definition will contain 3 "special" sections:

#### templates:

```
templates:
  - "templates/cron.template.yml"
  - "templates/postgres.template.yml"
```

This template is "composed" out of all these child templates, this allows for a very flexible configuration struture. Furthermore you may add specific hooks that extend the templates you reference.

#### expose:

```
expose:
  - "2222:22"
```

Expose port 22 inside the container on port 2222 on ALL local host interfaces.


#### volumes:

```
volumes:
  - volume:
      host: /var/docker/shared
      guest: /shared

```

Expose a directory inside the host inside the container.

### Upgrading Discourse

The Docker setup gives you multiple upgrade options:

1. Use the front end at http://yoursite.com/admin/docker to upgrade an already running image.

2. Create a new base image by running:
  - `./launcher destroy my_image`
  - `./launcher bootstrap my_image`
  - `./launcher start my_image`

### Single Container vs. Multiple Container

The samples directory contains a standalone template. This template bundles all of the software required to run Discourse into a single container. The advantage is that it is easy.

The multiple container configuration setup is far more flexible and robust, however it is also more complicated to set up. A multiple container setup allows you to:

- Minimize downtime when upgrading to new versions of Discourse. You can bootstrap new web processes while your site is running and only after it is built, switch the new image in. 
- Scale your forum to multiple servers.
- Add servers for redundancy.
- Have some required services (e.g. the database) run on beefier hardware.

If you want a multiple container setup, see the `data.yml` and `web_only.yml` templates in the samples directory. To ease this process, `launcher` will inject an env var called `DISCOURSE_HOST_IP` which will be available inside the image.

WARNING: In a multiple container configuration, *make sure* you setup iptables or some other firewall to protect various ports (for postgres/redis).
On Ubuntu, install the `ufw` or `iptables-persistent` package to manage firewall rules.

### Email

For a Discourse instance to function properly Email must be set up. Use the `SMTP_URL` env var to set your SMTP address, see sample templates for an example. The Docker image does not contain postfix, exim or another MTA, it was omitted because it is very tricky to set up correctly.

### Troubleshooting

You can ssh into your container using `./launcher ssh my_container`, we will automatically set up ssh access during bootstrap.

### Security

Directory permissions in Linux are UID/GID based, if your numeric IDs on the
host do not match the IDs in the guest, permissions will mismatch. On clean
installs you can ensure they are in sync by looking at `/etc/passwd` and
`/etc/group`, the Discourse account will have UID 1000.


### Advanced topics

- [Setting up SSL with Discourse Docker](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847)
