package layout

import (
	"fmt"
	"strings"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// MonorepoResolver resolves paths for kubernetes-manifests monorepo layout
// Path format: <cluster>/infra|apps/<namespace>/<chart>
type MonorepoResolver struct {
	config *types.LayoutConfig
}

// NewMonorepoResolver creates a new monorepo resolver
func NewMonorepoResolver(config *types.LayoutConfig) *MonorepoResolver {
	return &MonorepoResolver{
		config: config,
	}
}

// Resolve parses a monorepo path into structured components
func (r *MonorepoResolver) Resolve(repoName, repoPath string) (*types.ResolvedLayout, error) {
	pathParts := strings.Split(repoPath, "/")
	if len(pathParts) < 4 {
		return nil, fmt.Errorf("monorepo path must have at least 4 segments, got %d: %s", len(pathParts), repoPath)
	}

	resolved := &types.ResolvedLayout{}

	// Cluster: from static value or path index
	if r.config.ClusterResolver.Static != nil {
		resolved.Cluster = *r.config.ClusterResolver.Static
	} else if r.config.ClusterResolver.FromPathIndex != nil {
		idx := *r.config.ClusterResolver.FromPathIndex
		if idx < len(pathParts) {
			resolved.Cluster = pathParts[idx]
		}
	}

	// Type: infra or apps
	if r.config.PathStructure.TypeIndex < len(pathParts) {
		resolved.Type = pathParts[r.config.PathStructure.TypeIndex]
	}

	// Namespace
	if r.config.PathStructure.NamespaceIndex < len(pathParts) {
		resolved.Namespace = pathParts[r.config.PathStructure.NamespaceIndex]
	} else {
		resolved.Namespace = "default"
	}

	// Chart: last segment
	if r.config.PathStructure.ChartIndex < len(pathParts) {
		resolved.Chart = pathParts[r.config.PathStructure.ChartIndex]
	}

	return resolved, nil
}

