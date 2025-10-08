# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the official Discourse Docker deployment system (`discourse_docker`). It provides Docker images, launcher scripts, and templates for deploying and managing Discourse forum instances. The system uses a container orchestration approach with pups-managed YAML templates.

## Core Architecture

### Launcher Script (`./launcher`)

The primary interface for all container operations. Written in Bash, it manages the complete lifecycle of Discourse containers:

- `./launcher bootstrap CONFIG` - Initial container setup from templates
- `./launcher start CONFIG` - Start a container
- `./launcher stop CONFIG` - Stop a running container
- `./launcher restart CONFIG` - Restart a container
- `./launcher destroy CONFIG` - Stop and remove a container
- `./launcher enter CONFIG` - Shell into a running container
- `./launcher logs CONFIG` - View container logs
- `./launcher rebuild CONFIG` - Full rebuild (destroy + bootstrap + start)
- `./launcher cleanup` - Remove stopped containers (>24h old)

CONFIG refers to a YAML file in `/containers/` (e.g., `app.yml`).

### Setup Scripts

- `./discourse-setup` - Interactive initial configuration wizard that creates container YAML files
- `./discourse-doctor` - Diagnostic tool for troubleshooting installations

### Directory Structure

- `/containers/` - User-managed container definitions (you create these)
- `/samples/` - Example container configurations to copy from:
  - `standalone.yml` - All-in-one single container setup (easiest)
  - `data.yml` + `web_only.yml` - Multi-container setup (production)
  - `mail-receiver.yml` - Mail receiver container
  - `redis.yml` - Standalone Redis container
- `/templates/` - pups-managed YAML templates that are composed into containers:
  - `postgres.template.yml` - PostgreSQL (current stable version)
  - `postgres.{15,13,12,10,9.5}.template.yml` - Specific PostgreSQL versions
  - `redis.template.yml` - Redis configuration
  - `web.template.yml` - Nginx + Rails web server
  - `web.ssl.template.yml` - SSL/HTTPS support
  - `web.letsencrypt.ssl.template.yml` - Let's Encrypt SSL
  - `web.ratelimited.template.yml` - Rate limiting
  - `cron.template.yml` - Scheduled tasks
  - Other specialized templates for CDN, caching, etc.
- `/image/` - Dockerfiles and build scripts for base images
- `/shared/` - Persistent data mounted into containers (logs, uploads, backups)
- `/cids/` - Container IDs for running containers

### Container Configuration (YAML Files)

Container definitions use YAML with these sections:

- `templates:` - Array of template files to compose
- `expose:` - Port mappings (format: `"host_port:container_port"`)
- `params:` - Template parameters (e.g., `db_shared_buffers`, `version`)
- `env:` - Environment variables for the container
- `volumes:` - Volume mounts (host to guest mappings)
- `links:` - Link to other containers
- `hooks:` - Custom pups hooks (before_code, after_code, etc.)
- `run:` - Commands to execute during bootstrap

**IMPORTANT**: YAML is whitespace-sensitive. Use https://yamllint.com/ to validate.

### pups Template System

