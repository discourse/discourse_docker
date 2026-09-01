# push targets, push by digests
target "_common-push" {
  output = [{
    type = "registry",
    push-by-digest = true
  }]
}

target "base-runtime-deps" {
  inherits = ["_common-push"]
  tags = [BASE_IMAGE]
}
target "base-build-deps" {
  inherits = ["_common-push"]
  tags = [BASE_IMAGE]
}
target "base-slim" {
  name = "base-slim-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  inherits = ["_common-push"]
  tags = [BASE_IMAGE]
}
target "base-web-only" {
  name = "base-web-only-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  inherits = ["_common-push"]
  tags = [BASE_IMAGE]
}
target "base-release" {
  name = "base-release-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  inherits = ["_common-push"]
  tags = [BASE_IMAGE]
}
target "dev" {
  inherits = ["dev", "_common-push"]
  tags = [DEV_IMAGE]
}
target "test" {
  name = "test-${tag}"
  matrix = {
    tag = ["slim", "slim-browsers", "release"]
  }
  inherits = ["_common-push"]
  tags = [TEST_IMAGE]
}
target "setup-wizard" {
  inherits = ["_common-push"]
  tags = [SETUP_WIZARD_IMAGE]
}
