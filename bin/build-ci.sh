#!/bin/bash
set -e -u
# Force Bash
if [ -z "${BASH_VERSION:-}" ]; then exec /bin/bash "$0" "$@"; fi
set -o pipefail
IFS=$'\n\t'

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Display help message
display_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build and optionally push Docker images for Verdaccio.

Options:
  --license LICENSE       Specify the license for the image (e.g., MIT)
  --description DESC      Specify a description for the image
  -v, --version VERSION   Specify the version to build
  -p, --push              Push images to Docker registry after building
  -d, --debug             Enable debug mode (set -x)
  --verbose               Enable verbose output
  -h, --help              Display this help message and exit

Examples:
  $(basename "$0") -v 5.0.0
  $(basename "$0") --version 5.0.0 --push
  $(basename "$0") -d -v 5.0.0-rc1

EOF
}

# Script variables
_LICENSE=
_DESCRIPTION=
VERSION=
_PUSH=false
_DEBUG=false
_VERBOSE=false

# Parse command line arguments
# Support both short and long options using manual parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --license)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Option $1 requires a license argument" >&2
        display_help
        exit 1
      fi
      _LICENSE="$2"
      shift 2
      ;;
    --description)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Option $1 requires a description argument" >&2
        display_help
        exit 1
      fi
      _DESCRIPTION="$2"
      shift 2
      ;;
    -v|--version)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Option $1 requires a version argument" >&2
        display_help
        exit 1
      fi
      VERSION="$2"
      shift 2
      ;;
    -p|--push)
      _PUSH=true
      shift
      ;;
    -d|--debug)
      _DEBUG=true
      shift
      ;;
    --verbose)
      _VERBOSE=true
      shift
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    --)
      # End of all options
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      display_help
      exit 1
      ;;
    *)
      # No more options, break out of loop
      break
      ;;
  esac
done

if $_DEBUG; then
  set -x
fi

if [[ "${CI:-false}" != "true" ]] && [[ "${USER:-}" != "jenkins" ]]; then
  echo "Not Running in CI mode (Jenkins), cannot run build script!"
fi
echo "Running in CI mode (Jenkins)"

_DOCKER_NAMESPACE=iwfwebsolutions
# Extract repository name from git url (ignoring docker- prefix) (e.g.: git@git:iwf-web/docker-verdaccio.git -> verdaccio) (https://serverfault.com/a/417243/955565)
_DOCKER_REPOSITORY=$(basename $GIT_URL .git | sed -r 's,^docker-,,g')
# https://docs.docker.com/docker-id/
# Docker ID (& i guess organization names) can "only contain numbers and lowercase letters"
# https://docs.docker.com/docker-hub/repos/create/
# Repository name can "only contain lowercase letters, numbers, hyphens (-), and underscores (_)"
# So we need to convert the repository name at least to lowercase
_DOCKER_IMAGE=$(echo "$_DOCKER_NAMESPACE/$_DOCKER_REPOSITORY" | tr '[:upper:]' '[:lower:]')

# Get the tag assigned to the commit (if any) (e.g.: 2.0-rc1)
# and remove the leading "v" from the tag (e.g.: v2.0-rc1 -> 2.0-rc1)
# TODO: Make dynamic
#_VERSION=$(git describe --abbrev=0 --tags --exact-match 2>/dev/null | sed -r 's,^v,,g') || true
_VERSION=$VERSION

# Clean the branch name by renaming slashes to dashes and removing origin/ prefix (e.g.: origin/feature/build -> feature-build | origin/main -> main)
_GIT_BRANCH=$(echo "$GIT_BRANCH" | sed -r 's,/+,-,g' | sed -r 's,^origin-,,g')

# https://docs.docker.com/engine/reference/commandline/tag/#extended-description
# The tag must be valid ASCII and can contain lowercase and uppercase letters, digits, underscores, periods, and hyphens. It cannot start with a
# period or hyphen and must be no longer than 128 characters. If the tag is not specified
if [[ -z "$_VERSION" ]]; then
  # If we don't have a version, we are not in the QA branch, and therefore use the
  _TAGS=("$_GIT_BRANCH-latest")
elif [[ "$_VERSION" != "${_VERSION%%-*}" ]]; then
  # ... else if we do have a version, check if we have a suffix in the version (e.g.: 2.0-rc1 -> true)
  _TAGS=("$_GIT_BRANCH-latest" "$_VERSION")
