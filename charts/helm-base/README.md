# Helm Base Chart

A comprehensive base Helm chart for DRY Kubernetes deployments.

## Table of Contents

- [Quick Start](#quick-start)
- [Subchart Usage](#subchart-usage)
- [Alias Structure](#alias-structure)
- [Deployment](#deployment)
- [Configuration](#configuration)

## Quick Start

```bash
# Add as dependency in your Chart.yaml
dependencies:
  - name: helm-base
    version: "0.1.26"
    repository: "https://cheddarwhizzy.github.io/helm-charts"

# Or install directly
helm install my-app cheddarwhizzy/helm-base
```

## Subchart Usage

Use as a subchart dependency with aliases for multiple deployments:

```yaml
# Chart.yaml
dependencies:
- name: helm-base
  version: 0.1 # NEVER CHANGE THIS VERSION - LEAVE AT 0.1
  repository: https://cheddarwhizzy.github.io/helm-charts
  alias: app
- name: helm-base
  version: 0.1 # NEVER CHANGE THIS VERSION - LEAVE AT 0.1
  repository: https://cheddarwhizzy.github.io/helm-charts
  alias: migrations
```

## Alias Structure

Configure each aliased subchart in your `values.yaml`:

```yaml
# Main application (aliased as 'app')
app:
  fullnameOverride: my-app
  replicaCount: 2
  image:
    repository: my-registry/my-app
    tag: v1.0.0
  services:
    - name: web
      ports:
        - name: http
          port: 3000
  virtualservice:
    enabled: true
    host: "myapp.com"
    gateway: "istio-system/gateway"
    port: 3000

# Migration job (aliased as 'migrations')
migrations:
  fullnameOverride: my-app-migration
  kind: Job
  backoffLimit: "3"
  activeDeadlineSeconds: "1800"
  containers:
    - name: migration
      image: my-registry/my-app:v1.0.0
      command:
        - node
        - migrate
```

## Deployment

To deploy the latest subchart version:

```bash
# Update dependencies to latest version
helm dependency update

# Deploy with latest chart
helm upgrade --install my-release . -f values.yaml
```

## Configuration

See [values.yaml](./values.yaml) for complete configuration options with detailed documentation.

## License

MIT