package layout

import (
	"fmt"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// NewResolver creates a resolver based on the layout strategy
func NewResolver(config *types.LayoutConfig) (Resolver, error) {
	switch config.Strategy {
	case types.LayoutMonorepo:
		return NewMonorepoResolver(config), nil
	case types.LayoutSplitByEnv:
		return NewSplitByEnvResolver(config), nil
	case types.LayoutBusinessApp:
		return NewBusinessAppResolver(config), nil
	default:
		return nil, fmt.Errorf("unknown layout strategy: %s", config.Strategy)
	}
}

