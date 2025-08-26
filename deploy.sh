#!/bin/bash

# Helm Chart Deployment Script
# This script packages and deploys the helm-base chart to GitHub Pages
# Creates a GitHub release with the new version

set -e  # Exit on any error

echo "🚀 Starting Helm chart deployment..."

# Configuration
CHART_NAME="helm-base"
CHART_PATH="charts/${CHART_NAME}"
PACKAGE_DIR=".cr-release-packages"
REPO_URL="https://cheddarwhizzy.github.io/helm-charts"
REPO_OWNER="cheddarwhizzy"
REPO_NAME="helm-charts"

# Clean up previous packages
echo "🧹 Cleaning up previous packages..."
rm -rf "${PACKAGE_DIR}"

# Validate chart before packaging
echo "🔍 Validating chart structure..."
if [ ! -f "${CHART_PATH}/Chart.yaml" ]; then
    echo "❌ Error: Chart.yaml not found in ${CHART_PATH}"
    exit 1
fi

if [ ! -f "${CHART_PATH}/values.yaml" ]; then
    echo "❌ Error: values.yaml not found in ${CHART_PATH}"
    exit 1
fi

# Check if virtualservice template exists
if [ ! -f "${CHART_PATH}/templates/virtualservice.yaml" ]; then
    echo "⚠️  Warning: virtualservice.yaml template not found"
else
    echo "✅ VirtualService template found"
fi

# Package the chart
echo "📦 Packaging ${CHART_NAME} chart..."
helm package "${CHART_PATH}" --destination "${PACKAGE_DIR}"

# Verify package was created
PACKAGE_FILE=$(ls -t "${PACKAGE_DIR}"/*.tgz 2>/dev/null | head -1)
if [ -z "${PACKAGE_FILE}" ]; then
    echo "❌ Error: No package file created"
    exit 1
fi

echo "✅ Chart packaged: $(basename "${PACKAGE_FILE}")"

# Extract version from package filename
PACKAGE_VERSION=$(basename "${PACKAGE_FILE}" | sed 's/helm-base-\([0-9]*\.[0-9]*\.[0-9]*\)\.tgz/\1/')
if [ "${PACKAGE_VERSION}" = "$(basename "${PACKAGE_FILE}")" ]; then
    echo "❌ Error: Could not extract version from package filename"
    exit 1
fi
echo "📋 Package version: ${PACKAGE_VERSION}"

# Create GitHub release
echo "🏷️  Creating GitHub release ${PACKAGE_VERSION}..."
if command -v gh &> /dev/null; then
    # Test GitHub authentication
    if ! gh auth status &>/dev/null; then
        echo "❌ Error: GitHub authentication required"
        echo "   Please run: gh auth login"
        echo "   Or set GITHUB_TOKEN environment variable"
        echo "   Current token status: $([ -n "$GITHUB_TOKEN" ] && echo "Set" || echo "Not set")"
        exit 1
    fi
    
    # Check if release already exists
    if gh release view "${PACKAGE_VERSION}" --repo "${REPO_OWNER}/${REPO_NAME}" &>/dev/null; then
        echo "⚠️  Warning: Release ${PACKAGE_VERSION} already exists"
    else
        # Create new release
        gh release create "${PACKAGE_VERSION}" \
            --repo "${REPO_OWNER}/${REPO_NAME}" \
            --title "${CHART_NAME}-${PACKAGE_VERSION}" \
            --notes "Base helm chart for DRY Kubernetes manifests - Version ${PACKAGE_VERSION}" \
            --draft=false \
            --prerelease=false
        echo "✅ GitHub release ${PACKAGE_VERSION} created"
    fi
else
    echo "⚠️  Warning: GitHub CLI (gh) not found, skipping release creation"
fi

# Upload chart assets to GitHub release
echo "📤 Uploading chart assets to GitHub release..."
if command -v gh &> /dev/null; then
    if gh auth status &>/dev/null; then
        gh release upload "${PACKAGE_VERSION}" "${PACKAGE_FILE}" --repo "${REPO_OWNER}/${REPO_NAME}"
        echo "✅ Chart assets uploaded to GitHub release"
    else
        echo "⚠️  Warning: GitHub authentication required, skipping asset upload"
    fi
else
    echo "⚠️  Warning: GitHub CLI (gh) not found, skipping asset upload"
fi

# Upload to GitHub Releases (if using chart-releaser as fallback)
echo "📤 Uploading to GitHub Releases (chart-releaser)..."
if command -v cr &> /dev/null; then
    if cr upload 2>/dev/null; then
        echo "✅ Chart uploaded to GitHub Releases via chart-releaser"
    else
        echo "⚠️  Warning: chart-releaser upload failed (release may already exist)"
    fi
else
    echo "⚠️  Warning: chart-releaser (cr) not found, skipping upload"
fi

# Update index.yaml with correct GitHub release URL
echo "📝 Updating chart index..."
if command -v helm &> /dev/null; then
    # Calculate the correct GitHub release URL
    RELEASE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${PACKAGE_VERSION}/$(basename "${PACKAGE_FILE}")"
    
    # Create a temporary index file
    helm repo index . --url "${RELEASE_URL}" --merge ./index.yaml
    
    # Fix any malformed URLs in the index
    sed -i.bak "s|${RELEASE_URL}/\.cr-release-packages/|${RELEASE_URL}|g" ./index.yaml
    sed -i.bak "s|${RELEASE_URL}/\.deploy/|${RELEASE_URL}|g" ./index.yaml
    rm -f ./index.yaml.bak
    
    echo "✅ Chart index updated with GitHub release URL: ${RELEASE_URL}"
else
    echo "⚠️  Warning: helm not found, skipping index update"
fi

echo "🎉 Deployment completed successfully!"
echo "📋 Summary:"
echo "   - Chart: ${CHART_NAME}"
echo "   - Version: ${PACKAGE_VERSION}"
echo "   - Package: $(basename "${PACKAGE_FILE}")"
echo "   - Repository: ${REPO_URL}"
echo "   - GitHub Release: https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/tag/${PACKAGE_VERSION}"
echo ""
echo "💡 Next steps:"
echo "   - Verify the release at: https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"
echo "   - Verify the chart is available at: ${REPO_URL}"
