# Docker buildx bake 

group "default" {
    targets = ["api"]
}

target "api" {
    context    = "."
    dockerfile = "app/Dockerfile"
    platforms  = ["linux/amd64", "linux/arm64"]
    tags       = ["${DOCKER_REGISTRY:-myrepo}/swarmfort-api:latest"]
    output     = ["type=registry"]
}