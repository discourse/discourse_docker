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

variable "DATESTAMP" {
  default = "0"
}

target "base-runtime-deps" {
  context = "./base"
  tags = ["${BASE_IMAGE}:runtime-deps"]
  target = "discourse-runtime-base"
  args = {
    "DATESTAMP" = DATESTAMP
  }
}

target "base-build-deps" {
  context = "./base"
  tags = ["${BASE_IMAGE}:build-deps"]
  target = "discourse-build-base"
}

target "base-slim" {
  name = "base-slim-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:slim-${branch}"]
  target = "discourse-slim"
  args = {
    "DISCOURSE_BRANCH" = "${branch}"
  }
}

target "base-web-only" {
  name = "base-web-only-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:web-only-${branch}"]
  target = "discourse-web-only"
  args = {
    "DISCOURSE_BRANCH" = "${branch}"
  }
}

target "base-release" {
  name = "base-release-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  context = "./base"
  tags = ["${BASE_IMAGE}:release-${branch}"]
  target = "discourse-release"
  args = {
    "DISCOURSE_BRANCH" = "${branch}"
  }
}

target "test" {
  name = "test-${build_target.tag}"
  matrix = {
    build_target = [
      {
        target_name = "base"
        tag = "slim"
      },
      {
        target_name = "with_browsers"
        tag = "slim-browsers"
      },
      {
        target_name = "release"
        tag = "release"
      }
    ]
  }
  target = build_target.target_name
  context = "./discourse_test"
  tags = ["${TEST_IMAGE}:${build_target.tag}"]
  args = {
    "from_tag" = "from"
    "SOURCE_DATE_EPOCH" = 0
  }
  contexts = {
    from = "target:base-slim-main"
  }
}

target "dev" {
  context = "./discourse_dev"
  tags = ["${DEV_IMAGE}:release"]
  args = {
    "from_tag" = "from"
    "SOURCE_DATE_EPOCH" = 0
  }
  contexts = {
    from = "target:base-slim-main"
    templates = "../templates"
  }
}

target "setup-wizard" {
  context = "./setup_wizard"
  tags = ["${SETUP_WIZARD_IMAGE}:release"]
}
