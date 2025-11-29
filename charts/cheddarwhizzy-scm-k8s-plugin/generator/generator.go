package generator

import (
	"context"
	"fmt"
	"log"
	"strings"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/config"
	ghclient "github.com/cheddarwhizzy/argocd-scm-k8s-plugin/github"
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/layout"
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/utils"
)

// Generator generates ApplicationSet parameters
type Generator struct {
	config      *types.Config
	github      *ghclient.Client
	layoutCache map[string]layout.Resolver // Cache resolvers per repo
}

// NewGenerator creates a new generator
func NewGenerator(cfg *types.Config, githubClient *ghclient.Client) *Generator {
	return &Generator{
		config:      cfg,
		github:      githubClient,
		layoutCache: make(map[string]layout.Resolver),
	}
}

// GenerateParameters generates parameters based on input
func (g *Generator) GenerateParameters(params struct {
	Orgs            []string `json:"orgs,omitempty"`
	URL             string   `json:"url,omitempty"`
	Repository      string   `json:"repository,omitempty"`
	Organization    string   `json:"organization,omitempty"`
	Path            string   `json:"path,omitempty"`
	RepoURL         string   `json:"repoURL,omitempty"`
	Envs            []string `json:"envs"`
	IncludePatterns []string `json:"includePatterns,omitempty"`
	Branch          string   `json:"branch,omitempty"`
}) ([]types.Parameter, error) {
	branch := params.Branch
	if branch == "" {
		branch = g.config.DefaultBranch
	}

	ctx := context.Background()

	// Determine mode: path mode (git directory generator), matrix mode (scmProvider), or standalone mode
	if params.Path != "" {
		// Path mode: process path from git directory generator
		return g.generatePathMode(ctx, params.Path, params.RepoURL, branch)
	} else if params.URL != "" && params.Repository != "" && params.Organization != "" {
		// Matrix mode: process the single repo provided by scmProvider
		return g.generateMatrixMode(ctx, params.URL, params.Repository, params.Organization, params.Envs, branch)
	} else if len(params.Orgs) > 0 {
		// Standalone mode: discover repos by organization
		return g.generateStandaloneMode(ctx, params.Orgs, params.Envs, branch)
	} else {
		return nil, fmt.Errorf("either 'orgs' (standalone mode) or 'url'+'repository'+'organization' (matrix mode) or 'path' (path mode) must be provided")
	}
}

// generatePathMode generates parameters for path mode (git directory generator)
func (g *Generator) generatePathMode(ctx context.Context, path, repoURL, branch string) ([]types.Parameter, error) {
	log.Printf("Path mode: processing path %s", path)

	// Parse repo URL to get org/repo
	var org, repo string
	var err error
	if repoURL != "" {
		org, repo, err = utils.ParseRepoURL(repoURL)
		if err != nil {
			return nil, fmt.Errorf("failed to parse repo URL: %w", err)
		}
	} else {
		// Default to kubernetes-manifests for backward compatibility
		org = "cheddarwhizzy"
		repo = "kubernetes-manifests"
		repoURL = fmt.Sprintf("git@github.com:%s/%s.git", org, repo)
	}

	// Get layout config and resolver for this repo
	layoutConfig := config.GetLayoutConfigForRepo(repo)
	resolver, err := g.getResolver(repo, layoutConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to get layout resolver: %w", err)
	}

	// Resolve layout from path
	resolved, err := resolver.Resolve(repo, path)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve layout: %w", err)
	}

	// Read argocd-config.yaml from chart directory
	argocdConfig, err := g.github.ReadArgoCDConfig(ctx, org, repo, branch, path)
	if err != nil {
		log.Printf("Warning: Failed to read argocd-config.yaml for %s: %v", path, err)
		// Continue with empty config
		argocdConfig = &types.ArgoCDConfig{}
	}

	// Determine destination name (use cluster name or default)
	destinationName := resolved.Cluster
	if destinationName == "" {
		destinationName = "in-cluster"
	}

	// Generate parameter with argocd config
	param := types.Parameter{
		Organization:         org,
		Repository:           repo,
		Cluster:              resolved.Cluster,
		DestinationName:      destinationName,
		URL:                  repoURL,
		Branch:               branch,
		Namespace:            resolved.Namespace,
		ChartName:            resolved.Chart,
		SyncOptions:          argocdConfig.SyncOptions,
		SyncPolicy:           argocdConfig.SyncPolicy,
		IgnoreDifferences:    argocdConfig.IgnoreDifferences,
		RevisionHistoryLimit: argocdConfig.RevisionHistoryLimit,
	}

	return []types.Parameter{param}, nil
}

