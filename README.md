# Docker Verdaccio (with Plugins required for IWF)

This is a Docker image for [Verdaccio](https://verdaccio.org/) (a lightweight private npm proxy registry) with some plugins required for [IWF](https://iwf.ch).

[![License](https://img.shields.io/github/license/iwf-web/docker-verdaccio?label=License)](LICENSE.txt)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa)][code-of-conduct]
[![Docker Pulls](https://img.shields.io/docker/pulls/iwfwebsolutions/verdaccio)](https://hub.docker.com/r/iwfwebsolutions/verdaccio)

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

## Running the tests

### Code style

```bash
brew install hadolint
hadolint src/Dockerfile
```

## Built With

- [Verdaccio](https://verdaccio.org/) - Private npm proxy registry

## Contributing

Please read [CONTRIBUTING.md][contributing] for details on our code of conduct and the process for submitting pull requests.

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

## Versioning

We use [SemVer](http://semver.org/) for versioning. For available versions, see the [tags on this repository][gh-tags].

## Authors

### Special thanks for all the people who had helped this project so far

- **Manuele** - [D3strukt0r](https://github.com/D3strukt0r)

See also the full list of [contributors][gh-contributors] who participated in this project.

### I would like to join this list. How can I help the project?

We're currently looking for contributions for the following:

- [ ] Bug fixes
- [ ] Translations
- [ ] etc...

For more information, please refer to our [CONTRIBUTING.md][contributing] guide.

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

## Acknowledgments

This project currently uses no third-party libraries or copied code.

[gh-tags]: https://github.com/iwf-web/docker-verdaccio/tags
[gh-contributors]: https://github.com/iwf-web/docker-verdaccio/contributors
[contributing]: https://github.com/iwf-web/.github/blob/main/CONTRIBUTING.md
[code-of-conduct]: https://github.com/iwf-web/.github/blob/main/CODE_OF_CONDUCT.md
