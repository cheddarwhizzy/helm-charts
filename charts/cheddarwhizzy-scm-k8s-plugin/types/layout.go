package types

// LayoutStrategy defines how to parse repo paths
type LayoutStrategy string

const (
	LayoutMonorepo      LayoutStrategy = "monorepo"      // kubernetes-manifests/<cluster>/infra|apps/...
	LayoutSplitByEnv    LayoutStrategy = "split-by-env"  // kubernetes-<env>-<cluster>/infra|apps/...
	LayoutBusinessApp   LayoutStrategy = "business-app"  // deployment/k8s/base|env/...
)

// LayoutConfig defines how to resolve cluster/env/namespace/chart from repo+path
type LayoutConfig struct {
	Strategy LayoutStrategy `yaml:"strategy"`

	// For monorepo: cluster is first path segment
	// For split-by-env: cluster extracted from repo name pattern
	ClusterResolver ClusterResolver `yaml:"clusterResolver,omitempty"`

	// Environment resolver (optional, for split-by-env)
	EnvResolver EnvResolver `yaml:"envResolver,omitempty"`

	// Path structure definition
	PathStructure PathStructure `yaml:"pathStructure"`
}

type ClusterResolver struct {
	// For monorepo: index in path (default: 0)
	FromPathIndex *int `yaml:"fromPathIndex,omitempty"`

	// For split repos: regex pattern to extract from repo name
	// e.g., "kubernetes-(.+)-(.+)" captures env and cluster
	FromRepoPattern *string `yaml:"fromRepoPattern,omitempty"`

	// Static value (fallback)
	Static *string `yaml:"static,omitempty"`
}

type EnvResolver struct {
	// Extract from repo name pattern
	FromRepoPattern string `yaml:"fromRepoPattern"`
	// Or from path index
	FromPathIndex *int `yaml:"fromPathIndex,omitempty"`
}

type PathStructure struct {
	// Index where "infra" or "apps" appears (default: 1 for monorepo)
	TypeIndex int `yaml:"typeIndex"`

	// Index where namespace appears (default: 2 for monorepo)
	NamespaceIndex int `yaml:"namespaceIndex"`

	// Index where chart name appears (default: 3 for monorepo)
	ChartIndex int `yaml:"chartIndex"`
}

// ResolvedLayout contains the parsed components
type ResolvedLayout struct {
	Cluster   string
	Env       string // may be empty
	Type      string // "infra" or "apps"
	Namespace string
	Chart     string
}