// generateMatrixMode generates parameters for matrix mode (scmProvider + plugin)
func (g *Generator) generateMatrixMode(ctx context.Context, url, repository, organization string, envs []string, branch string) ([]types.Parameter, error) {
	log.Printf("Matrix mode: processing repo %s/%s from scmProvider", organization, repository)

	org := organization
	repo := repository
	repoURL := url

	// Read project-info.yaml using GitHub API
	projectInfo, err := g.github.ReadProjectInfo(ctx, org, repo, branch)
	if err != nil {
		log.Printf("Warning: Failed to read project-info.yaml for %s: %v", repoURL, err)
		// Continue with defaults
		projectInfo = &types.ProjectInfo{}
	}

	// Determine namespace
	namespace := projectInfo.Deployment.Namespace
	if namespace == "" {
		namespace = strings.TrimSuffix(repo, ".git")
	}

	var allParameters []types.Parameter

	// For each environment
	for _, env := range envs {
		envPath := fmt.Sprintf("deployment/k8s/%s", env)

		// Discover charts in this environment
		charts, err := g.github.DiscoverCharts(ctx, org, repo, branch, envPath)
		if err != nil {
			log.Printf("Warning: Failed to discover charts for %s/%s: %v", repoURL, envPath, err)
			continue
		}

		// Get clusters for this environment
		clusters := g.getClustersForEnv(projectInfo, env)

		// For each chart
		for _, chart := range charts {
			// ChartPath points to base chart (where Chart.yaml lives)
			chartPath := fmt.Sprintf("deployment/k8s/base/%s", chart)

			// Get directory listing once for this chart to check for optional files
			chartDirPath := fmt.Sprintf("%s/%s", envPath, chart)
			chartFiles, err := g.github.ListChartFiles(ctx, org, repo, branch, chartDirPath)
			if err != nil {
				log.Printf("Warning: Failed to list files in %s/%s: %v", repoURL, chartDirPath, err)
				chartFiles = make(map[string]bool)
			}

			// For each cluster
			for _, cluster := range clusters {
				valueFiles := g.buildValueFiles(env, chart, cluster.Name, chartFiles)

				applicationName := utils.GenerateApplicationName(repo, chart, cluster.Name)

				param := types.Parameter{
					Organization:    org,
					Repository:      repo,
					URL:             repoURL,
					Branch:          branch,
					Env:             env,
					ChartName:       chart,
					ChartPath:       chartPath,
					Cluster:         cluster.Name,
					DestinationName: cluster.DestinationName,
					Namespace:       namespace,
					ValueFiles:      valueFiles,
					ApplicationName: applicationName,
				}

				allParameters = append(allParameters, param)
			}
		}
	}

	return allParameters, nil
}

