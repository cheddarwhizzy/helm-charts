package config

import (
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// DefaultMonorepoLayout returns the default layout config for kubernetes-manifests monorepo
func DefaultMonorepoLayout() *types.LayoutConfig {
	typeIndex := 1
	namespaceIndex := 2
	chartIndex := 3
	staticCluster := "in-cluster"

	return &types.LayoutConfig{
		Strategy: types.LayoutMonorepo,
		ClusterResolver: types.ClusterResolver{
			Static: &staticCluster, // Currently hard-coded to "in-cluster"
		},
		PathStructure: types.PathStructure{
			TypeIndex:      typeIndex,
			NamespaceIndex: namespaceIndex,
			ChartIndex:     chartIndex,
		},
	}
}

// DefaultSplitByEnvLayout returns the default layout config for kubernetes-<env>-<cluster> repos
func DefaultSplitByEnvLayout() *types.LayoutConfig {
	typeIndex := 0
	namespaceIndex := 1
	chartIndex := 2
	repoPattern := "kubernetes-(.+)-(.+)"

	return &types.LayoutConfig{
		Strategy: types.LayoutSplitByEnv,
		ClusterResolver: types.ClusterResolver{
			FromRepoPattern: &repoPattern, // Extract from repo name
		},
		EnvResolver: types.EnvResolver{
			FromRepoPattern: repoPattern, // Extract env from repo name
		},
		PathStructure: types.PathStructure{
			TypeIndex:      typeIndex,
			NamespaceIndex: namespaceIndex,
			ChartIndex:     chartIndex,
		},
	}
}

// DefaultBusinessAppLayout returns the default layout config for business app repos
func DefaultBusinessAppLayout() *types.LayoutConfig {
	// Business app layout doesn't use path-based resolution
	// It uses project-info.yaml and deployment/k8s/ structure
	return &types.LayoutConfig{
		Strategy: types.LayoutBusinessApp,
	}
}

