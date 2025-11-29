# Plugin Layout Assumptions - Current Behavior Audit

This document captures the current behavior and hard-coded assumptions in the `cheddarwhizzy-scm-k8s-plugin` before refactoring to support flexible repo layouts.

## Overview

The plugin currently operates in three modes:
1. **Path Mode**: For kubernetes-manifests monorepo (git directory generator)
2. **Matrix Mode**: For business app repos (scmProvider + plugin generator)
3. **Standalone Mode**: For discovering repos by organization (plugin generator only)

## Path Mode (kubernetes-manifests monorepo)

### Current Path Format
```
<cluster-name>/infra|apps/<namespace>/<chart>/
```

Example: `cheddarwhizzy-prod/infra/cnpg/cloudnative-pg`

### Hard-coded Assumptions

#### Path Structure
- **Path segment 0**: Cluster name (e.g., "cheddarwhizzy-prod")
  - Currently **NOT USED** - cluster is hard-coded to "in-cluster"
  - Location: `main.go:300`
  
- **Path segment 1**: Type ("infra" or "apps")
  - Used to distinguish infrastructure vs application charts
  - Currently **NOT EXTRACTED** in path mode code
  
- **Path segment 2**: Namespace (e.g., "cnpg")
  - Extracted and used as the Kubernetes namespace
  - Location: `main.go:283` - `namespace = pathParts[2]`
  
- **Path segment 3**: Chart name (e.g., "cloudnative-pg")
  - Used as the chart identifier
  - Extracted via `path.basename` in ApplicationSet templates

#### Repository Information
- **Organization**: Hard-coded to `"cheddarwhizzy"`
  - Location: `main.go:272`
  
- **Repository**: Hard-coded to `"kubernetes-manifests"`
  - Location: `main.go:273`
  
- **RepoURL**: Constructed from hard-coded org/repo if not provided
  - Location: `main.go:274-277`

#### Cluster Configuration
- **Cluster**: Always set to `"in-cluster"`
  - Location: `main.go:300`
  
- **DestinationName**: Always set to `"in-cluster"`
  - Location: `main.go:301`

#### Namespace Resolution
- Extracted from `pathParts[2]` (third path segment)
- Falls back to `"default"` if path has fewer than 3 segments
- Location: `main.go:280-286`

### ApplicationSet Template Usage

#### Current Template (prod - FIXED)
```yaml
name: 'cheddarwhizzy-prod-infra-{{index (splitList "/" path) 2}}-{{path.basename}}'
namespace: '{{index (splitList "/" path) 2}}'
```

#### Template Bugs (staging/qa - NEEDS FIX)
```yaml
# staging/values.yaml:61,70,107
name: 'in-cluster-{{path[2]}}-{{path.basename}}'
namespace: '{{path[2]}}'

# qa/values.yaml:20,29,60,69
name: 'cheddarwhizzy-qa-infra-{{path[2]}}-{{path.basename}}'
namespace: '{{path[2]}}'
```

**Issue**: `{{path[2]}}` syntax is invalid in Go templates. Should be `{{index (splitList "/" path) 2}}`.

### argocd-config.yaml Location
- Expected at: `<path>/argocd-config.yaml`
- Example: `cheddarwhizzy-prod/infra/cnpg/cloudnative-pg/argocd-config.yaml`
- Location: `main.go:289` - `readArgoCDConfigAPI(ctx, client, org, repo, branch, params.Path)`

## Matrix Mode (business app repos)

### Current Path Format
```
deployment/k8s/<env>/<chart>/
```

Base charts at:
```
deployment/k8s/base/<chart>/
```

### Configuration Sources

#### project-info.yaml
Located at repository root. Structure:
```yaml
name: <app-name>
deployment:
  namespace: <default-namespace>  # Shared across all environments
  environments:
    <env>:
      clusters:
        - name: <cluster-name>
          destinationName: <argocd-destination>
```

#### Namespace Resolution
1. From `project-info.yaml` → `deployment.namespace`
2. Fallback: Repository name (without `.git` suffix)
3. Location: `main.go:329-332`

#### Cluster Resolution
1. From `project-info.yaml` → `deployment.environments.<env>.clusters`
2. Fallback: Default clusters from config (typically `[{name: "in-cluster", destinationName: "in-cluster"}]`)
3. Location: `main.go:346` - `getClustersForEnv(projectInfo, env)`

