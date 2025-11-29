package config

import (
	"regexp"
	"strings"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// GetLayoutConfigForRepo determines the appropriate layout config for a repository
// Uses pattern matching to detect repo type
func GetLayoutConfigForRepo(repoName string) *types.LayoutConfig {
	// Check for split-by-env pattern: kubernetes-<env>-<cluster>
	splitPattern := regexp.MustCompile(`^kubernetes-.+-.+$`)
	if splitPattern.MatchString(repoName) {
		return DefaultSplitByEnvLayout()
	}

	// Check for monorepo pattern: kubernetes-manifests
	if strings.HasPrefix(repoName, "kubernetes-manifests") || repoName == "kubernetes-manifests" {
		return DefaultMonorepoLayout()
	}

	// Default to business app layout for other repos
	return DefaultBusinessAppLayout()
}

