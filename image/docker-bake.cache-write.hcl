target "base-runtime-deps" {
  cache-to = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-runtime-deps-${ARCH}"
    mode = "max"
  }]
}
target "base-build-deps" {
  cache-to = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-build-deps-${ARCH}"
    mode = "max"
  }]
}
target "base-slim" {
  name = "base-slim-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  cache-to = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-slim-${branch}-${ARCH}"
    mode = "max"
  }]
}
target "base-web-only" {
  name = "base-web-only-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  cache-to = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-web-only-${branch}-${ARCH}"
    mode = "max"
  }]
}
target "base-release" {
  name = "base-release-${branch}"
  matrix = {
    branch = ["main", "stable"]
  }
  cache-to = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-release-${branch}-${ARCH}"
    mode = "max"
  }]
}

target "test" {
  name = "test-${tag}"
  matrix = {
    tag = ["slim", "slim-browsers", "release"]
  }
  cache-to = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-test-${tag}-${ARCH}"
    mode = "max"
  }]
}

target "dev" {
  cache-to = [{
    type = "registry"
    ref = "${CACHE_IMAGE}:cache-dev-${ARCH}"
    mode = "max"
  }]
}
