#!/bin/bash

# Helm Chart Deployment Script with Authentication
# This script handles GitHub authentication and deploys the helm chart

set -e  # Exit on any error

echo "🔐 Setting up authentication and deploying helm chart..."

# Source the environment file to get GITHUB_TOKEN
if [ -f "/Users/cheddarwhizzy/cheddar/dotfiles/customers/cheddarwhizzy.sh" ]; then
    echo "📋 Loading environment variables..."
    source /Users/cheddarwhizzy/cheddar/dotfiles/customers/cheddarwhizzy.sh
fi

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN not found in environment"
    echo "   Please set GITHUB_TOKEN or run: gh auth login"
    exit 1
fi

echo "✅ GITHUB_TOKEN found"

# Authenticate with GitHub CLI using the token
echo "🔐 Authenticating with GitHub..."
echo "$GITHUB_TOKEN" | gh auth login --with-token

# Check authentication status
if gh auth status &>/dev/null; then
    echo "✅ GitHub authentication successful"
else
    echo "❌ Error: GitHub authentication failed"
    exit 1
fi

# Run the deployment script
echo "🚀 Starting deployment..."
./deploy.sh
