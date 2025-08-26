# Helm Chart Deployment Guide

This guide explains how to deploy the helm-base chart and create GitHub releases.

## Prerequisites

Before deploying, ensure you have the following tools installed:

### Required Tools
- **Helm**: Kubernetes package manager
- **GitHub CLI (gh)**: For creating GitHub releases

### Optional Tools
- **chart-releaser (cr)**: For additional chart repository management

## Quick Start

1. **Check prerequisites**:
   ```bash
   ./check-prerequisites.sh
   ```

2. **Deploy the chart**:
   ```bash
   ./deploy.sh
   ```

## What the Deployment Script Does

The `deploy.sh` script performs the following steps:

1. **Validation**: Checks that required chart files exist
2. **Packaging**: Creates a Helm chart package (.tgz file)
3. **Version Extraction**: Extracts the version from the package filename
4. **GitHub Release**: Creates a new GitHub release with the version tag
5. **Asset Upload**: Uploads the chart package to the GitHub release
6. **Index Update**: Updates the chart repository index (if chart-releaser is available)

## Version Management

### Current Version
The current chart version is defined in `charts/helm-base/Chart.yaml`:
```yaml
version: 0.1.23
```

### Versioning Strategy
- **Major version (x.y.z)**: Breaking changes
- **Minor version (x.y.z)**: New features, backward compatible
- **Patch version (x.y.z)**: Bug fixes, backward compatible

### Updating Version
To update the version:

1. Edit `charts/helm-base/Chart.yaml`
2. Update the `version` field
3. Run the deployment script

## GitHub Release Process

The deployment script automatically:

1. **Creates a GitHub release** with the version tag (e.g., `0.1.23`)
2. **Sets release title** as `helm-base-0.1.23`
3. **Adds release notes** describing the chart
4. **Uploads chart assets** to the release
5. **Marks as stable release** (not draft or prerelease)

## Repository Structure

```
helm-charts/
├── charts/
│   └── helm-base/
│       ├── Chart.yaml          # Chart metadata and version
│       ├── values.yaml         # Default values
│       └── templates/          # Kubernetes templates
├── deploy.sh                   # Main deployment script
├── check-prerequisites.sh      # Prerequisites checker
├── index.yaml                  # Chart repository index
└── .cr-release-packages/       # Generated packages (gitignored)
```

## Troubleshooting

### Common Issues

1. **GitHub CLI not authenticated**:
   ```bash
   gh auth login
   ```

2. **Release already exists**:
   - The script will warn you if a release with the same version already exists
   - Update the version in `Chart.yaml` before running again

3. **Missing tools**:
   - Run `./check-prerequisites.sh` to identify missing tools
   - Follow the installation instructions provided

### Manual Release Creation

If you need to create a release manually:

```bash
# Package the chart
helm package charts/helm-base

# Create GitHub release
gh release create 0.1.23 \
  --repo cheddarwhizzy/helm-charts \
  --title "helm-base-0.1.23" \
  --notes "Base helm chart for DRY Kubernetes manifests - Version 0.1.23"

# Upload assets
gh release upload 0.1.23 helm-base-0.1.23.tgz --repo cheddarwhizzy/helm-charts
```

## Chart Repository

The chart is available at: https://cheddarwhizzy.github.io/helm-charts

### Adding the Repository

```bash
helm repo add cheddarwhizzy https://cheddarwhizzy.github.io/helm-charts
helm repo update
```

### Installing the Chart

```bash
helm install my-release cheddarwhizzy/helm-base
```

## CI/CD Integration

The deployment process can be integrated into CI/CD pipelines:

1. **GitHub Actions**: Use the `gh` CLI in workflows
2. **Jenkins**: Execute the deployment script as a build step
3. **GitLab CI**: Run the script in pipeline stages

### Example GitHub Actions Workflow

```yaml
name: Deploy Helm Chart
on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v3
        with:
          go-version: '1.19'
      - name: Install Helm
        run: |
          curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
          sudo mv linux-amd64/helm /usr/local/bin/
      - name: Deploy Chart
        run: |
          ./deploy.sh
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Security Considerations

- **Authentication**: Always use GitHub CLI authentication for releases
- **Version Control**: Keep chart versions in sync with Git tags
- **Validation**: The script validates chart structure before packaging
- **Backup**: Chart packages are stored in GitHub releases for backup

## Support

For issues with the deployment process:

1. Check the troubleshooting section above
2. Review the script output for error messages
3. Verify GitHub authentication and permissions
4. Ensure all prerequisites are met
