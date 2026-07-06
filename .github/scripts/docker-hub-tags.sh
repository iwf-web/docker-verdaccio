#!/bin/bash
set -e -u
# Force Bash
if [ -z "${BASH_VERSION:-}" ]; then exec /bin/bash "$0" "$@"; fi
set -o pipefail
IFS=$'\n\t'

# List the tags of a Docker Hub repository, grouped by the manifest digest they
# point to, as JSON (so callers can post-process with jq). Tags that resolve to
# the same image (e.g. 2.4.1, 2.4, 2, latest) share a digest, so they show up
# under a single group.

# Display help message
display_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [REPOSITORY]

List Docker Hub tags grouped by the manifest digest they point to, as JSON.

Arguments:
  REPOSITORY              Docker Hub repo, e.g. 'verdaccio/verdaccio' or 'php'.
                          A bare name (no slash) is treated as an official
                          image (prefixed with 'library/'). Required.

Options:
  -l, --latest            Emit only the newest group (highest version) as a
                          single JSON object instead of an array. Useful for
                          repos that maintain several minor lines (e.g. PHP
                          8.1-8.5) when you only care about the latest one.
  -d, --debug             Enable debug mode (set -x)
  -h, --help              Display this help message and exit

Examples:
  $(basename "$0") verdaccio/verdaccio     # all groups, JSON array
  $(basename "$0") php                      # official PHP image, JSON array
  $(basename "$0") --latest php             # newest PHP line, single object
  $(basename "$0") -l verdaccio/verdaccio   # newest Verdaccio version

Output:
  Without --latest, a JSON array of groups, newest first. 'version' is the
  most specific version-like tag in the group (null if none). 'tags' is the
  full tag list, version-sorted:
    [
      {"digest":"sha256:abc...","version":"2.4.1","tags":["2","2.4","2.4.1","latest"]},
      {"digest":"sha256:def...","version":"1.9.3","tags":["1","1.9","1.9.3"]}
    ]
  With --latest, just the first (newest) object:
    {"digest":"sha256:abc...","version":"2.4.1","tags":["2","2.4","2.4.1","latest"]}

EOF
}

# Script variables
REPO=
_LATEST=false
_DEBUG=false

# Parse command line arguments
# Support both short and long options using manual parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--latest)
      _LATEST=true
      shift
      ;;
    -d|--debug)
      _DEBUG=true
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
      if [[ -n "$REPO" ]]; then
        echo "Error: Unexpected extra argument: $1" >&2
        display_help
        exit 1
      fi
      REPO="$1"
      shift
      ;;
  esac
done

if $_DEBUG; then
  set -x
fi

if [[ -z "$REPO" ]]; then
  echo "Error: REPOSITORY argument is required" >&2
  display_help
  exit 1
fi

# Bare names (no namespace) are Docker Official Images living under 'library/'.
if [[ "$REPO" != */* ]]; then
  REPO="library/$REPO"
fi

# Dependencies
for _cmd in curl jq sort; do
  if ! command -v "$_cmd" > /dev/null 2>&1; then
    echo "Error: required command '$_cmd' not found in PATH" >&2
    exit 1
  fi
done

# Fetch every tag from the Docker Hub API (paginated), emitting one
# "<digest>\t<tag>" line per tag. The top-level .digest is the manifest(-list)
# digest, which is identical for every tag that points to the same image.
fetch_pairs() {
  local url="https://hub.docker.com/v2/repositories/${REPO}/tags?page_size=100"
  local resp
  while [[ -n "$url" && "$url" != "null" ]]; do
    if ! resp=$(curl -fsSL "$url"); then
      echo "Error: failed to fetch tags for '$REPO' (is the repository name correct?)" >&2
      exit 1
    fi
    jq -r '.results[] | select(.digest != null) | [.digest, .name] | @tsv' <<< "$resp"
    url=$(jq -r '.next' <<< "$resp")
  done
}

PAIRS=$(fetch_pairs)
if [[ -z "$PAIRS" ]]; then
  echo "No tags found for '$REPO'." >&2
  exit 1
fi

# Unique digests, in first-seen order. (Associative arrays are avoided so this
# runs on the stock Bash 3.2 shipped by macOS as well as CI's Bash 4+.)
DIGESTS=$(cut -f1 <<< "$PAIRS" | awk 'NF && !seen[$0]++')

# Tags pointing at a given digest.
tags_of() {
  awk -F'\t' -v d="$1" '$1 == d { print $2 }' <<< "$PAIRS"
}

# Highest version-like tag in a group (used to rank groups). Non-numeric tags
# like 'latest' or 'nightly' are ignored here; a group with none ranks lowest.
rep_version() {
  tags_of "$1" | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -1
}

# One group as a JSON object: {digest, version, tags[]}. Tags are version-sorted
# ascending; version is the most specific version-like tag (null if none).
group_json() {
  local digest="$1" tags_nl version
  tags_nl=$(tags_of "$digest" | grep -v '^$' | sort -V)
  version=$(rep_version "$digest")
  jq -nc \
    --arg digest "$digest" \
    --arg version "$version" \
    --arg tags "$tags_nl" \
    '{
      digest: $digest,
      version: (if $version == "" then null else $version end),
      tags: ($tags | split("\n") | map(select(length > 0)))
    }'
}

# Order groups newest-first by their representative version; version-less
# groups sort last (rep defaults to "0").
DIGESTS_SORTED=$(
  while IFS= read -r digest; do
    [[ -z "$digest" ]] && continue
    printf '%s\t%s\n' "$(rep_version "$digest")" "$digest"
  done <<< "$DIGESTS" | sed 's/^\t/0\t/' | sort -Vr | cut -f2
)

if $_LATEST; then
  # The first entry is the highest-versioned group.
  group_json "$(head -1 <<< "$DIGESTS_SORTED")"
else
  # Emit each group as a JSON line, then fold them into a single array.
  while IFS= read -r digest; do
    [[ -z "$digest" ]] && continue
    group_json "$digest"
  done <<< "$DIGESTS_SORTED" | jq -s '.'
fi