// generateStandaloneMode generates parameters for standalone mode (discover repos by org)
func (g *Generator) generateStandaloneMode(ctx context.Context, orgs, envs []string, branch string) ([]types.Parameter, error) {
	log.Printf("Standalone mode: discovering repos for orgs: %v", orgs)

	var allParameters []types.Parameter

	// For each organization
	for _, org := range orgs {
		// Discover repositories using GitHub API
		repos, err := g.github.DiscoverRepos(ctx, org, envs, g.config.DefaultBranch)
		if err != nil {
			log.Printf("Warning: Failed to discover repos for org %s: %v", org, err)
			continue
		}

		// For each repository
		for _, repo := range repos {
			repoURL := fmt.Sprintf("git@github.com:%s/%s.git", org, repo)

			// Read project-info.yaml using GitHub API
			projectInfo, err := g.github.ReadProjectInfo(ctx, org, repo, branch)
			if err != nil {
				log.Printf("Warning: Failed to read project-info.yaml for %s: %v", repoURL, err)
				projectInfo = &types.ProjectInfo{}
			}

			// Determine namespace
			namespace := projectInfo.Deployment.Namespace
			if namespace == "" {
				namespace = strings.TrimSuffix(repo, ".git")
			}

			// For each environment
			for _, env := range envs {
				envPath := fmt.Sprintf("deployment/k8s/%s", env)

				// Discover charts in this environment
				charts, err := g.github.DiscoverCharts(ctx, org, repo, branch, envPath)
				if err != nil {
					log.Printf("Warning: Failed to discover charts for %s/%s: %v", repoURL, envPath, err)
					continue
				}

				// Get clusters for this environment
				clusters := g.getClustersForEnv(projectInfo, env)

				// For each chart
				for _, chart := range charts {
					chartPath := fmt.Sprintf("deployment/k8s/base/%s", chart)

					chartDirPath := fmt.Sprintf("%s/%s", envPath, chart)
					chartFiles, err := g.github.ListChartFiles(ctx, org, repo, branch, chartDirPath)
					if err != nil {
						log.Printf("Warning: Failed to list files in %s/%s: %v", repoURL, chartDirPath, err)
						chartFiles = make(map[string]bool)
					}

					// For each cluster
					for _, cluster := range clusters {
						valueFiles := g.buildValueFiles(env, chart, cluster.Name, chartFiles)

						param := types.Parameter{
							Organization:    org,
							Repository:      repo,
							URL:             repoURL,
							Branch:          branch,
							Env:             env,
							ChartName:       chart,
							ChartPath:       chartPath,
							Cluster:         cluster.Name,
							DestinationName: cluster.DestinationName,
							Namespace:       namespace,
							ValueFiles:      valueFiles,
						}

						allParameters = append(allParameters, param)
					}
				}
			}
		}
	}

	return allParameters, nil
}

// buildValueFiles builds the ordered list of value files
func (g *Generator) buildValueFiles(env, chart, clusterName string, chartFiles map[string]bool) []string {
	valueFiles := []string{}

	// 1. Base chart values
	valueFiles = append(valueFiles, "values.yaml")

	// 2. Env-specific values
	envValuesPath := fmt.Sprintf("../../%s/%s/values.yaml", env, chart)
	valueFiles = append(valueFiles, envValuesPath)

	// 3. Env-specific image.yaml (optional)
	if chartFiles["image.yaml"] {
		envImagePath := fmt.Sprintf("../../%s/%s/image.yaml", env, chart)
		valueFiles = append(valueFiles, envImagePath)
	}

	// 4. Cluster-specific values override (optional)
	clusterValuesFile := fmt.Sprintf("values-%s.yaml", clusterName)
	if chartFiles[clusterValuesFile] {
		clusterValuesPath := fmt.Sprintf("../../%s/%s/%s", env, chart, clusterValuesFile)
		valueFiles = append(valueFiles, clusterValuesPath)
	}

	// 5. Cluster-specific image.yaml override (optional)
	clusterImageFile := fmt.Sprintf("image-%s.yaml", clusterName)
	if chartFiles[clusterImageFile] {
		clusterImagePath := fmt.Sprintf("../../%s/%s/%s", env, chart, clusterImageFile)
		valueFiles = append(valueFiles, clusterImagePath)
	}

	return valueFiles
}

// getClustersForEnv returns clusters for an environment, with fallback to defaults
func (g *Generator) getClustersForEnv(projectInfo *types.ProjectInfo, env string) []types.ClusterConfig {
	if projectInfo.Deployment.Environments == nil {
		return g.config.DefaultClusters
	}

	envConfig, exists := projectInfo.Deployment.Environments[env]
	if !exists || len(envConfig.Clusters) == 0 {
		return g.config.DefaultClusters
	}

	return envConfig.Clusters
}

// getResolver gets or creates a resolver for a repo
func (g *Generator) getResolver(repoName string, layoutConfig *types.LayoutConfig) (layout.Resolver, error) {
	if resolver, exists := g.layoutCache[repoName]; exists {
		return resolver, nil
	}

	resolver, err := layout.NewResolver(layoutConfig)
	if err != nil {
		return nil, err
	}

	g.layoutCache[repoName] = resolver
	return resolver, nil
}

