TOPDIR=$(dir $(lastword $(MAKEFILE_LIST)))

DOCKERFILE_DIR     ?= ./
CONTAINER_CMD         ?= podman
CONTAINER_REGISTRY    ?= docker.io
CONTAINER_ORG         ?= cyberbugjr
CONTAINER_TAG         ?= $(shell cat $(TOPDIR)/release.version)
BUILD_TAG          ?= latest
PROJECT_NAME       ?= vaultwarden-backups

all: CONTAINER_build CONTAINER_push

CONTAINER_build_default:
	# Build Docker image ...
	$(CONTAINER_CMD) $(CONTAINER_BUILDX) build $(CONTAINER_PLATFORM) $(CONTAINER_BUILD_ARGS) -t $(CONTAINER_ORG)/$(PROJECT_NAME):latest $(DOCKERFILE_DIR)
#   The Dockerfiles all use FROM ...:latest, so it is necessary to tag images with latest (-t above)
	# Also tag with $(BUILD_TAG)
	$(CONTAINER_CMD) tag $(CONTAINER_ORG)/$(PROJECT_NAME):latest $(CONTAINER_ORG)/$(PROJECT_NAME):$(BUILD_TAG)$(CONTAINER_PLATFORM_TAG_SUFFIX)

CONTAINER_tag_default:
	# Tag the $(BUILD_TAG) image we built with the given $(CONTAINER_TAG) tag
	$(CONTAINER_CMD) tag $(CONTAINER_ORG)/$(PROJECT_NAME):$(BUILD_TAG)$(CONTAINER_PLATFORM_TAG_SUFFIX) $(CONTAINER_REGISTRY)/$(CONTAINER_ORG)/$(PROJECT_NAME):$(CONTAINER_TAG)$(CONTAINER_PLATFORM_TAG_SUFFIX)
	# Tag the $(BUILD_TAG) image we built with the latest tag
	$(CONTAINER_CMD) tag $(CONTAINER_ORG)/$(PROJECT_NAME):$(BUILD_TAG)$(CONTAINER_PLATFORM_TAG_SUFFIX) $(CONTAINER_REGISTRY)/$(CONTAINER_ORG)/$(PROJECT_NAME):latest$(CONTAINER_PLATFORM_TAG_SUFFIX)

CONTAINER_push_default: CONTAINER_tag
	# Push the $(CONTAINER_TAG)-tagged image to the registry
	$(CONTAINER_CMD) push $(CONTAINER_REGISTRY)/$(CONTAINER_ORG)/$(PROJECT_NAME):$(CONTAINER_TAG)$(CONTAINER_PLATFORM_TAG_SUFFIX)
	# Push the latest-tagged image to the registry
	$(CONTAINER_CMD) push $(CONTAINER_REGISTRY)/$(CONTAINER_ORG)/$(PROJECT_NAME):latest$(CONTAINER_PLATFORM_TAG_SUFFIX)

CONTAINER_%: CONTAINER_%_default
	@  true