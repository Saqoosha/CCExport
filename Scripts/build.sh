#!/usr/bin/env bash
# Generate the Xcode project from project.yml and build CCExport.app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
CONFIGURATION="${1:-Debug}"

mkdir -p "${BUILD_DIR}"

xcodegen generate --spec "${ROOT_DIR}/project.yml"

xcodebuild \
  -scheme CCExport \
  -configuration "${CONFIGURATION}" \
  -destination 'platform=macOS' \
  -derivedDataPath "${BUILD_DIR}" \
  build

echo "Built app: ${BUILD_DIR}/Build/Products/${CONFIGURATION}/CCExport.app"
