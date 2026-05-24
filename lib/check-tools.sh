#!/usr/bin/env bash
# Verify the toolchain needed by the labs. Lists missing tools at the end.

set -u

missing=()
check() {
  local name=$1
  local hint=$2
  if command -v "$name" >/dev/null 2>&1; then
    printf '  \033[32m✓\033[0m %-12s %s\n' "$name" "$(command -v "$name")"
  else
    printf '  \033[31m✗\033[0m %-12s (install: %s)\n' "$name" "$hint"
    missing+=("$name")
  fi
}

echo "Core toolchain"
check docker    "https://docs.docker.com/engine/install/ or Rancher/OrbStack"
check kind      "brew install kind"
check kubectl   "brew install kubectl"
check helm      "brew install helm"

echo
echo "Per-pattern extras"
check cilium    "brew install cilium-cli (pattern 02, 03)"
check istioctl  "brew install istioctl (pattern 04, 05)"
check tofu      "brew install opentofu (pattern 08, OpenTofu replaces Terraform)"
check jq        "brew install jq (several patterns)"

echo
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing: ${missing[*]}"
  exit 1
fi
echo "All tools present."
