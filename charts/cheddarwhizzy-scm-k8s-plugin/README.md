# cheddarwhizzy-scm-k8s-plugin

ArgoCD ApplicationSet plugin generator for SCM-based Kubernetes chart discovery with environment and cluster fan-out support.

## Overview

This plugin automatically discovers Helm charts in GitHub repositories and generates ApplicationSet parameters for ArgoCD. It supports:

- **Multi-environment discovery**: Discovers charts by checking for `values.yaml` in `deployment/k8s/<env>/*` for qa, staging, and prod
- **Base chart referencing**: Points to `deployment/k8s/base/<chart>` where Chart.yaml lives (avoids file:// dependencies)
- **Per-environment cluster fan-out**: Configures multiple clusters per environment via `project-info.yaml`
- **Layered value file detection**: Automatically layers value files in order (base → env → image.yaml → cluster overrides)
- **Namespace management**: Supports repo-level namespace configuration via `project-info.yaml`
- **Flexible repository layouts**: Supports monorepo, split-by-env, and business app repository structures
- **Declarative ArgoCD configuration**: Charts can specify sync options, policies, and ignore differences via `argocd-config.yaml`

## Installation

```bash
# Add helm dependency
helm dependency update

# Install with default values (uses ghcr.io for prod)
helm install cheddarwhizzy-scm-k8s-plugin . -n argocd

# Install for QA environment (uses registry.cheddarwhizzy.com)
helm install cheddarwhizzy-scm-k8s-plugin . -n argocd -f values-qa.yaml

# Install for Staging environment (uses registry.cheddarwhizzy.com)
helm install cheddarwhizzy-scm-k8s-plugin . -n argocd -f values-staging.yaml

# Install for Production environment (uses ghcr.io)
helm install cheddarwhizzy-scm-k8s-plugin . -n argocd -f values-prod.yaml

# Install with custom values
helm install cheddarwhizzy-scm-k8s-plugin . -n argocd -f values.yaml
```

### Environment-Specific Values Files

The chart includes environment-specific values files:

- **values.yaml**: Default values (uses `ghcr.io` for production)
- **values-qa.yaml**: QA environment (uses `registry.cheddarwhizzy.com`)
- **values-staging.yaml**: Staging environment (uses `registry.cheddarwhizzy.com`)
- **values-prod.yaml**: Production environment (uses `ghcr.io`)

Each environment uses a different image registry:
- **QA/Staging**: `registry.cheddarwhizzy.com/cheddarwhizzy/argocd-scm-k8s-plugin:<env>`
- **Production**: `ghcr.io/cheddarwhizzy/argocd-scm-k8s-plugin:<version>`

## Configuration

### GitHub Token

The plugin requires a GitHub token for API access. Create a secret:

```bash
kubectl create secret generic github-token \
  --from-literal=GITHUB_TOKEN=<your-token> \
  -n argocd
```

### Plugin Configuration

The plugin is configured via `values.yaml`:

```yaml
pluginConfig:
  orgs:
    - mushattention
    - imagineepoxy
  envs:
    - qa
    - staging
    - prod
  defaultBranch: main
  defaultClusters:
    - name: in-cluster
      destinationName: in-cluster
```

## Repository Layout Support

The plugin supports multiple repository layout patterns:

1. **Monorepo**: `kubernetes-manifests/<cluster>/infra|apps/<namespace>/<chart>`
2. **Split-by-Env**: `kubernetes-<env>-<cluster>/infra|apps/<namespace>/<chart>`
3. **Business App**: `deployment/k8s/base/<chart>` and `deployment/k8s/<env>/<chart>`

The plugin automatically detects the layout based on repository name patterns. See [Layout Configuration Guide](docs/layout-config.md) for details.

## ArgoCD Configuration

Charts can declaratively configure ArgoCD Application settings by including an `argocd-config.yaml` file in the chart directory. This allows charts to specify sync options, sync policies, ignore differences, and revision history limits without hard-coding them in ApplicationSet templates.

### argocd-config.yaml Format

Place `argocd-config.yaml` in your chart directory (e.g., `cheddarwhizzy-prod/infra/cnpg/cloudnative-pg/argocd-config.yaml`):

```yaml
# Sync options - ServerSideApply helps with CRD annotation size limits
syncOptions:
  - ServerSideApply=true

# Ignore differences for CRDs that have large annotations or are modified by operators
ignoreDifferences:
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    jsonPointers:
      - /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
  - group: postgresql.cnpg.io
    kind: Cluster
    jsonPointers:
      - /status

# Sync policy configuration
syncPolicy:
  automated:
    prune: false
    selfHeal: true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
  managedNamespaceMetadata:
    labels:
      app.kubernetes.io/managed-by: argocd
    annotations:
      argocd.argoproj.io/sync-wave: "0"

# Limit application revision history
revisionHistoryLimit: 10
```

### Supported Fields

- **syncOptions**: Array of sync option strings (e.g., `ServerSideApply=true`, `PrunePropagationPolicy=foreground`)
- **syncPolicy**: Complete sync policy configuration
  - **automated**: Automated sync settings (prune, selfHeal, allowEmpty)
  - **retry**: Retry configuration with backoff
  - **managedNamespaceMetadata**: Labels and annotations for managed namespaces
- **ignoreDifferences**: Array of ignore difference rules for fields managed outside ArgoCD
  - **group**: API group (e.g., `apiextensions.k8s.io`)
  - **kind**: Resource kind (e.g., `CustomResourceDefinition`)
  - **jsonPointers**: JSON pointer paths to ignore (use `~1` for `/` in paths)
  - **jqPathExpressions**: JQ path expressions for complex matching
- **revisionHistoryLimit**: Number of application revisions to keep

### Usage with Git Directory Generator

When using the plugin with a git directory generator in a matrix generator, the plugin reads `argocd-config.yaml` from each discovered path and generates parameters that can be used in the ApplicationSet templatePatch:

```yaml
generators:
  - matrix:
      generators:
        - git:
            repoURL: git@github.com:cheddarwhizzy/kubernetes-manifests.git
            revision: HEAD
            directories:
              - path: cheddarwhizzy-prod/infra/*/*
        - plugin:
            configMapRef:
              name: cheddarwhizzy-scm-k8s-plugin
            input:
              parameters:
                path: '{{path}}'
                repoURL: git@github.com:cheddarwhizzy/kubernetes-manifests.git
                branch: HEAD
templatePatch: |
  spec:
    destination:
      name: '{{.cluster}}'
      namespace: '{{.namespace}}'
    {{- if .syncOptions }}
    syncPolicy:
      syncOptions:
        - CreateNamespace=true
        - RespectHelmHooks=true
        - ApplyOutOfSyncOnly=false
        - Refresh=true
        - PruneLast=true
        {{- range .syncOptions }}
        - {{.}}
        {{- end }}
    {{- end }}
    {{- if .ignoreDifferences }}
    ignoreDifferences:
      {{- range .ignoreDifferences }}
      - {{- if .Group }}group: {{.Group}}{{ end }}
        {{- if .Kind }}kind: {{.Kind}}{{ end }}
        {{- if .JSONPointers }}
        jsonPointers:
          {{- range .JSONPointers }}
          - {{.}}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
```

## Project Info Format

Each repository can include a `project-info.yaml` at the root:

```yaml
name: payload-cms

deployment:
  namespace: mushattention  # Shared across all environments
  
  environments:
    prod:
      clusters:
        - name: cluster1
          destinationName: cheddarwhizzy-civo-prod-cluster1
        - name: cluster2
          destinationName: cheddarwhizzy-civo-prod-cluster2
    staging:
      clusters:
        - name: cluster1
          destinationName: cheddarwhizzy-civo-staging-cluster1
```

## Chart Structure

Charts should be organized with base charts containing Chart.yaml and env-specific folders containing only value overrides:

**Base chart** (contains Chart.yaml and all dependencies):
```
deployment/k8s/base/<chart>/
  Chart.yaml              # Required - contains chart definition and dependencies
  values.yaml             # Base chart defaults
```

**Env-specific overrides** (no Chart.yaml - only value files):
```
deployment/k8s/<env>/<chart>/
  values.yaml             # Required - env-specific overrides (discovery indicator)
  image.yaml              # Optional - Kargo image defaults for all clusters
  values-<cluster>.yaml   # Optional - per-cluster value overrides
  image-<cluster>.yaml    # Optional - Kargo image per-cluster overrides
```

**Example**:
```
deployment/k8s/base/payload-cms/
  Chart.yaml              # Contains dependencies (no file:// references)
  values.yaml             # Global defaults

deployment/k8s/prod/payload-cms/
  values.yaml             # Prod-specific overrides (required for discovery)
  image.yaml              # Kargo image defaults for prod
  values-cluster2.yaml    # Cluster2-specific overrides
  image-cluster2.yaml     # Kargo image for cluster2
```

**Value file layering order** (later files override earlier ones):
1. `deployment/k8s/base/<chart>/values.yaml` (base chart defaults)
2. `deployment/k8s/<env>/<chart>/values.yaml` (env-specific overrides)
3. `deployment/k8s/<env>/<chart>/image.yaml` (optional, Kargo image defaults)
4. `deployment/k8s/<env>/<chart>/values-<cluster>.yaml` (optional, cluster-specific)
5. `deployment/k8s/<env>/<chart>/image-<cluster>.yaml` (optional, Kargo cluster-specific)

## ApplicationSet Usage

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: github-scm
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - plugin:
        configMapRef:
          name: cheddarwhizzy-scm-k8s-plugin
        input:
          parameters:
            orgs:
              - mushattention
              - imagineepoxy
            envs:
              - qa
              - staging
              - prod
            branch: main
  template:
    metadata:
      name: '{{.repository}}-{{.env}}-{{.chartName}}-{{.cluster}}'
    spec:
      project: cheddarwhizzy-civo-applications
      source:
        repoURL: '{{.url}}'
        targetRevision: '{{.branch}}'
        path: '{{.chartPath}}'
        helm:
          valueFiles:
            {{- range .valueFiles }}
            - '{{.}}'
            {{- end }}
      destination:
        name: '{{.destinationName}}'
        namespace: '{{.namespace}}'
      syncPolicy:
        automated:
          prune: false
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - RespectHelmHooks=true
          - ApplyOutOfSyncOnly=false
          - Refresh=true
```

## Output Parameters

The plugin generates parameters for each (repo, env, chart, cluster) combination:

```json
{
  "organization": "mushattention",
  "repository": "payload-cms",
  "url": "git@github.com:mushattention/payload-cms.git",
  "branch": "main",
  "env": "prod",
  "chartName": "payload-cms",
  "chartPath": "deployment/k8s/base/payload-cms",
  "cluster": "cluster2",
  "destinationName": "cheddarwhizzy-civo-prod-cluster2",
  "namespace": "mushattention",
  "valueFiles": [
    "deployment/k8s/base/payload-cms/values.yaml",
    "deployment/k8s/prod/payload-cms/values.yaml",
    "deployment/k8s/prod/payload-cms/image.yaml",
    "deployment/k8s/prod/payload-cms/values-cluster2.yaml",
    "deployment/k8s/prod/payload-cms/image-cluster2.yaml"
  ]
}
```

## Package Structure

The plugin is organized into logical packages:

- **types/**: Type definitions (PluginInput, Parameter, ArgoCDConfig, LayoutConfig, etc.)
- **github/**: GitHub API client wrapper
- **layout/**: Layout resolution (monorepo, split-by-env, business app)
- **generator/**: Parameter generation logic
- **handler/**: HTTP request handlers
- **utils/**: Utility functions
- **config/**: Configuration defaults and loading

See [Layout Assumptions](docs/layout-assumptions.md) for detailed documentation of current behavior and assumptions.

## Development

### Building the Plugin

```bash
# Build Go binary
go build -o plugin-server main.go

# Build Docker image
docker build -t argocd-scm-k8s-plugin:latest .

# Test locally
GITHUB_TOKEN=<token> ./plugin-server
```

### Testing

The plugin exposes two endpoints:

- `GET /healthz` - Health check
- `POST /generate` - Generate ApplicationSet parameters

Test with:

```bash
curl -X POST http://localhost:8080/generate \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "parameters": {
        "orgs": ["mushattention"],
        "envs": ["prod"],
        "branch": "main"
      }
    }
  }'
```

## License

MIT

