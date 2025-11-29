# Layout Configuration Guide

This document explains how to configure the plugin to support different repository layout patterns.

## Supported Layout Strategies

The plugin supports three layout strategies:

1. **Monorepo** (`monorepo`): Single repository containing multiple clusters
   - Example: `kubernetes-manifests/<cluster>/infra|apps/<namespace>/<chart>`
   
2. **Split-by-Env** (`split-by-env`): Separate repositories per environment/cluster
   - Example: `kubernetes-prod-cluster1/infra/<namespace>/<chart>`
   - Example: `kubernetes-qa-cluster2/apps/<namespace>/<chart>`

3. **Business App** (`business-app`): Application repositories with deployment structure
   - Example: `deployment/k8s/base/<chart>` and `deployment/k8s/<env>/<chart>`

## Automatic Layout Detection

The plugin automatically detects the layout strategy based on repository name patterns:

- **Monorepo**: Repositories matching `kubernetes-manifests*`
- **Split-by-Env**: Repositories matching `kubernetes-*-*` pattern (e.g., `kubernetes-prod-cluster1`)
- **Business App**: All other repositories

## Monorepo Layout

### Path Structure
```
<cluster-name>/infra|apps/<namespace>/<chart>/
```

### Example
```
cheddarwhizzy-prod/infra/cnpg/cloudnative-pg/
```

### Configuration
- **Cluster**: Extracted from path segment 0 (currently hard-coded to "in-cluster" for backward compatibility)
- **Type**: Extracted from path segment 1 ("infra" or "apps")
- **Namespace**: Extracted from path segment 2
- **Chart**: Extracted from path segment 3

### Default Config
```go
LayoutConfig{
    Strategy: LayoutMonorepo,
    ClusterResolver: {
        Static: "in-cluster",  // Can be changed to use path segment 0
    },
    PathStructure: {
        TypeIndex:      1,
        NamespaceIndex: 2,
        ChartIndex:     3,
    },
}
```

## Split-by-Env Layout

### Path Structure
```
infra|apps/<namespace>/<chart>/
```

### Repository Naming
Repositories must follow the pattern: `kubernetes-<env>-<cluster>`

Examples:
- `kubernetes-prod-cluster1`
- `kubernetes-qa-cluster2`
- `kubernetes-staging-cluster1`

### Configuration
- **Environment**: Extracted from repo name using pattern `kubernetes-(.+)-(.+)` (capture group 1)
- **Cluster**: Extracted from repo name using pattern `kubernetes-(.+)-(.+)` (capture group 2)
- **Type**: Extracted from path segment 0 ("infra" or "apps")
- **Namespace**: Extracted from path segment 1
- **Chart**: Extracted from path segment 2

### Default Config
```go
LayoutConfig{
    Strategy: LayoutSplitByEnv,
    ClusterResolver: {
        FromRepoPattern: "kubernetes-(.+)-(.+)",
    },
    EnvResolver: {
        FromRepoPattern: "kubernetes-(.+)-(.+)",
    },
    PathStructure: {
        TypeIndex:      0,
        NamespaceIndex: 1,
        ChartIndex:     2,
    },
}
```

## Business App Layout

### Path Structure
```
deployment/k8s/base/<chart>/          # Base chart (contains Chart.yaml)
deployment/k8s/<env>/<chart>/         # Environment-specific overrides
```

### Configuration
Business app layout uses `project-info.yaml` for configuration instead of path parsing:
- **Namespace**: From `project-info.yaml` → `deployment.namespace`
- **Clusters**: From `project-info.yaml` → `deployment.environments.<env>.clusters`
- **Environment**: From ApplicationSet `envs` parameter

## Custom Layout Configuration

To use a custom layout configuration, you can:

1. **Extend the layout loader** (`config/loader.go`) to read from a config file
2. **Add per-repo configuration** by reading `layout-config.yaml` from repository root
3. **Use environment variables** to override default behavior

### Example: Custom Monorepo with Cluster from Path

```yaml
# layout-config.yaml (in repository root)
strategy: monorepo
clusterResolver:
  fromPathIndex: 0  # Use path segment 0 instead of static value
pathStructure:
  typeIndex: 1
  namespaceIndex: 2
  chartIndex: 3
```

## Migration Guide

### From Hard-coded to Layout Abstraction

**Before** (hard-coded):
```go
org := "cheddarwhizzy"
repo := "kubernetes-manifests"
namespace := pathParts[2]
cluster := "in-cluster"
```

**After** (layout abstraction):
```go
layoutConfig := config.GetLayoutConfigForRepo(repo)
resolver, _ := layout.NewResolver(layoutConfig)
resolved, _ := resolver.Resolve(repo, path)
// resolved.Cluster, resolved.Namespace, etc.
```

## Adding New Layout Strategies

To add a new layout strategy:

1. **Define the strategy constant** in `types/layout.go`:
   ```go
   LayoutCustom LayoutStrategy = "custom"
   ```

2. **Create a resolver** in `layout/custom.go`:
   ```go
   type CustomResolver struct {
       config *types.LayoutConfig
   }
   
   func (r *CustomResolver) Resolve(repoName, repoPath string) (*types.ResolvedLayout, error) {
       // Implementation
   }
   ```

3. **Update the factory** in `layout/factory.go`:
   ```go
   case types.LayoutCustom:
       return NewCustomResolver(config), nil
   ```

4. **Add default config** in `config/defaults.go`:
   ```go
   func DefaultCustomLayout() *types.LayoutConfig {
       // Configuration
   }
   ```

5. **Update loader** in `config/loader.go` to detect the new pattern

## Troubleshooting

### Layout Resolution Fails

If layout resolution fails, check:
1. Repository name matches expected pattern
2. Path structure matches configured indices
3. All required path segments are present

### Wrong Cluster/Namespace Extracted

Verify:
1. Path structure indices are correct
2. Repository name pattern matches (for split-by-env)
3. Layout config is being loaded correctly

### ArgoCD Config Not Found

Ensure:
1. `argocd-config.yaml` exists in chart directory
2. Path to chart directory is correct
3. GitHub API has access to read the file

