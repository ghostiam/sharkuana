#!/usr/bin/env bash

# Strict mode.
set -e -u -o pipefail

red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
empty='\033[0m'

if [ "$#" -eq 0 ]; then
  echo -e "${red}Usage: $(basename "${0}") <command>${empty}"
  exit 1
fi

# Check if nix installed.
if command -v nix &>/dev/null; then
  echo -e "${green}Nix found${empty}"

  nix --experimental-features 'nix-command flakes' \
    develop --ignore-environment --command bash --norc --noprofile -c "$@"

  exit 0
fi

echo -e "${yellow}Nix not found, falling back to docker...${empty}"

# Fallback to docker with nix.
if command -v docker &>/dev/null; then
  echo -e "${green}Docker found${empty}"

  DOCKER_TAG="nix-develop-$(basename "$PWD")"

  # build docker image with nix dependencies.
  # build once and cache it until nix files change.
  docker build -t "$DOCKER_TAG" . -f ./nix.Dockerfile
  # run docker container with current directory mounted.
  # shellcheck disable=SC2068
  docker run --rm -v "$PWD":/app "$DOCKER_TAG" "./$(basename "${0}")" $@

  exit 0
fi

echo -e "${yellow}Nix and Docker not found, falling back to local...${empty}"

# shellcheck disable=SC2068
$@
