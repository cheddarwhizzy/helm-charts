package layout

import (
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// Resolver interface for resolving repo paths into structured layout components
type Resolver interface {
	Resolve(repoName, repoPath string) (*types.ResolvedLayout, error)
}

