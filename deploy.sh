#!/bin/bash

# Helm Chart Deployment Script
# This script packages and deploys the helm-base chart to GitHub Pages
# Creates a GitHub release with the new version

set -e  # Exit on any error

# Parse command line arguments
VERSION_BUMP=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --bump)
            VERSION_BUMP="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--bump {major|minor|patch}]"
            echo ""
            echo "Options:"
            echo "  --bump {major|minor|patch}  Bump version before deploying (default: patch)"
            echo "  --help, -h                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Deploy current version"
            echo "  $0 --bump patch       # Bump patch version and deploy"
            echo "  $0 --bump minor       # Bump minor version and deploy"
            echo "  $0 --bump major       # Bump major version and deploy"
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown option $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Starting Helm chart deployment..."

# Check if semver tool is available (if version bumping is requested)
if [ -n "${VERSION_BUMP}" ] && ! command -v semver &> /dev/null; then
    echo "❌ Error: semver tool not found. Please install it with: brew install semver"
    exit 1
fi

# Ensure we're in the correct directory
if [ ! -f "charts/${CHART_NAME}/Chart.yaml" ]; then
    echo "❌ Error: Chart.yaml not found. Please run this script from the helm-charts repository root."
    echo "   Expected path: charts/${CHART_NAME}/Chart.yaml"
    exit 1
fi

# Bump version if requested
if [ -n "${VERSION_BUMP}" ]; then
    echo "📈 Bumping version (${VERSION_BUMP})..."
    bump_version "${VERSION_BUMP}"
fi

# Configuration
CHART_NAME="helm-base"
CHART_PATH="charts/${CHART_NAME}"
PACKAGE_DIR=".cr-release-packages"
REPO_URL="https://cheddarwhizzy.github.io/helm-charts"
REPO_OWNER="cheddarwhizzy"
REPO_NAME="helm-charts"

# Function to bump version using semver tool
bump_version() {
    local version_type="${1:-patch}"
    local chart_yaml="${CHART_PATH}/Chart.yaml"
    
    if [ ! -f "${chart_yaml}" ]; then
        echo "❌ Error: Chart.yaml not found at ${chart_yaml}"
        exit 1
    fi
    
    # Get current version
    local current_version=$(grep "^version:" "${chart_yaml}" | awk '{print $2}' | tr -d '"')
    echo "📋 Current version: ${current_version}"
    
    # Bump version using semver tool
    local new_version=$(semver bump "${version_type}" "${current_version}")
    echo "📋 New version: ${new_version}"
    
    # Update Chart.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version:.*/version: ${new_version}/" "${chart_yaml}"
    else
        # Linux
        sed -i "s/^version:.*/version: ${new_version}/" "${chart_yaml}"
    fi
    
    echo "✅ Version bumped to ${new_version}"
}

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

# Create GitHub release with proper tag name
RELEASE_TAG="${CHART_NAME}-${PACKAGE_VERSION}"
echo "🏷️  Creating GitHub release ${RELEASE_TAG}..."
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
    if gh release view "${RELEASE_TAG}" --repo "${REPO_OWNER}/${REPO_NAME}" &>/dev/null; then
        echo "⚠️  Warning: Release ${RELEASE_TAG} already exists"
    else
        # Create new release
        gh release create "${RELEASE_TAG}" \
            --repo "${REPO_OWNER}/${REPO_NAME}" \
            --title "${CHART_NAME}-${PACKAGE_VERSION}" \
            --notes "Base helm chart for DRY Kubernetes manifests - Version ${PACKAGE_VERSION}" \
            --draft=false \
            --prerelease=false
        echo "✅ GitHub release ${RELEASE_TAG} created"
    fi
else
    echo "⚠️  Warning: GitHub CLI (gh) not found, skipping release creation"
fi

# Upload chart assets to GitHub release
echo "📤 Uploading chart assets to GitHub release..."
if command -v gh &> /dev/null; then
    if gh auth status &>/dev/null; then
        gh release upload "${RELEASE_TAG}" "${PACKAGE_FILE}" --repo "${REPO_OWNER}/${REPO_NAME}"
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
    # Calculate the correct GitHub release URL using the proper tag
    RELEASE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${RELEASE_TAG}/$(basename "${PACKAGE_FILE}")"
    
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

# Commit and push changes to git
echo "📝 Committing and pushing changes..."
if command -v git &> /dev/null; then
    # Check if we're in a git repository
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Add all changes
        git add .
        
        # Create commit message
        if [ -n "${VERSION_BUMP}" ]; then
            COMMIT_MSG="🚀 Release ${CHART_NAME} v${PACKAGE_VERSION} (${VERSION_BUMP} bump)"
        else
            COMMIT_MSG="🚀 Release ${CHART_NAME} v${PACKAGE_VERSION}"
        fi
        
        # Commit changes
        git commit -m "${COMMIT_MSG}"
        
        # Push to remote
        git push origin main
        echo "✅ Changes committed and pushed to git"
    else
        echo "⚠️  Warning: Not in a git repository, skipping git operations"
    fi
else
    echo "⚠️  Warning: git not found, skipping git operations"
fi

echo "🎉 Deployment completed successfully!"
echo "📋 Summary:"
echo "   - Chart: ${CHART_NAME}"
echo "   - Version: ${PACKAGE_VERSION}"
echo "   - Package: $(basename "${PACKAGE_FILE}")"
echo "   - Repository: ${REPO_URL}"
echo "   - GitHub Release: https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/tag/${RELEASE_TAG}"
echo ""
echo "💡 Next steps:"
echo "   - Verify the release at: https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"
echo "   - Verify the chart is available at: ${REPO_URL}"