Templates use pups (https://github.com/discourse/pups) which processes YAML configurations. Templates define:
- Base images via `base_image:`
- Environment setup via `env:` and `params:`
- Bootstrap commands via `run:` blocks
- File creation via `file:` directives
- Command execution via `exec:` directives
- Text replacement via `replace:` directives

### Docker Images

Built via `image/auto_build.rb`:

```bash
# Build a specific image (run from /image/ directory)
ruby auto_build.rb IMAGE_NAME
```

Available images (defined in `auto_build.rb`):
- `base_*` - Base images with Discourse dependencies (multiple targets: deps, slim, web_only, release)
- `discourse_dev_*` - Development environment (includes Redis + PostgreSQL)
- `discourse_test_*` - Test environment with testing tools
- Suffixes: `_amd64` or `_arm64` for architecture
- Variations: `_main` (latest) or `_stable` (stable branch)

Image types:
- **discourse/base** - Production-ready with all dependencies (postgres, nginx, ruby, imagemagick, etc.)
- **discourse/discourse_dev** - All-in-one dev container (mount source to `/src`)
- **discourse/discourse_test** - Test environment with testing tools

Published to Docker Hub at `discourse/base` and `discourse/discourse_dev`.

## Common Development Tasks

### Testing discourse-setup

Run tests from `/tests/` directory:

```bash
cd tests
./run-all-tests        # Run all tests
./standalone-tests     # Test standalone.yml generation
./two-container-tests  # Test multi-container setup
./update-old-templates # Test template upgrades
```

**Note**: Tests require that `app.yml` and `web_only.yml` do not exist.

### Building Docker Images

```bash
cd image
ruby auto_build.rb base_release_main_amd64  # Build amd64 release image
ruby auto_build.rb discourse_dev_arm64      # Build arm64 dev image
```

See `.github/workflows/build.yml` for the full CI build process.

### Deploying Containers

```bash
# Copy a sample configuration
cp samples/standalone.yml containers/app.yml

# Edit the configuration (set DISCOURSE_HOSTNAME, SMTP settings, etc.)
nano containers/app.yml

# Bootstrap and start
sudo ./launcher bootstrap app
sudo ./launcher start app

# Or rebuild everything
sudo ./launcher rebuild app
```

### Upgrading Discourse

Two methods:
1. Web UI: `http://yoursite.com/admin/upgrade`
2. Command line: `sudo ./launcher rebuild app`

### Troubleshooting

```bash
# View logs
./launcher logs app

# Enter container for debugging
./launcher enter app

# Run diagnostics
./discourse-doctor app
```

## Architecture Notes

### Single vs Multi-Container

**Single Container** (`standalone.yml`):
- All services in one container (PostgreSQL, Redis, Nginx, Rails)
- Easiest to set up and manage
- Suitable for smaller installations

**Multi-Container** (`data.yml` + `web_only.yml`):
- Separate data and web containers
- Zero-downtime upgrades (rebuild web while data keeps running)
- Horizontal scaling capability
- Requires firewall configuration (iptables/ufw) to protect PostgreSQL/Redis ports

### Template Composition

Containers compose templates in order. Later templates can override earlier ones via hooks. Example from `standalone.yml`:

```yaml
templates:
  - "templates/postgres.template.yml"
  - "templates/redis.template.yml"
  - "templates/web.template.yml"
  - "templates/web.ratelimited.template.yml"
```

### Bundled Plugins

The launcher script defines `BUNDLED_PLUGINS` array (line 26-59) containing official Discourse plugins that can be installed via the docker_manager.

## Important Constraints

- **Root required**: `launcher` and `discourse-setup` must run as root (use `sudo`)
- **Email required**: Discourse requires SMTP configuration to function
- **No bare IPs**: Must use a domain name for `DISCOURSE_HOSTNAME`
- **Persistent data**: All data stored in `/shared` volumes - containers are stateless
- **Port conflicts**: Default ports 80/443 must be available (or configure alternative ports)
- **YAML sensitivity**: Indentation and whitespace matter - validate before rebuilding

## CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`):
- Builds all image variants (amd64/arm64, main/stable, slim/web_only/release)
- Runs Discourse specs on built images
- Publishes to Docker Hub on main branch
- Creates multi-arch manifests
- Scheduled daily builds

## Environment Variables

Key environment variables in container configs:
- `DISCOURSE_HOSTNAME` - Domain name (required)
- `DISCOURSE_DEVELOPER_EMAILS` - Admin emails on first signup
- `DISCOURSE_SMTP_ADDRESS/PORT/USER_NAME/PASSWORD` - Email config (required)
- `DISCOURSE_DB_HOST/PORT/SOCKET` - Database connection
- `UNICORN_WORKERS` - Web worker count (auto-detected based on CPU)
- `LETSENCRYPT_ACCOUNT_EMAIL` - For Let's Encrypt SSL
- `DISCOURSE_CDN_URL` - CDN configuration
- `RAILS_ENV` - Usually 'production'

## Version Management

- Default: Uses `version: latest` to pull latest Discourse version
- Can pin to specific version: `version: v3.1.0` in container params
- Base image version specified in `web.template.yml` (e.g., `discourse/base:2.0.20251003-1437`)
