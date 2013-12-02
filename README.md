##Discourse Docker

A toolkit for building and managing Docker images for Discourse.

### About

The Discourse docker templates were designed by Sam Saffron. See the following introduction: http://samsaffron.com/archive/2013/11/07/discourse-in-a-docker-container

These templates are agnostic, you may run Discourse in multiple containers or a single container.

The templates and base image take care of configuring Discourse with best practices in mind. The latest version of Ruby 2.0 is included as is fairly extensive memory and GC tuning. The web template uses unicorn which helps cut down on overall memory usage making this very suitable for VPS type installs.

###Getting started

The simplest (though slightly more fragile) way of getting started is using the standalone template.

- `cp samples/standalone.yml containers/app.yml`
- **Edit** app.yml with your environment specific information, including binds and volumes
- `sudo ./launcher bootstrap app`
- `sudo ./launcher start app`

Note: you can add yourself to the docker group if you wish to avoid `sudo` with `usermod -a -G docker your-user-name`.

### Directory Structure

- cids

Contains container ids for currently running Docker containers. cids are Docker's "equivalent" of pids. Each container will have a unique git like hash.

- containers

This directory is to contain container definitions for your various Discourse containers. You are in charge of this directory, it ships empty.

- samples

Sample container definitions you may use to bootstrap your environment. You can copy and amend templates here into the containers directory.

- shared

Placeholder spot for shared volumes with various Discourse containers. You may elect to store certain persistent information outside of a container, in our case we keep various logfiles and upload directory outside. This allows you to rebuild containers easily without losing important information. Keeping uploads outside of the container allows you to share them between multiple web instances.

- templates

[pups](https://github.com/samsaffron/pups) managed pups templates you may use to bootstrap your environment.

- image

Dockerfile for both the base image `samsaffron/discoruse_base` and discourse image `samsaffron/discourse`.

`samsaffron/discourse_base` contains all the OS dependencies including sshd, runit, postgres, nginx, ruby.

`samsaffron/discourse` builds on the base image and configures a discourse user and `/var/www/discourse` directory for the Discourse source.

The Docker repository will always contain the latest built version at: https://index.docker.io/u/samsaffron/discourse/ , you should not need to build the base image.

###launcher

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


###About the container configuration

The beggining of the container definition will contain 3 "special" sections:

- templates:

```
templates:
  - "templates/cron.template.yml"
  - "templates/postgres.template.yml"
```

This template is "composed" out of all these child templates, this allows for a very flexible configuration struture. Further more you may add specific hooks that extend the templates you reference.

- expose:

```
expose:
  - "2222:22"
```

Expose port 22 inside the container on port 2222 on ALL local host interfaces.


- volumes:

```
volumes:
  - volume:
      host: /var/docker/data
      guest: /shared

```

Expose a directory inside the host inside the container.

*short note about security* Directory permissions in Linux are sid based, if your sids on the host do not match the sids in the guest, permissions will mismatch. On clean installs you can ensure they are in sync by looking at `/etc/passwd` and `/etc/group`, the discourse account will have the sid 1000.





