# Docker Verdaccio (with Plugins required for IWF)

This is a Docker image for [Verdaccio](https://verdaccio.org/) (a lightweight private npm proxy registry) with some plugins required for [IWF](https://iwf.ch).

Project

[![License](https://img.shields.io/github/license/iwf-web/docker-verdaccio)][license]

## Getting Started

These instructions will help you install this library in your project and tell you how to use it.

### Prerequisites

Before using this Docker Verdaccio setup, ensure you have the following installed:

- **Docker** (version 20.10 or later) - [Install Docker](https://docs.docker.com/get-docker/)
- **Docker Compose** (version 2.0 or later) - [Install Docker Compose](https://docs.docker.com/compose/install/)
- **Git** - For cloning the repository
- **SSH Keys** (optional) - Configured for GitLab authentication if you plan to use GitLab auth

For production builds, you'll also need:
- **Docker Buildx** - For multi-platform builds (usually included with Docker Desktop)

### Installing

#### Option 1: Clone and Build Locally

1. **Clone the repository:**
   ```bash
   git clone https://github.com/iwf-web/docker-verdaccio.git
   cd docker-verdaccio
   ```

2. **Build and run with Docker Compose (recommended for development):**
   ```bash
   docker compose up --build
   ```
   This will:
   - Build the Verdaccio image with plugins
   - Start MinIO (S3-compatible storage) for local development
   - Create necessary S3 buckets automatically
   - Start Verdaccio on port 4873

3. **Build for production:**
   ```bash
   ./bin/build-ci.sh --version 6.1.0
   ```

#### Option 2: Use Pre-built Image

If available from the registry:
```bash
docker pull iwfwebsolutions/verdaccio:latest
```

### Usage

#### Starting the Service

1. **Development Mode (with local MinIO S3 storage):**

   ```bash
   docker compose up
   ```

   Access points:
   - **Verdaccio Web UI**: http://localhost:4873
   - **MinIO Console**: http://localhost:9001 (admin/admin123 or minio/minio123)

2. **Production Mode:**

   Configure your environment variables and run:
   ```bash
   docker run -p 4873:4873 \
     -e AWS_S3_BUCKET=your-bucket \
     -e AWS_ACCESS_KEY_ID=your-key \
     -e AWS_SECRET_ACCESS_KEY=your-secret \
     iwfwebsolutions/verdaccio:latest
   ```

#### Configuring NPM/Yarn Clients

1. **Set the registry URL:**

   ```bash
   npm config set registry http://localhost:4873
   # or for yarn
   yarn config set registry http://localhost:4873
   ```

2. **Login with GitLab credentials:**

   ```bash
   npm login --registry http://localhost:4873
   ```

   Use your GitLab username and personal access token.

#### Publishing Packages

```bash
npm publish --registry http://localhost:4873
```

#### Authentication

This setup uses GitLab authentication against `https://git.iwf.io`. Users can authenticate using their GitLab credentials:

- **Username**: Your GitLab username
- **Password**: GitLab personal access token with `read_api` scope

#### Storage

- **Development**: Uses MinIO (S3-compatible) running locally
- **Production**: Configured for AWS S3 storage with environment variables

## Built With

- [Verdaccio](https://verdaccio.org/) - Private npm proxy registry

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and [CONTRIBUTING.md](CONTRIBUTING.md) for the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository][gh-tags].

## Authors

All the authors can be seen in the [AUTHORS.md](AUTHORS.md) file.

Contributors can be seen in the [CONTRIBUTORS.md](CONTRIBUTORS.md) file.

See also the full list of [contributors][gh-contributors] who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details

## Acknowledgments

A list of used libraries and code with their licenses can be seen in the [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md) file.

[license]: https://github.com/iwf-web/docker-verdaccio/blob/main/LICENSE.txt
[gh-tags]: https://github.com/iwf-web/docker-verdaccio/tags
[gh-contributors]: https://github.com/iwf-web/docker-verdaccio/contributors