#### Environment Resolution
- From `params.Envs` array (provided by ApplicationSet)
- Used to construct path: `deployment/k8s/<env>/`
- Location: `main.go:336`

#### Chart Discovery
- Scans `deployment/k8s/<env>/` for directories
- Validates chart by checking for `values.yaml` in directory
- Location: `main.go:339` - `discoverCharts(ctx, client, org, repo, branch, envPath)`

#### Value File Layering
Order (later files override earlier):
1. `deployment/k8s/base/<chart>/values.yaml` (base defaults)
2. `deployment/k8s/<env>/<chart>/values.yaml` (env-specific)
3. `deployment/k8s/<env>/<chart>/image.yaml` (optional, Kargo defaults)
4. `deployment/k8s/<env>/<chart>/values-<cluster>.yaml` (optional, cluster-specific)
5. `deployment/k8s/<env>/<chart>/image-<cluster>.yaml` (optional, cluster-specific)

Location: `main.go:368-396`

### Application Name Generation
- Pattern: `repository-chartName-cluster`
- Truncated to 53 characters with MD5 hash suffix if needed
- Location: `main.go:398` - `generateApplicationName(repo, chart, cluster.Name)`

## Standalone Mode

### Discovery Process
1. Lists all repos in specified organizations
2. Filters repos that have `deployment/k8s/<env>/` paths for any requested env
3. For each matching repo, follows Matrix Mode logic

Location: `main.go:419-533`

## Current Issues & Limitations

### 1. Hard-coded Repository (Path Mode)
- **Issue**: Path mode assumes `cheddarwhizzy/kubernetes-manifests`
- **Impact**: Cannot use plugin with other monorepo repositories
- **Location**: `main.go:272-273`

### 2. Fixed Path Structure (Path Mode)
- **Issue**: Assumes `<cluster>/infra|apps/<namespace>/<chart>` structure
- **Impact**: Cannot support alternative layouts like `kubernetes-<env>-<cluster>/infra/...`
- **Location**: `main.go:280-286`

### 3. Hard-coded Cluster (Path Mode)
- **Issue**: Always uses "in-cluster", ignores path segment 0
- **Impact**: Cannot support multi-cluster deployments from monorepo
- **Location**: `main.go:300-301`

### 4. Template Syntax Bugs
- **Issue**: `{{path[2]}}` invalid syntax in staging/qa templates
- **Impact**: ApplicationSet generation may fail
- **Files**: 
  - `clusters/staging/cheddarwhizzy-staging/values.yaml:61,70,107`
  - `clusters/qa/cheddarwhizzy-qa/values.yaml:20,29,60,69`

### 5. No Layout Abstraction
- **Issue**: Path parsing logic is hard-coded, not configurable
- **Impact**: Cannot support multiple repo layout patterns without code changes
- **Location**: Throughout path mode generation logic

### 6. No Support for Split Repos
- **Issue**: Cannot handle `kubernetes-prod-cluster1`, `kubernetes-qa-cluster1` pattern
- **Impact**: Teams must use monorepo structure or business app structure
- **Location**: Path mode assumes monorepo structure

## argocd-config.yaml Support

### Current Implementation
- **Reading**: Implemented in `readArgoCDConfigAPI` (main.go:663-685)
- **Merging**: Basic merge into Parameter struct (main.go:305-308)
- **Location**: Chart directory (`<path>/argocd-config.yaml`)

### Supported Fields
- `syncOptions`: Array of sync option strings
- `syncPolicy`: Complete sync policy configuration
- `ignoreDifferences`: Array of ignore difference rules
- `revisionHistoryLimit`: Integer limit

### Current Limitations
- Only works in Path Mode
- Not integrated into Matrix Mode or Standalone Mode
- No merging logic for syncPolicy (simple assignment)

## ApplicationSet Integration

### Path Mode Integration
- Uses plugin generator in matrix with git directory generator
- Plugin receives `path` parameter from git generator
- Generates single parameter with ArgoCD config
- Location: `clusters/prod/cheddarwhizzy-prod/values.yaml:17-24`

### Matrix Mode Integration
- Uses plugin generator in matrix with scmProvider generator
- Plugin receives repo info from scmProvider
- Generates parameters for each (env, chart, cluster) combination
- Location: `clusters/prod/cheddarwhizzy-prod/values.yaml:125-159`