else
  # ... else we have a regular release and probably in the QA branch, so create all necessary versions (e.g.: 2.0.1 -> 2.0.1, 2.0, 2)
  # https://stackoverflow.com/a/10586169/4156752
  IFS='.' read -r -a _VERSION_ARRAY <<< "$_VERSION" # Extract version into array (e.g.: 2.0.1 -> [2, 0, 1])
  _TAGS=(latest)
  if [ -n "${_VERSION_ARRAY[0]:-}" ]; then _TAGS+=("${_VERSION_ARRAY[0]}"); fi
  if [ -n "${_VERSION_ARRAY[1]:-}" ]; then _TAGS+=("${_VERSION_ARRAY[0]}.${_VERSION_ARRAY[1]}"); fi
  if [ -n "${_VERSION_ARRAY[2]:-}" ]; then _TAGS+=("${_VERSION_ARRAY[0]}.${_VERSION_ARRAY[1]}.${_VERSION_ARRAY[2]}"); fi
fi

# Common build arguments for all images
_COMMON_BUILD_ARGS=(
  --ssh default
  --label 'maintainer=IWF Web Solutions <developer@iwf.ch>'
  --label "org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" # e.g.: 2023-11-05T20:17:40.333Z
  --label "org.opencontainers.image.url=${GIT_URL%.git}" # HTML URL, e.g.: https://github.com/iwf-web/docker-verdaccio
  --label "org.opencontainers.image.source=$GIT_URL" # Clone URL, e.g.: https://github.com/iwf-web/docker-verdaccio.git
  --label "org.opencontainers.image.version=${_TAGS[0]}" # e.g.: feature-build / develop
  --label "org.opencontainers.image.revision=$GIT_COMMIT" # Commit Hash, e.g.: ace9a2b39eef5cd7f108d96fb3e3d49b49f0d6a7
  --label "org.opencontainers.image.title=$_DOCKER_REPOSITORY" # Repository Name, e.g.: docker-verdaccio
  --label "org.opencontainers.image.description=$_DESCRIPTION" # Repository Description e.g.: My Docker image for Verdaccio
  --label "org.opencontainers.image.licenses=$_LICENSE" # e.g.: MIT
  # IWF specific labels
  --label "io.web-solutions.git-branch=$_GIT_BRANCH"
  --label "io.web-solutions.git-commit=$GIT_COMMIT" # e.g.: ace9a2b39eef5cd7f108d96fb3e3d49b49f0d6a7
  --label "io.web-solutions.git-is-dirty=$(git status -s >/dev/null && echo false || echo true)"
  --label "io.web-solutions.build-creator=$(git config user.email || echo "$USER")"
  --label "io.web-solutions.build-number=$BUILD_NUMBER" # e.g.: 1
)

# Initialize SSH Agent
eval "$(ssh-agent -s)"
ssh-add -l > /dev/null || ssh-add

# Extend build arguments with project specific arguments
_BUILD_ARGS=(
  # Expand from common build arguments
  "${_COMMON_BUILD_ARGS[@]}"
  #--build-arg 'TOKEN=MY_SECRET_KEY'
  --build-arg "VERDACCIO_VERSION=$_VERSION"
)

# Build the images, use the common build arguments, correctly prefix all tags (--tag $_DOCKER_IMAGE:X)
IFS=' ' read -r -a _TAGS <<< "${_TAGS[@]/#/--tag $_DOCKER_IMAGE:}"
if $_VERBOSE || $_DEBUG; then
  echo "Docker Image: $_DOCKER_IMAGE"

  # Extract tag values without --tag prefix
  _CLEAN_TAGS=()
  for tag in "${_TAGS[@]}"; do
    _CLEAN_TAGS+=("${tag#--tag }")
  done
  echo "Docker Tags: ${_CLEAN_TAGS[*]}"

  # Extract build arg values without --build-arg prefix
  _CLEAN_BUILD_ARGS=()
  for arg in "${_BUILD_ARGS[@]}"; do
    if [[ "$arg" == --build-arg* ]]; then
      _CLEAN_BUILD_ARGS+=("${arg#--build-arg }")
    elif [[ "$arg" != --* ]]; then
      # Skip other flags but include non-flag arguments
      _CLEAN_BUILD_ARGS+=("$arg")
    fi
  done
  echo "Build Args: ${_CLEAN_BUILD_ARGS[*]}"
fi

# TODO: Make push dynamic
docker buildx build \
  "${_BUILD_ARGS[@]}" \
  "${_TAGS[@]}" \
  --platform=linux/amd64,linux/arm64 \
  --no-cache \
  --pull \
  --push \
  "$SCRIPT_DIR/../src"

# TODO: Explore bake with compose.build.yml
#docker buildx bake \
#  --file src/Dockerfile \
#  --set "*.platform=linux/amd64,linux/arm64" \
#  --set "*.build-arg=${_BUILD_ARGS[*]}" \
#  --set "*.tags=${_TAGS[*]/#/$_DOCKER_IMAGE:}" \
#  "$SCRIPT_DIR"
