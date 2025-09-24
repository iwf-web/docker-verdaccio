# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker image for Verdaccio (a lightweight private npm proxy registry) with plugins required for IWF. It's designed to work with GitLab authentication and AWS S3 storage.

## Architecture

- **Base**: Multi-stage Dockerfile building on top of the official Verdaccio Docker image
- **Plugins**: Includes `verdaccio-gitlab` for GitLab authentication and `verdaccio-aws-s3-storage` for S3 storage
- **Configuration**: Main config file at `src/config.yaml` with settings for authentication, storage, and package management
- **Build System**: CI/CD build script at `bin/build-ci.sh` for multi-platform Docker image builds

## Key Files

- `src/Dockerfile`: Multi-stage build definition using Alpine Node.js to install plugins
- `src/config.yaml`: Verdaccio configuration with GitLab auth and S3 storage settings
- `compose.yml`: Development setup with Verdaccio, MinIO (S3-compatible storage), and setup services
- `compose.build.yml`: Build-specific Docker Compose configuration for multi-platform builds
- `bin/build-ci.sh`: CI build script with Docker Buildx for cross-platform image creation

## Common Commands

### Development
```bash
# Start development environment with MinIO (S3-compatible storage)
docker compose up

# Build for development (using compose.yml)
docker compose build
```

### Production Builds
```bash
# Build multi-platform images (requires CI environment or manual override)
./bin/build-ci.sh --version 6.1.0

# Build with push to registry
./bin/build-ci.sh --version 6.1.0 --push

# Build for specific platforms using compose.build.yml
docker compose -f compose.build.yml build
```

## Configuration Details

- **GitLab Authentication**: Configured to authenticate against `https://git.iwf.io`
- **Storage**: Uses AWS S3 storage plugin with configurable endpoints (supports LocalStack for development)
- **Ports**: Verdaccio runs on port 4873 (exposed as 4874), MinIO on 9001
- **Environment Variables**: AWS credentials and S3 configuration via environment variables

## Development Setup

The project uses MinIO as a local S3-compatible storage service for development. The setup automatically creates required buckets and configures access.

## Build System

The `bin/build-ci.sh` script handles:
- Multi-platform builds (linux/amd64, linux/arm64)
- Version tagging and Docker registry management
- Metadata labels for tracking builds
- SSH agent setup for private repository access

## Branching Strategy

According to the contributing guidelines:
- Base new features off the `develop` branch
- Bug fixes should target the oldest affected release line
- Use descriptive branch names and separate unrelated changes
