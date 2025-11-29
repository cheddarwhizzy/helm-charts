package layout

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// SplitByEnvResolver resolves paths for kubernetes-<env>-<cluster> split repo layout
// Path format: infra|apps/<namespace>/<chart>
type SplitByEnvResolver struct {
	config *types.LayoutConfig
}

// NewSplitByEnvResolver creates a new split-by-env resolver
func NewSplitByEnvResolver(config *types.LayoutConfig) *SplitByEnvResolver {
	return &SplitByEnvResolver{
		config: config,
	}
}

// Resolve parses a split repo path and extracts env/cluster from repo name
func (r *SplitByEnvResolver) Resolve(repoName, repoPath string) (*types.ResolvedLayout, error) {
	pathParts := strings.Split(repoPath, "/")
	if len(pathParts) < 3 {
		return nil, fmt.Errorf("split repo path must have at least 3 segments, got %d: %s", len(pathParts), repoPath)
	}

	resolved := &types.ResolvedLayout{}

	// Extract env and cluster from repo name using pattern
	if r.config.EnvResolver.FromRepoPattern != "" {
		pattern := regexp.MustCompile(r.config.EnvResolver.FromRepoPattern)
		matches := pattern.FindStringSubmatch(repoName)
		if len(matches) >= 3 {
			// matches[0] is full match, matches[1] is env, matches[2] is cluster
			resolved.Env = matches[1]
			resolved.Cluster = matches[2]
		} else {
			return nil, fmt.Errorf("failed to extract env/cluster from repo name %s using pattern %s", repoName, r.config.EnvResolver.FromRepoPattern)
		}
	}

	// Type: infra or apps (first path segment)
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

