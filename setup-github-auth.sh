#!/bin/bash

# GitHub Authentication Setup Script
# This script helps set up proper GitHub authentication for the helm chart deployment

echo "🔐 Setting up GitHub authentication..."

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    echo "   Please install it first:"
    echo "   # macOS: brew install gh"
    echo "   # Ubuntu: sudo apt install gh"
    exit 1
fi

echo "✅ GitHub CLI found"

# Check current authentication status
echo "🔍 Checking current authentication status..."
if gh auth status &>/dev/null; then
    echo "✅ Already authenticated with GitHub"
    gh auth status
    exit 0
fi

echo "❌ Not authenticated with GitHub"

# Check for GITHUB_TOKEN environment variable
if [ -n "$GITHUB_TOKEN" ]; then
    echo "📋 GITHUB_TOKEN environment variable is set"
    echo "   Token: ${GITHUB_TOKEN:0:10}..."
    
    # Test the token
    echo "🧪 Testing token..."
    if curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user &>/dev/null; then
        echo "✅ Token is valid"
        echo "💡 To use this token with GitHub CLI, run:"
        echo "   echo $GITHUB_TOKEN | gh auth login --with-token"
    else
        echo "❌ Token is invalid or expired"
        echo "   Please check your token at: https://github.com/settings/tokens"
    fi
else
    echo "📋 No GITHUB_TOKEN environment variable found"
fi

echo ""
echo "🔧 Authentication Options:"
echo ""
echo "1. Interactive login (recommended):"
echo "   gh auth login"
echo ""
echo "2. Login with existing token:"
echo "   echo YOUR_TOKEN | gh auth login --with-token"
echo ""
echo "3. Login with token from environment:"
echo "   echo \$GITHUB_TOKEN | gh auth login --with-token"
echo ""
echo "4. Create a new token:"
echo "   - Go to: https://github.com/settings/tokens"
echo "   - Click 'Generate new token (classic)'"
echo "   - Select scopes: repo, workflow"
echo "   - Copy the token and use option 2 above"
echo ""

# Ask user what they want to do
read -p "Would you like to run interactive login now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting interactive login..."
    gh auth login
else
    echo "💡 Please run one of the authentication commands above"
    echo "   Then run: ./deploy.sh"
fi
