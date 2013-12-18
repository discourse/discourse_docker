## Discourse Docker

A toolkit for building and managing Docker images for Discourse.

### About

The Discourse docker templates were designed by Sam Saffron. See the following introduction: http://samsaffron.com/archive/2013/11/07/discourse-in-a-docker-container

These templates are agnostic, you may run Discourse in multiple containers or a single container.

The templates and base image take care of configuring Discourse with best practices in mind. The latest version of Ruby 2.0 is included as is fairly extensive memory and GC tuning. The web template uses unicorn which helps cut down on overall memory usage making this very suitable for VPS type installs.

### Getting started

The simplest (though slightly more fragile) way of getting started is using the **standalone** template.

1. **Clone** this project from github: `git clone https://github.com/SamSaffron/discourse_docker.git`
2. **Copy** the standalone sample into the containers directory: `cp samples/standalone.yml containers/app.yml`
3. **Edit** `containers/app.yml` with your environment specific information
  - [bindings](#expose)
  - [volumes](#volumes) (make sure you create the appropriate directories on the host)
4. **Bootstrap** the image: `sudo ./launcher bootstrap app`
5. **Start** the image: `sudo ./launcher start app`

Note: you can add yourself to the docker group if you wish to avoid `sudo` with `usermod -aG docker <your-user-name>`.

### Directory Structure

#### cids

Contains container ids for currently running Docker containers. cids are Docker's "equivalent" of pids. Each container will have a unique git like hash.

#### containers

This directory is to contain container definitions for your various Discourse containers. You are in charge of this directory, it ships empty.

#### samples

Sample container definitions you may use to bootstrap your environment. You can copy and amend templates here into the containers directory.

#### shared

Placeholder spot for shared volumes with various Discourse containers. You may elect to store certain persistent information outside of a container, in our case we keep various logfiles and upload directory outside. This allows you to rebuild containers easily without losing important information. Keeping uploads outside of the container allows you to share them between multiple web instances.

#### templates

[pups](https://github.com/samsaffron/pups) managed pups templates you may use to bootstrap your environment.

#### image

Dockerfile for both the base image `samsaffron/discoruse_base` and discourse image `samsaffron/discourse`.

`samsaffron/discourse_base` contains all the OS dependencies including sshd, runit, postgres, nginx, ruby.

`samsaffron/discourse` builds on the base image and configures a discourse user and `/var/www/discourse` directory for the Discourse source.

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


### About the container configuration

The beggining of the container definition will contain 3 "special" sections:

#### templates:

```
templates:
  - "templates/cron.template.yml"
  - "templates/postgres.template.yml"
```

This template is "composed" out of all these child templates, this allows for a very flexible configuration struture. Further more you may add specific hooks that extend the templates you reference.

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
      host: /var/docker/data
      guest: /shared

```

Expose a directory inside the host inside the container.

### Upgrading discourse

The docker setup gives you multiple upgrade options:

1. You can use the front end at http://yoursite.com/admin/docker to upgrade an already running image.

2. You can create a new base image by running:
  - `./launcher bootstrap my_image`
  - `./launcher destroy my_image`
  - `./launcher start my_image`

### Multi image vs Single image setups

The samples directory contains a standalone template. This template will bundle all of the programs required to run discourse into a single image. The advantage is that it is very easy to get started as you do not need to wire up communications between containers.

However, the disadvantage is that the bootstrapping process will launch a new postgres instance, having 2 postgres instances running against a single directory can lead to unexpected results. Due to that, if you are ever to bootstrap the `standalone` template again you should first stop the existing container.

A multi images setup allows you to bootstrap new web processes while your site is running and only after it is built, switch the new image in. The setup is far more flexible and robust, however is a bit more complicated to setup. See the `data.yml` and `web_only.yml` templates in the samples directory. To ease this process, `launcher` will inject an env var called `DISCOURSE_HOST_IP` which will be available inside the image.

WARNING: If you launch multiple images, **make sure** you setup iptables or some other firewall to protect various ports (for postgres/redis).

### Email setup

For a Discourse instance to function properly Email must be setup. Use the SMTP_URL env var to set your SMTP address, see sample templates for an example.
The docker image does not contain postfix, exim or another MTA, it was omitted cause it is very tricky to setup perfectly.

### Troubleshooting

It is strongly recommended you have ssh access to your running containers, this allows you very easily take sneak peak of the internals. Simplest way to gain access is:

1. Run a terminal as root
2. cd `~/.ssh`
3. `ssh-key-gen`
4. paste the contents of `id_rsa.pub` into your templates (see placeholder in samples)
5. bootstrap and run your container
6. `./launcher ssh my_container`

### Security

Directory permissions in Linux are sid based, if your sids on the host do not match the sids in the guest, permissions will mismatch. On clean installs you can ensure they are in sync by looking at `/etc/passwd` and `/etc/group`, the discourse account will have the sid 1000.
