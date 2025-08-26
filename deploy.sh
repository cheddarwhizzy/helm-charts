#!/bin/bash

# Helm Chart Deployment Script
# This script packages and deploys the helm-base chart to GitHub Pages

set -e  # Exit on any error

echo "🚀 Starting Helm chart deployment..."

# Configuration
CHART_NAME="helm-base"
CHART_PATH="charts/${CHART_NAME}"
PACKAGE_DIR=".cr-release-packages"
REPO_URL="https://cheddarwhizzy.github.io/helm-charts"

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

# Upload to GitHub Releases (if using chart-releaser)
echo "📤 Uploading to GitHub Releases..."
if command -v cr &> /dev/null; then
    cr upload
    echo "✅ Chart uploaded to GitHub Releases"
else
    echo "⚠️  Warning: chart-releaser (cr) not found, skipping upload"
fi

# Update index.yaml
echo "📝 Updating chart index..."
if command -v cr &> /dev/null; then
    cr index -i ./index.yaml -c "${REPO_URL}"
    echo "✅ Chart index updated"
else
    echo "⚠️  Warning: chart-releaser (cr) not found, skipping index update"
fi

echo "🎉 Deployment completed successfully!"
echo "📋 Summary:"
echo "   - Chart: ${CHART_NAME}"
echo "   - Package: $(basename "${PACKAGE_FILE}")"
echo "   - Repository: ${REPO_URL}"
echo ""
echo "💡 Next steps:"
echo "   - Commit and push changes to GitHub"
echo "   - Verify the chart is available at: ${REPO_URL}"