### templatePatch Usage
- Path mode: Uses plugin-generated `.syncOptions`, `.syncPolicy`, etc.
- Matrix mode: Currently does not use ArgoCD config (not implemented)
- Location: `clusters/prod/cheddarwhizzy-prod/values.yaml:47-150`

## Summary

The plugin currently has three distinct modes with different assumptions:

1. **Path Mode**: Hard-coded for `kubernetes-manifests` monorepo with fixed structure
2. **Matrix Mode**: Flexible for business apps using `project-info.yaml` and `deployment/k8s/` structure
3. **Standalone Mode**: Discovers repos and uses Matrix Mode logic

**Key Refactoring Needs**:
- Abstract path parsing into configurable layout resolvers
- Support multiple repo layout patterns (monorepo, split-by-env)
- Fix template syntax bugs in staging/qa
- Extend ArgoCD config support to all modes
- Remove hard-coded repository assumptions

---

## Phase 2: Layout Abstraction Design

### Design Overview

The layout abstraction allows the plugin to support multiple repository layout patterns without hard-coding path parsing logic. The design uses a strategy pattern with configurable resolvers.

### LayoutConfig Structure

The `LayoutConfig` type (defined in `types/layout.go`) provides:

- **Strategy**: Identifies the layout type (monorepo, split-by-env, business-app)
- **ClusterResolver**: Configures how to extract cluster name (from path index, repo pattern, or static value)
- **EnvResolver**: Configures how to extract environment (from repo pattern or path index)
- **PathStructure**: Defines which path segments contain type, namespace, and chart

### Resolver Interface

All layout resolvers implement the `Resolver` interface:

```go
type Resolver interface {
    Resolve(repoName, repoPath string) (*ResolvedLayout, error)
}
```

The `ResolvedLayout` contains:
- `Cluster`: Cluster name
- `Env`: Environment name (may be empty)
- `Type`: "infra" or "apps"
- `Namespace`: Kubernetes namespace
- `Chart`: Chart name

### Implementation Status

**Implemented**:
- ✅ LayoutConfig types and ResolvedLayout
- ✅ Resolver interface
- ✅ MonorepoResolver (for kubernetes-manifests)
- ✅ SplitByEnvResolver (for kubernetes-<env>-<cluster>)
- ✅ BusinessAppResolver (placeholder, uses project-info.yaml)
- ✅ Factory pattern for creating resolvers
- ✅ Default layout configs
- ✅ Automatic layout detection based on repo name patterns

**Integration**:
- ✅ Path mode uses layout resolvers
- ✅ Layout config automatically selected based on repo name
- ✅ Backward compatible with existing kubernetes-manifests monorepo

### Example: Monorepo Layout Resolution

**Input**:
- Repo: `kubernetes-manifests`
- Path: `cheddarwhizzy-prod/infra/cnpg/cloudnative-pg`

**Process**:
1. Detect layout: `GetLayoutConfigForRepo("kubernetes-manifests")` → `LayoutMonorepo`
2. Create resolver: `NewMonorepoResolver(config)`
3. Resolve: `resolver.Resolve("kubernetes-manifests", path)`

**Output**:
```go
ResolvedLayout{
    Cluster:   "in-cluster",  // From static config
    Env:       "",            // Not applicable for monorepo
    Type:      "infra",       // Path segment 1
    Namespace: "cnpg",        // Path segment 2
    Chart:     "cloudnative-pg", // Path segment 3
}
```

### Example: Split-by-Env Layout Resolution

**Input**:
- Repo: `kubernetes-prod-cluster1`
- Path: `infra/observability/kube-prometheus-stack`

**Process**:
1. Detect layout: `GetLayoutConfigForRepo("kubernetes-prod-cluster1")` → `LayoutSplitByEnv`
2. Create resolver: `NewSplitByEnvResolver(config)`
3. Resolve: `resolver.Resolve("kubernetes-prod-cluster1", path)`

**Output**:
```go
ResolvedLayout{
    Cluster:   "cluster1",    // From repo name pattern (group 2)
    Env:       "prod",        // From repo name pattern (group 1)
    Type:      "infra",       // Path segment 0
    Namespace: "observability", // Path segment 1
    Chart:     "kube-prometheus-stack", // Path segment 2
}
```

### Future Enhancements

1. **Per-repo layout config**: Read `layout-config.yaml` from repository root
2. **Plugin-level config**: Support layout config via ConfigMap or environment variables
3. **Custom resolvers**: Allow teams to define custom layout patterns
4. **Path validation**: Validate resolved layouts before generating parameters

