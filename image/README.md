# Docker images

## Building new images

To build a new image, just run `docker bake target`. The build process will build a local image with predefined tags.

See [docker bake](docs.docker.com/build/bake) for more details.

Images and tag names are defined in docker-bake.hcl in this repository.

### Docker bake environment variables

`TIMESTAMP` - timestamp in `YYYYMMDD-HHmm` (RFC 3339) format.
`ARCH` - image architecture. arm64 or amd64.
`BASE_REPO` - base image repository. `discourse/base`
`TEST_REPO` - test image repository. `discourse/discourse_test`
`SETUP_WIZARD_REPO` - setup wizard image repository. `discourse/setup-wizard`
`DEV_REPO` - dev image repository. `discourse/discourse_dev`

## More about the images

See both `docker-bake.hcl` and the respective `Dockerfile`s for details on _how_ all of this happens.

### base ([discourse/base](https://hub.docker.com/r/discourse/base/))

All of the dependencies for running Discourse.  This includes runit, postgres, nginx, ruby, imagemagick, etc.  It also includes the creation of the "discourse" user and `/var/www` directory.

This image has the following tag varieties:

#### runtime-deps
Runtime dependencies only.

#### build-deps
Everything above, plus build tools to build Discourse. Includes compiling tools for gems, node, and pnpm.

#### slim
Everything above, plus Discourse clone. Includes both main and esr varieties.

#### web-only
Everything above, plus gems and node modules.

#### release
Everything above, plus redis and postgres.

### discourse_dev ([discourse/discourse_dev](https://hub.docker.com/r/discourse/discourse_dev/))

Adds redis and postgres just like the "standalone" template for Discourse in order to have an all-in-one container for development.  Note that you are expected to mount your local discourse source directory to `/src`.  See [the README in GitHub's discourse/bin/docker](https://github.com/discourse/discourse/tree/main/bin/docker/) for utilities that help with this.

Note that the discourse user is granted "sudo" permission without asking for a password in the discourse_dev image.  This is to facilitate the command-line Docker tools in discourse proper that run commands as the discourse user.


### discourse_test ([discourse/discourse_test](https://hub.docker.com/r/discourse/discourse_test/))

Builds on the discourse image and adds testing tools and a default testing entrypoint.

## Github actions variables

The following environment variables are necessary to run the github actions for image builds

`AMD64_RUNNER` - Github actions runner for AMD64 image versions
`ARM64_RUNNER` - Github actions runner for ARM64 image versions
`BASE_REPO` - Docker repository for discourse base image builds
`DEV_REPO` - Docker repository for discourse dev image builds
`TEST_REPO` - Docker repository for discourse test image builds
`SETUP_WIZARD_REPO` - Docker repository for discourse setup wizard image builds
`WEB_ONLY_REPO` - Docker repository for discourse web-only image builds
`DOCKERHUB_USERNAME` - docker registry username
`DOCKERHUB_PASSWORD` - docker registry password
`SKIP_TESTS` - Flag to skip tests. Set to 1 to skip full tests before images pushes.
