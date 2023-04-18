#!/bin/bash

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 package-name"
    exit 1
fi

package_name="$1"

# Download the provenance file.
attestations_url=$(npm view "$package_name" --json | jq -r '.dist.attestations.url')

if [ "$attestations_url" == "null" ]; then
    echo "cannot retrieve the attestation URL"
    exit 2
fi

echo "Attestations URL: $attestations_url"

provenance_attestation_file=$(mktemp "/tmp/provenance.intoto.sigstore.XXXXXXX")
publish_attestation_file=$(mktemp "/tmp/publish.intoto.sigstore.XXXXXXX")
attestations_file=$(mktemp "/tmp/attestations.intoto.sigstore.XXXXXXX")

# The SLSA provenance.
curl -s "$attestations_url" | jq -r '.attestations[0]' > "$provenance_attestation_file"
# The publish attestation.
curl -s "$attestations_url" | jq -r '.attestations[1]' > "$publish_attestation_file"
# Both attestations
curl -s "$attestations_url" | jq -r '.attestations' > "$attestations_file"

# Download the tarball in a "trusted folder".
tarball_url=$(npm view "$package_name" --json | jq -r '.dist.tarball')

if [ "$tarball_url" == "null" ]; then
    echo "cannot retrieve the tarball URL"
    exit 2
fi

echo "Tarball URL: $tarball_url"

tarball_file=$(mktemp "tarball.tgz.XXXXXXX")

curl -s "$tarball_url" > "$tarball_file"
sha512sum "$tarball_file"

# TODO: compare SHA256 of the provenance and publish attestations.
# TODO: compare the dist.integrity file if we can (optional)
# TODO: compare the package names in both atesttations.

# pkg:npm/%40laurentsimon/provenance-npm-test@1.0.0 is URL encoded.
# note: package name is versioned, but it's different from the repo tag.
echo slsa-verifier verify-npm-package "$tarball_file" \
    --attestations-path "$attestations_file" \
    --source-uri github.com/repo/name \
    --package-name "$package_name"

echo slsa-verifier verify-npm-package "$tarball_file" \
    --provenance-path "$provenance_attestation_file" \
    --publish-attestation-path "$publish_attestation_file" \
    --source-uri github.com/repo/name \
    --package-name "$package_name"
