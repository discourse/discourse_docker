# Docker images

## Building new images

To build a new set of images, update the `Makefile` with the new version number, and then `make all`.  This will automatically update the header comments in the Dockerfiles and update any `FROM` statements to ensure that the image verions remain in lock-step with each other.  (The downside is that if you only wanted to tweak a "leaf" image, you'll still be touching/updating _all_ of the images.  But reasoning about the images is much easier if they all have the same version.)

> _A note about building on OSX:_ While the `Makefile` has provisions for acquiring an OS-specific version of docker-squash, running the Darwin (OSX) version doesn't work on my machine.  To cope, OSX builds simply skip the docker-squash step.  Since I'm not going to be pushing images up to Docker Hub, that's okay with me.

The build process will tag the images with the version number, but not with "latest", nor will it push the images up to Docker Hub.  Both of those steps must be performed manually.

## More about the images

See both `Makefile` and the respective `Dockerfile`s for details on _how_ all of this happens.


### base ([discourse/base](https://hub.docker.com/r/discourse/base/))

All of the dependencies for running Discourse.  This includes runit, postgres, nginx, ruby, imagemagick, etc.  It also includes the creation of the "discourse" user and `/var/www` directory.


### discourse ([discourse/discourse](https://hub.docker.com/r/discourse/discourse/))

Builds on the base image and adds the current (as of image build time) version of Discourse, cloned from GitHub, and also the bundled gems.


### discourse_dev ([discourse/discourse_dev](https://hub.docker.com/r/discourse/discourse_dev/))

Adds redis and postgres just like the "standalone" template for Discourse in order to have an all-in-one container for development.  Note that you are expected to mount your local discourse source directory to `/src`.  See [the README in GitHub's discourse/bin/docker](https://github.com/discourse/discourse/tree/master/bin/docker/) for utilities that help with this.

Note that the discourse user is granted "sudo" permission without asking for a password in the discourse_dev image.  This is to facilitate the command-line Docker tools in discourse proper that run commands as the discourse user.


### discourse_test ([discourse/discourse_test](https://hub.docker.com/r/discourse/discourse_test/))

Builds on the discourse image and adds testing tools and a default testing entrypoint.


### discourse_bench ([discourse/discourse_bench](https://hub.docker.com/r/discourse/discourse_bench/))

Builds on the discourse_test image and adds benchmark testing.


### discourse_fast_switch ([discourse/discourse_fast_switch](https://hub.docker.com/r/discourse/discourse_fast_switch/))

Builds on the discourse image and adds the ability to easily switch versions of Ruby.
