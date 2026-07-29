variable "CACHE_IMAGE" {
  default = ""
  validation {
    condition = CACHE_IMAGE != ""
    error_message = "The variable 'CACHE_IMAGE' must not be empty."
  }
}

variable "ARCH" {
  deafault = ""
  validation {
    condition = ARCH != ""
    error_message = "The variable 'ARCH' must not be empty."
  }
}

target "base-runtime-deps" {
  cache-from = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-runtime-deps-${ARCH}"
  }]
}
target "base-build-deps" {
  cache-from = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-build-deps-${ARCH}"
  }]
}
target "base-slim" {
  name = "base-slim-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  cache-from = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-slim-${branch}-${ARCH}"
  }]
}
target "base-web-only" {
  name = "base-web-only-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  cache-from = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-web-only-${branch}-${ARCH}"
  }]
}
target "base-release" {
  name = "base-release-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  cache-from = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-release-${branch}-${ARCH}"
  }]
}

target "test" {
  name = "test-${tag}"
  matrix = {
    tag = ["slim", "slim-browsers", "release"]
  }
  cache-from = [
    {
      type = "registry"
      ref = "${CACHE_IMAGE}:cache-test-${tag}-${ARCH}"
    },
    {
      type = "registry"
      ref = "${CACHE_IMAGE}:cache-slim-main-${ARCH}"
    }
  ]
}

target "dev" {
  cache-from = [
    {
      type = "registry"
      ref = "${CACHE_IMAGE}:cache-dev-${ARCH}"
    },
    {
      type = "registry"
      ref = "${CACHE_IMAGE}:cache-slim-main-${ARCH}"
    }
  ]
}
