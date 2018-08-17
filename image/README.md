# Docker images

## Building new images

To build a new image, just run `ruby auto_build.rb image-name`. The build process will build a local image with a predefined tag.

Images and tag names are defined [here](https://github.com/discourse/discourse_docker/blob/master/image/auto_build.rb#L6-L11).

> **A note about --squash**: By default we squash the images we serve on Docker Hub. You will need to [enable experimental features](https://github.com/docker/docker-ce/blob/master/components/cli/experimental/README.md) on your Docker daemon for that.


## More about the images

See both `auto_build.rb` and the respective `Dockerfile`s for details on _how_ all of this happens.


### base ([discourse/base](https://hub.docker.com/r/discourse/base/))

All of the dependencies for running Discourse.  This includes runit, postgres, nginx, ruby, imagemagick, etc.  It also includes the creation of the "discourse" user and `/var/www` directory.


### discourse_dev ([discourse/discourse_dev](https://hub.docker.com/r/discourse/discourse_dev/))

Adds redis and postgres just like the "standalone" template for Discourse in order to have an all-in-one container for development.  Note that you are expected to mount your local discourse source directory to `/src`.  See [the README in GitHub's discourse/bin/docker](https://github.com/discourse/discourse/tree/master/bin/docker/) for utilities that help with this.

Note that the discourse user is granted "sudo" permission without asking for a password in the discourse_dev image.  This is to facilitate the command-line Docker tools in discourse proper that run commands as the discourse user.


### discourse_test ([discourse/discourse_test](https://hub.docker.com/r/discourse/discourse_test/))

Builds on the discourse image and adds testing tools and a default testing entrypoint.


### discourse_bench ([discourse/discourse_bench](https://hub.docker.com/r/discourse/discourse_bench/))

Builds on the discourse_test image and adds benchmark testing.


### discourse_fast_switch ([discourse/discourse_fast_switch](https://hub.docker.com/r/discourse/discourse_fast_switch/))

Builds on the discourse image and adds the ability to easily switch versions of Ruby.
