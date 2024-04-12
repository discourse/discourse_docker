# Launcher2

Build and run discourse images. Drop in replacement for launcher the shell script.

## Changes from launcher

No software prerequisites are checked here. It assumes you have docker set up and whatever minimum requirements setup for Discourse: namely a recent enough version of docker, git.

Some things are not implemented from launcher1.

* `DOCKER_HOST_IP` - container can use `host.docker.internal` in most cases. Supported on mac and windows... can also be [added on linux via docker args](https://stackoverflow.com/questions/72827527/what-is-running-on-host-docker-internal-host).
* debug containers - not implemented. No debug containers saved on build. Under the hood, launcher2 uses docker build which does not allow images to be saved along the way.
* stable `mac-address` - not implemented.

## New features

In a nutshell: split bootstrap/rebuild process up into distinct parts to allow for greater flexibility in how we build and deploy Discourse containers.

### Separates bootstrap process into distinct build, configure, and migrate steps.

Separating the larger bootstrap process into separate steps allows us to break up the work.

`bootstrap` becomes an alias for: `build`, `migrate`, `configure`. There are multiple benefits to this.

#### Build: Easier creation for prebuilt docker images

Share built docker images by only running a `build` step - this build step does not need to connect to a database.
It does not need postgres or redis running. This makes for a simple way to install custom plugins to your Discourse image.

The resulting image is able to be used in Kubernetes and other docker environments.

This is done by deferring finishing the build step, to a later configure step -- which boostraps the db, and precompiles assets.

The `configure` and `migrate` steps can now be done on boot through use of env vars set in the `app.yml` config: `CREATE_DB_ON_BOOT`, `MIGRATE_ON_BOOT`, and `PRECOMPILE_ON_BOOT`, which allows for more portable containers able to drop in and bootstrap themselves and the database as they come into service.

#### Build: Better environment management

The resulting image from a build is a container with no environment (unless `--bake-env` is specified). Additionally, well-known secrets are excluded from the build environment, resulting in a clean history of the prebuilt image that may be more easily shared.

Environment is only bound to a container either with `--bake-env` on build, or on a subsequent `configure` step.

#### Migrate: Adds support to *when* migrations are run

`Build` and `Configure` steps do not run migrations, allowing for external tooling to specify exactly when migrations are run.

`Migrate`, (and`bootstrap`, and `rebuild`) steps are the only ones that run migrations.

#### Migrate: Adds support for *how* migrations are run: `SKIP_POST_DEPLOYMENT_MIGRATIONS` support

the `migrate` step exposes env vars that turn on separate post deploy migration steps.

Allows the ability to turn on and skip post migration steps from launcher when running a stand-alone migrate step.

#### Rebuild: Minimize downtime

Both standalone and multi-container setups' downtime have been minimized for rebuilds

##### Standalone
On standalone builds, only stop the running container after the base build is done.
Standalone sites will only need to be offline during migration and configure steps.

For standalone, `rebuild` runs `build`, `stop`, `migrate`, `configure`, `destroy`, `start`.

##### Multiple container, web only
On multi-container setups or setups with a configured external database using web only containers, rebuilds attempt to run migrations without stopping the container.
A multi-container stays up as migration (skipping post deployment migrations) and as any necessary configuration steps are run. After deploy, post deployment migrations are run to clean up any destructive migrations.

For web-only, `rebuild` runs `build`, `migrate (skip post migrations)`, `configure`, `destroy`, `start`, `migrate`.

#### Rebuild: Serve offline page during downtime

Adds the ability to build and run an image that finishes a build on boot, allowing the server to display an offline page.
For standalone builds above, this allows for the accrued downtime from migration and configure steps to happen more gracefully.

Additional container env vars get turned on by adding the `offline-page.template.yml` template:
  * `CREATE_DB_ON_BOOT`
  * `MIGRATE_ON_BOOT`
  * `PRECOMPILE_ON_BOOT`

These allow containers to boot cleanly from a cold state, and complete db creation, migration, and precompile steps on boot.

During this time, nginx can be up which allows standalone builds to display an offline page.

These variables may also be used for other applications where more flexible bootstrapping is desired.

##### Standalone
On rebuild, a standalone site will skip migration if it detects the presence of `MIGRATE_ON_BOOT` in the app config, and will skip configure steps if it detects the presence of `PRECOMPILE_ON_BOOT` in the app config.

For standalone, `rebuild` runs `build`, `destroy`, `start`, skipping `migrate` and `configure`. The started container then serves an offline page, and runs migrate and precompiles assets before fully entering service.

##### Multiple container, web only
On rebuild, a web only container will act in the same way as a standalone container. This may result in the same downtime as standalone services, as the containers are swapped, and the new container is still responsible for migration and precompiling before serving traffic.

For web-only containers, it may be desired to either ensure that `MIGRATE_ON_BOOT` and `PRECOMPILE_ON_BOOT` are false. Alternatively, you may run with `--full-build` which will ensure that migration and precompile steps are not deferred for the 'live' deploy.

### Multiline env support

Allows the use of multiline env vars so this is valid config, and is passed through to the container as expected:
```
env:
  SECRET_KEY: |
    ---START OF SECRET KEY---
    123456
    78910
    ---END OF SECRET KEY---
```

### More dependable SIGINT/SIGTERM handling.

Launcher wraps docker run commands, which run as children in process trees. Launcher2 does the same, but attempts to kill or stop the underlying docker processes from interrupt signals.

Tools that extend or depend on launcher should be able to send SIGINT/SIGTERM signals to tell launcher to shut down, and launcher should clean up child processes appropriately.

### Docker compose generation.

Allows easier exporting of configuration from discourse's pups configuration to a docker compose configuration.

### Autocomplete support

Run `source <(./launcher2 sh)` to activate completions for the current shell, or add the results of `./launcher2 sh` to your dotfiles

Autocompletes commands, subcommands, and suggests `app` config files from your containers directory. Having a long site name should not feel like a pain to type.

## Maintainability

Golang is well suited as a drop in replacement as just like a shellscript, the deployed binary can still carry minimal assumptions about a particular platform to run. (IE, no dependency on ruby, python, etc)

Golang allows us to use a fully fleshed out programming language to run native yaml parsing: Calling out to ruby through a docker container worked well enough, but got complicated shuffling results through stdout into shell variables.

Launcher has outgrown being a simple wrapper script around Docker. Golang has good support for tests and breaking up code into separate modules to better support further growth around additional subcommands we may wish to add.

## Roadmap

Scaffolding out subcommands, possibly as a later rewrite for `discourse-setup` as having native YAML libraries should make config parsing and editing simpler to do.
