#!/usr/bin/env bash
# Install the xScaler agent on remote Linux hosts.
# Requires only Docker — no Ansible or Python needed locally.
#
# Usage:
#   ./install.sh --hosts web-01.example.com                           # prompts for token + SSH password
#   ./install.sh --hosts azure@20.31.128.253                          # user@host format supported
#   ./install.sh --hosts web-01.example.com --key ~/.ssh/id_rsa       # SSH key auth
#   ./install.sh --hosts web-01.example.com --user ubuntu --key ~/.ssh/my_key
#   ./install.sh --inventory ./hosts.yml
#   ./install.sh --hosts web-01.example.com --check                   # dry run
#
# The token can also be supplied via the XSCALER_TOKEN environment variable:
#   export XSCALER_TOKEN=xse_...
#   ./install.sh --hosts web-01.example.com
#
# Options:
#   --token     xScaler enrollment token (xse_...) — omit to be prompted securely
#   --hosts     Comma-separated list of target hostnames/IPs (user@host format supported)
#   --inventory Path to a custom Ansible inventory file
#   --key       SSH private key path for key-based auth
#   --password  Prompt for SSH password (use instead of --key for password auth)
#   --user      SSH username override (default: root, or user from user@host)
#   --env       Environment label (default: prod)
#   --region    Region label (default: us)
#   --check     Dry run — show what would change without applying
#   --verify    Run the verify playbook instead of the install playbook
#   --build     Force-rebuild the installer image (auto-built on first run)

set -euo pipefail

IMAGE="${XSCALER_IMAGE:-xscaler-installer}"
XSCALER_TOKEN="${XSCALER_TOKEN:-}"
ANSIBLE_SSH_PASS="${ANSIBLE_SSH_PASS:-}"
SSH_KEY=""
PROMPT_PASSWORD=false
TARGET_HOSTS=""
INVENTORY=""
ANSIBLE_USER=""
XSCALER_ENV=""
XSCALER_REGION=""
CHECK=false
VERIFY=false
BUILD=false

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --token)     XSCALER_TOKEN="$2";    shift 2 ;;
        --hosts)     TARGET_HOSTS="$2";     shift 2 ;;
        --inventory) INVENTORY="$2";        shift 2 ;;
        --key)       SSH_KEY="$2";       shift 2 ;;
        --password)  PROMPT_PASSWORD=true; shift ;;
        --user)      ANSIBLE_USER="$2";     shift 2 ;;
        --env)       XSCALER_ENV="$2";      shift 2 ;;
        --region)    XSCALER_REGION="$2";   shift 2 ;;
        --check)     CHECK=true;            shift ;;
        --verify)    VERIFY=true;           shift ;;
        --build)     BUILD=true;            shift ;;
        --help|-h)   usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "${TARGET_HOSTS}" && -z "${INVENTORY}" ]]; then
    echo "Error: provide --hosts or --inventory" >&2
    exit 1
fi

# Prompt for token if not supplied via --token or env var
if [[ -z "${XSCALER_TOKEN}" ]]; then
    read -r -s -p "xScaler enrollment token (xse_...): " XSCALER_TOKEN
    echo
fi
if [[ -z "${XSCALER_TOKEN}" ]]; then
    echo "Error: token is required" >&2
    exit 1
fi

# Prompt for SSH password when --password flag given or no --key provided
if [[ "${PROMPT_PASSWORD}" == "true" || ( -z "${SSH_KEY}" && -z "${ANSIBLE_SSH_PASS}" ) ]]; then
    read -r -s -p "SSH password for target hosts: " ANSIBLE_SSH_PASS
    echo
fi

# Build if requested, or build automatically on first run
if [[ "${BUILD}" == "true" ]]; then
    echo "Building installer image from local source..."
    docker build -t "${IMAGE}" .
elif ! docker image inspect "${IMAGE}" &>/dev/null; then
    echo "Image '${IMAGE}' not found locally. Building from source..."
    docker build -t "${IMAGE}" .
fi

DOCKER_ARGS=(
    --rm
    -e "XSCALER_TOKEN=${XSCALER_TOKEN}"
    -e "CHECK=${CHECK}"
)

[[ -n "${TARGET_HOSTS}"    ]] && DOCKER_ARGS+=(-e "TARGET_HOSTS=${TARGET_HOSTS}")
[[ -n "${XSCALER_ENV}"     ]] && DOCKER_ARGS+=(-e "XSCALER_ENV=${XSCALER_ENV}")
[[ -n "${XSCALER_REGION}"  ]] && DOCKER_ARGS+=(-e "XSCALER_REGION=${XSCALER_REGION}")
[[ -n "${ANSIBLE_USER}"    ]] && DOCKER_ARGS+=(-e "ANSIBLE_USER=${ANSIBLE_USER}")
[[ -n "${ANSIBLE_SSH_PASS}" ]] && DOCKER_ARGS+=(-e "ANSIBLE_SSH_PASS=${ANSIBLE_SSH_PASS}")
[[ "${VERIFY}" == "true"   ]] && DOCKER_ARGS+=(-e "VERIFY=true")

if [[ -n "${SSH_KEY}" ]]; then
    DOCKER_ARGS+=(-v "$(realpath "${SSH_KEY}"):/root/.ssh/id_rsa:ro")
fi

if [[ -n "${INVENTORY}" ]]; then
    DOCKER_ARGS+=(-v "$(realpath "${INVENTORY}"):/workspace/inventories/prod/hosts.yml:ro")
fi

docker run "${DOCKER_ARGS[@]}" "${IMAGE}"
