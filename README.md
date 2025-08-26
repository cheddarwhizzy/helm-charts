# Helm Charts Repository

This repository contains reusable Helm charts for Kubernetes deployments.

## Charts

### helm-base

A base Helm chart for DRY (Don't Repeat Yourself) Kubernetes manifests with support for:
- Deployments and StatefulSets
- Services (ClusterIP, NodePort, ExternalName)
- Ingress configurations
- **VirtualService templates (NEW!)**
- ConfigMaps and Secrets
- CronJobs
- RBAC configurations
- Network policies
- And more...

#### Version: 0.1.23

**Latest Changes:**
- ✨ Added VirtualService template support for Istio service mesh
- 🔧 Improved deployment script with better error handling
- 📝 Enhanced documentation and examples

## Quick Start

### Installation

```bash
# Add the repository
helm repo add cheddarwhizzy https://cheddarwhizzy.github.io/helm-charts

# Update repository
helm repo update

# Install the chart
helm install my-app cheddarwhizzy/helm-base
```

### Using VirtualService (NEW!)

The chart now supports Istio VirtualService templates for advanced traffic routing:

```yaml
# values.yaml
services:
  - name: web
    type: ClusterIP
    ports:
      - name: http
        port: 8080

virtualservice:
  enabled: true
  host: "myapp.example.com"
  gateway: "mesh"
  port: 8080
  annotations:
    custom.annotation: "value"
  routes:
    - name: default
      host: "app.example.com"
      port: 8080
      path: /
      corsPolicy:
        allowOrigins:
          - exact: "https://example.com"
        allowMethods:
          - GET
          - POST
        allowHeaders:
          - authorization
          - content-type
      retries:
        attempts: 3
        perTryTimeout: 2s
      timeout: 30s
  aliases:
    - "www.example.com"
```

## Development

### Prerequisites

- Helm 3.x
- chart-releaser (optional, for automated releases)

### Local Development

```bash
# Test template rendering
./test-virtualservice.sh

# Package chart locally
helm package charts/helm-base

# Install locally for testing
helm install test-release ./helm-base-0.1.23.tgz
```

### Deployment

```bash
# Deploy to GitHub Pages
./deploy.sh
```

The deployment script will:
1. Clean up previous packages
2. Validate chart structure
3. Package the chart
4. Upload to GitHub Releases (if chart-releaser is available)
5. Update the chart index

### Environment Variables

For chart-releaser functionality, set these environment variables:

```bash
export CR_TOKEN=<personal_access_token>
export CR_OWNER=cheddarwhizzy
export CR_GIT_REPO=helm-charts
export CR_PACKAGE_PATH=.cr-release-packages
export CR_GIT_BASE_URL=https://api.github.com/
export CR_GIT_UPLOAD_URL=https://uploads.github.com/
```

## Chart Configuration

### Key Features

- **Multi-service support**: Deploy multiple services with a single chart
- **Flexible ingress**: Support for multiple ingress controllers
- **VirtualService integration**: Istio service mesh support
- **CronJob support**: Scheduled job deployments
- **RBAC integration**: Role-based access control
- **Network policies**: Pod-to-pod communication rules

### Common Values

```yaml
# Basic deployment
replicaCount: 1
apiVersion: apps/v1
kind: Deployment

# Services
services:
  - name: web
    type: ClusterIP
    ports:
      - name: http
        port: 8080

# VirtualService (NEW!)
virtualservice:
  enabled: true
  host: "example.com"
  routes:
    - name: default
      path: /
      port: 8080
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./test-virtualservice.sh`
5. Update version in `Chart.yaml`
6. Submit a pull request

## License

This project is licensed under the MIT License.
