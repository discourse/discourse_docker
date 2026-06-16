variable "ARCH" {
  default = "amd64,arm64"
}

variable "ARCH_ARRAY" {
  default = split(",", ARCH)
}

variable "BASE_IMAGE" {
  default = "local_discourse/base"
}

variable "TEST_IMAGE" {
  default = "local_discourse/discourse_test"
}

variable "SETUP_WIZARD_IMAGE" {
  default = "local_discourse/setup-wizard"
}

variable "DEV_IMAGE" {
  default = "local_discourse/discourse_dev"
}

group "base" {
  targets = ["base-slim", "base-web-only", "base-release"]
}

group "all" {
  targets = ["base", "test", "dev"]
}

target "base-runtime-deps" {
  name = "base-runtime-deps-${arch}"
  matrix = {
    arch = ARCH_ARRAY
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:runtime-deps-${arch}"]
  target = "discourse-runtime-base"
  platforms = ["linux/${arch}"]
}

target "base-build-deps" {
  name = "base-build-deps-${arch}"
  matrix = {
    arch = ARCH_ARRAY
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:build-deps-${arch}"]
  target = "discourse-build-base"
  platforms = ["linux/${arch}"]
}

target "base-slim" {
  name = "base-slim-${branch}-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main", "stable"]
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:slim-${branch}-${arch}"]
  target = "discourse-slim"
  platforms = ["linux/${arch}"]
  args = {
    "DISCOURSE_BRANCH" = "${branch}"
  }
}

target "base-web-only" {
  name = "base-web-only-${branch}-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main", "stable"]
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:web-only-${branch}-${arch}"]
  target = "discourse-web-only"
  platforms = ["linux/${arch}"]
  args = {
    "DISCOURSE_BRANCH" = "${branch}"
  }
}

target "base-release" {
  name = "base-release-${branch}-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main", "stable"]
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:release-${branch}-${arch}"]
  target = "discourse-release"
  platforms = ["linux/${arch}"]
  args = {
    "DISCOURSE_BRANCH" = "${branch}"
  }
}

# depends on raw arch image, canary build for test images when building base images
target "test" {
  name = "test-${build_target.tag}-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main"]
    build_target = [
      {
        from_tag = "slim"
        target_name = "base"
        tag = "slim"
      },
      {
        from_tag = "slim"
        target_name = "with_browsers"
        tag = "slim-browsers"
      },
      {
        from_tag = "release"
        target_name = "release"
        tag = "release"
      }
    ]
  }
  target = build_target.target_name
  context = "./discourse_test"
  platforms = ["linux/${arch}"]
  tags = ["${TEST_IMAGE}:${build_target.tag}-${arch}"]
  args = {
    "from_tag" = "from"
  }
  contexts = {
    from = "target:base-${build_target.from_tag}-${branch}-${arch}"
  }
}

target "dev" {
  name = "dev-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main"]
  }
  context = "./discourse_dev"
  tags = ["${DEV_IMAGE}:release-${arch}"]
  platforms = ["linux/${arch}"]
  args = {
    "from_tag" = "from"
  }
  contexts = {
    from = "target:base-slim-${branch}-${arch}"
    templates = "../templates"
  }
}

target "setup-wizard" {
  name = "setup-wizard-${arch}"
  matrix = {
    arch = ARCH_ARRAY
  }
  context = "./setup_wizard"
  tags = ["${SETUP_WIZARD_IMAGE}:release-${arch}"]
  platforms = ["linux/${arch}"]
}
