#!/bin/bash

# Manual upload script for Helm chart packages
# This script handles the upload when chart-releaser has authentication issues

set -e

echo "🔧 Manual upload script for helm-base v0.1.23"

# Configuration
PACKAGE_FILE=".cr-release-packages/helm-base-0.1.23.tgz"
RELEASE_NAME="helm-base-0.1.23"
RELEASE_TAG="helm-base-0.1.23"

# Check if package exists
if [ ! -f "$PACKAGE_FILE" ]; then
    echo "❌ Package file not found: $PACKAGE_FILE"
    exit 1
fi

echo "✅ Package file found: $PACKAGE_FILE"

# Create a temporary directory for gh-pages work
TEMP_DIR=$(mktemp -d)
echo "📁 Working in temporary directory: $TEMP_DIR"

# Clone the gh-pages branch
echo "📥 Cloning gh-pages branch..."
git clone --branch gh-pages --single-branch https://github.com/cheddarwhizzy/helm-charts.git "$TEMP_DIR/gh-pages"

# Copy the package to gh-pages
echo "📦 Copying package to gh-pages..."
cp "$PACKAGE_FILE" "$TEMP_DIR/gh-pages/"

# Update the index.yaml in gh-pages
echo "📝 Updating index.yaml in gh-pages..."
cp index.yaml "$TEMP_DIR/gh-pages/"

# Commit and push to gh-pages
cd "$TEMP_DIR/gh-pages"
git add .
git commit -m "Add helm-base v0.1.23 with VirtualService support"
git push origin gh-pages

echo "✅ Successfully uploaded to gh-pages branch"

# Clean up
cd /Users/cheddarwhizzy/cheddar/helm-charts
rm -rf "$TEMP_DIR"

echo "🎉 Manual upload completed!"
echo "📋 Summary:"
echo "   - Package: helm-base-0.1.23.tgz"
echo "   - Uploaded to: gh-pages branch"
echo "   - Index updated: index.yaml"
echo ""
echo "💡 Next steps:"
echo "   - Create a GitHub release manually at: https://github.com/cheddarwhizzy/helm-charts/releases/new"
echo "   - Tag: helm-base-0.1.23"
echo "   - Title: helm-base-0.1.23"
echo "   - Description: Add VirtualService template support for Istio service mesh"
echo "   - Upload the package file: .cr-release-packages/helm-base-0.1.23.tgz"
