package layout

import (
	"fmt"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// BusinessAppResolver resolves paths for business app repos
// This resolver is a placeholder - business apps use project-info.yaml instead
type BusinessAppResolver struct {
	config *types.LayoutConfig
}

// NewBusinessAppResolver creates a new business app resolver
func NewBusinessAppResolver(config *types.LayoutConfig) *BusinessAppResolver {
	return &BusinessAppResolver{
		config: config,
	}
}

// Resolve is not used for business apps - they use project-info.yaml
// This is kept for interface compliance
func (r *BusinessAppResolver) Resolve(repoName, repoPath string) (*types.ResolvedLayout, error) {
	return nil, fmt.Errorf("business app resolver should not be used for path resolution - use project-info.yaml instead")
}

