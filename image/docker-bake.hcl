variable "TIMESTAMP" {
  default = "${formatdate("YYYYMMDD-HHmm", timestamp())}"
}

variable "ARCH" {
  default = "amd64,arm64"
}

variable "ARCH_ARRAY" {
  default = split(",", ARCH)
}

variable "BASE_REPO" {
  default = "local_discourse/base"
}

variable "TEST_REPO" {
  default = "local_discourse/discourse_test"
}

variable "SETUP_WIZARD_REPO" {
  default = "local_discourse/setup-wizard"
}

variable "DEV_REPO" {
  default = "local_discourse/discourse_dev"
}

variable "VERSION" {
  default = "2.0"
}

group "base-push-tags" {
  targets = ["base-slim", "base-web-only", "base-release"]
}

target "base-runtime-deps" {
  name = "base-runtime-deps-${arch}"
  matrix = {
    arch = ARCH_ARRAY
  }
  context = "./base"
  tags = ["${BASE_REPO}:runtime-deps-${arch}", "${BASE_REPO}:${VERSION}.${TIMESTAMP}-runtime-deps-${arch}"]
  target = "discourse-runtime-base"
  platforms = ["linux/${arch}"]
}

target "base-build-deps" {
  name = "base-build-deps-${arch}"
  matrix = {
    arch = ARCH_ARRAY
  }
  context = "./base"
  tags = ["${BASE_REPO}:build-deps-${arch}", "${BASE_REPO}:${VERSION}.${TIMESTAMP}-build-deps-${arch}"]
  target = "discourse-build-base"
  platforms = ["linux/${arch}"]
}

target "base-slim" {
  name = "base-slim-${branch}-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main", "esr"]
  }
  context = "./base"
  tags = ["${BASE_REPO}:slim-${branch}-${arch}", "${BASE_REPO}:${VERSION}.${TIMESTAMP}-slim-${branch}-${arch}"]
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
    branch = ["main", "esr"]
  }
  context = "./base"
  tags = ["${BASE_REPO}:web-only-${branch}-${arch}", "${BASE_REPO}:${VERSION}.${TIMESTAMP}-web-only-${branch}-${arch}"]
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
    branch = ["main", "esr"]
  }
  context = "./base"
  tags = ["${BASE_REPO}:release-${branch}-${arch}", "${BASE_REPO}:${VERSION}.${TIMESTAMP}-${branch}-${arch}"]
  target = "discourse-release"
  platforms = ["linux/${arch}"]
  args = {
    "DISCOURSE_BRANCH" = "${branch}"
  }
}

# depends on raw arch image, canary build for test images when building base images
target "base-test" {
  name = "base-test-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main"]
  }
  context = "./discourse_test"
  platforms = ["linux/${arch}"]
  tags = ["${TEST_REPO}:build-${arch}"]
  args = {
    "from_tag" = "from"
  }
  contexts = {
    from = "target:base-release-${branch}-${arch}"
  }
}

target "dev" {
  name = "dev-${arch}"
  matrix = {
    arch = ARCH_ARRAY
    branch = ["main"]
  }
  context = "./discourse_dev"
  tags = ["${DEV_REPO}:release-${arch}", "${DEV_REPO}:${TIMESTAMP}-${arch}"]
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
  tags = ["${SETUP_WIZARD_REPO}:release-${arch}"]
  platforms = ["linux/${arch}"]
}

# expects images with multiplatform manifests to already be tagged/pushed
target "test" {
  name = "test-${build_target.tag}"
  matrix = {
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
  context = "./discourse_test"
  tags = ["${TEST_REPO}:${build_target.tag}"]
  target = build_target.target_name
  args = {
    "from_tag" = "${BASE_REPO}:${build_target.from_tag}"
  }
}
