# Llama Stack Playground Container

This container builds and runs the TypeScript UI application from the [meta-llama/llama-stack](https://github.com/meta-llama/llama-stack) repository.

## Building the Image

### Single Architecture Build

To build the image for your current architecture:

```bash
podman build -t quay.io/rh-aiservices-bu/llama-stack-playground .
```

### Multi-Architecture Build

To build the image for multiple architectures (linux/amd64 and linux/arm64):

```bash
# Create and use a new builder instance that supports multi-platform builds
podman buildx create --name multiarch-builder --use

# Build and push for multiple architectures
podman buildx build \
  --platform linux/amd64,linux/arm64 \
  -t quay.io/rh-aiservices-bu/llama-stack-playground \
  --push .
```

### Alternative Multi-Architecture Build (using manifest)

If you prefer to build each architecture separately:

```bash
# Build for AMD64
podman build --platform linux/amd64 -t quay.io/rh-aiservices-bu/llama-stack-playground:amd64 .

# Build for ARM64
podman build --platform linux/arm64 -t quay.io/rh-aiservices-bu/llama-stack-playground:arm64 .

# Push both architecture-specific images
podman push quay.io/rh-aiservices-bu/llama-stack-playground:amd64
podman push quay.io/rh-aiservices-bu/llama-stack-playground:arm64

# Create and push a multi-architecture manifest
podman manifest create quay.io/rh-aiservices-bu/llama-stack-playground
podman manifest add quay.io/rh-aiservices-bu/llama-stack-playground quay.io/rh-aiservices-bu/llama-stack-playground:amd64
podman manifest add quay.io/rh-aiservices-bu/llama-stack-playground quay.io/rh-aiservices-bu/llama-stack-playground:arm64
podman manifest push quay.io/rh-aiservices-bu/llama-stack-playground
```

## Running the Container

```bash
podman run -p 3000:3000 quay.io/rh-aiservices-bu/llama-stack-playground
```

The TypeScript application will be available at http://localhost:3000

## Prerequisites

- Podman with buildx support (for multi-architecture builds)
- Access to push to the quay.io/rh-aiservices-bu registry