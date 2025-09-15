# Helm Charts Repository

Reusable Helm charts for Kubernetes deployments with comprehensive documentation and examples.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Available Charts](#available-charts)
- [Usage Examples](#usage-examples)
- [Documentation](#documentation)

## 🚀 Quick Start

### 1. Add Repository

```bash
helm repo add cheddarwhizzy https://cheddarwhizzy.github.io/helm-charts
helm repo update
```

### 2. Create Your Chart

```bash
# Create a new chart directory
mkdir my-app
cd my-app
```

### 3. Setup Chart.yaml

```yaml
# Chart.yaml
apiVersion: v2
name: my-app
description: A Helm chart for my application
type: application
version: 0.1.0
appVersion: "1.0"

dependencies:
- name: helm-base
  version: 0.1.26
  repository: https://cheddarwhizzy.github.io/helm-charts
```

### 4. Create values.yaml

```yaml
# values.yaml
# Hello World Nginx Example
fullnameOverride: hello-world
replicaCount: 2

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

# Create a ConfigMap with custom HTML
configMaps:
- name: nginx-html
  data:
    index.html: |
      <!DOCTYPE html>
      <html>
      <head>
          <title>Hello from Kubernetes</title>
      </head>
      <body>
          <h1>Hello from Kubernetes!</h1>
          <p>This page is served from a ConfigMap mounted into an Nginx container.</p>
          <p>Deployed with helm-base chart.</p>
      </body>
      </html>

# Mount the ConfigMap into the container
containers:
- name: nginx
  image: nginx:1.21
  ports:
  - name: http
    port: 80
    protocol: TCP
  volumeMounts:
  - name: nginx-html
    mountPath: /usr/share/nginx/html
    readOnly: true

# Define the volume
volumes:
- name: nginx-html
  configMap:
    name: nginx-html

# Expose the service
services:
- name: http
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP

# Add ingress for external access
ingress:
  enabled: true
  subdomain: hello-world
  domain: example.com
  routes:
  - name: default
    path: /
    pathType: Prefix
```

### 5. Deploy

```bash
# Update dependencies
helm dependency update

# Install the chart
helm install my-app .

# Check the deployment
kubectl get pods,svc,ingress
```

## 📦 Available Charts

### helm-base

**Version:** 0.1.26  
**Description:** Comprehensive base chart for DRY Kubernetes deployments

**Features:**
- ✅ Deployments, StatefulSets, Jobs, CronJobs, DaemonSets
- ✅ Services (ClusterIP, NodePort, ExternalName, LoadBalancer)
- ✅ Ingress configurations
- ✅ ConfigMaps and Secrets
- ✅ RBAC configurations
- ✅ Network policies
- ✅ External secrets (AWS Parameter Store)
- ✅ HPA and Pod Disruption Budgets
- ✅ PodMonitor and VPA
- ✅ Raw Resources (maximum flexibility)

**Documentation:** [helm-base/README.md](./charts/helm-base/README.md)  
**Configuration:** [helm-base/values.yaml](./charts/helm-base/values.yaml)

## 🎯 Usage Examples

### Subchart with Aliases

```yaml
# Chart.yaml
dependencies:
- name: helm-base
  version: 0.1.26
  repository: https://cheddarwhizzy.github.io/helm-charts
  alias: app
```

```yaml
# values.yaml
app:
  fullnameOverride: my-app
  replicaCount: 2
  image:
    repository: my-app
    tag: "latest"
  # ... app configuration

migrations:
  fullnameOverride: my-app-migration
  kind: Job
  image:
    repository: my-app
    tag: "latest"
  # ... migration configuration
```

### Direct Installation

```bash
helm install my-app cheddarwhizzy/helm-base -f my-values.yaml
```

## 📚 Documentation

- **Chart Documentation:** [helm-base/README.md](./charts/helm-base/README.md)
- **Configuration Reference:** [helm-base/values.yaml](./charts/helm-base/values.yaml)
- **Deployment Guide:** [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Examples:** See `charts/helm-base/examples/` for real-world usage patterns

## 📄 License

This project is licensed under the MIT License.