#!/bin/bash

# Prerequisites Check Script for Helm Chart Deployment
# This script checks if all required tools are installed

echo "🔍 Checking deployment prerequisites..."

# Check for required tools
MISSING_TOOLS=()

# Check Helm
if ! command -v helm &> /dev/null; then
    MISSING_TOOLS+=("helm")
    echo "❌ Helm not found"
else
    echo "✅ Helm found: $(helm version --short)"
fi

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    MISSING_TOOLS+=("gh")
    echo "❌ GitHub CLI (gh) not found"
else
    echo "✅ GitHub CLI found: $(gh version | head -1)"
fi

# Check chart-releaser (optional but recommended)
if ! command -v cr &> /dev/null; then
    echo "⚠️  chart-releaser (cr) not found (optional but recommended)"
else
    echo "✅ chart-releaser found: $(cr version)"
fi

# Check if authenticated with GitHub
if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        echo "✅ GitHub authentication verified"
    else
        echo "❌ GitHub authentication required"
        echo "   Run: gh auth login"
        MISSING_TOOLS+=("github_auth")
    fi
fi

# Report results
if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo ""
    echo "🎉 All prerequisites met! You can run ./deploy.sh"
else
    echo ""
    echo "❌ Missing prerequisites:"
    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            "helm")
                echo "   - Install Helm: https://helm.sh/docs/intro/install/"
                ;;
            "gh")
                echo "   - Install GitHub CLI: https://cli.github.com/"
                ;;
            "github_auth")
                echo "   - Authenticate with GitHub: gh auth login"
                ;;
        esac
    done
    echo ""
    echo "💡 Installation commands:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   # macOS (using Homebrew)"
        echo "   brew install helm gh"
    else
        echo "   # Ubuntu/Debian"
        echo "   curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null"
        echo "   echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main\" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list"
        echo "   sudo apt-get update && sudo apt-get install helm"
        echo "   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
        echo "   echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
        echo "   sudo apt update && sudo apt install gh"
    fi
    exit 1
fi
