# Deployment Guide

This document covers the deployment process for the helm-charts repository, including automated releases and manual deployment procedures.

## 🚀 Automated Deployment

### GitHub Actions Workflow

The repository includes a comprehensive CI/CD pipeline that automatically:

**On Pull Requests:**
- ✅ Lints Helm charts
- ✅ Tests chart rendering with multiple configurations
- ✅ Validates Kubernetes manifests
- ✅ Runs security scans
- ✅ Tests VirtualService templates

**On Merge to Main:**
- ✅ Auto-bumps patch version in Chart.yaml
- ✅ Packages the chart
- ✅ Creates GitHub releases
- ✅ Updates the chart index
- ✅ Deploys to GitHub Pages

### Prerequisites

- Helm 3.x
- chart-releaser (for automated releases)
- GitHub Personal Access Token with appropriate permissions

### Environment Variables

For chart-releaser functionality:

```bash
export CR_TOKEN=<personal_access_token>
export CR_OWNER=cheddarwhizzy
export CR_GIT_REPO=helm-charts
export CR_PACKAGE_PATH=.cr-release-packages
export CR_GIT_BASE_URL=https://api.github.com/
export CR_GIT_UPLOAD_URL=https://uploads.github.com/
```

### Manual Deploy to GitHub Pages

```bash
# Deploy to GitHub Pages
./deploy.sh
```

**Deployment Process:**
1. Clean up previous packages
2. Validate chart structure
3. Package the chart
4. Upload to GitHub Releases
5. Update the chart index

## 🛠 Development

### Prerequisites

- Helm 3.x
- chart-releaser (for automated releases)

### Local Development

```bash
# Test template rendering
./test-virtualservice.sh

# Package chart locally
helm package charts/helm-base

# Install locally for testing
helm install test-release ./helm-base-0.1.26.tgz
```

### Scripts

- `./deploy.sh` - Deploy charts to GitHub Pages
- `./test-virtualservice.sh` - Test VirtualService templates
- `./manual-upload.sh` - Manual chart upload

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./test-virtualservice.sh`
5. Update version in `Chart.yaml`
6. Submit a pull request

### Development Guidelines

- Keep charts DRY and reusable
- Document all configuration options
- Include examples for common use cases
- Test with multiple Kubernetes versions
- Follow semantic versioning

## 📚 Additional Resources

- **Chart Documentation:** Each chart has its own README with detailed usage examples
- **Configuration Reference:** Comprehensive values.yaml with inline documentation
- **Examples:** See `charts/helm-base/examples/` for real-world usage patterns