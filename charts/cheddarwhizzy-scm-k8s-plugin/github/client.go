package github

import (
	"context"
	"fmt"
	"log"
	"strings"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
	"github.com/google/go-github/v57/github"
	"golang.org/x/oauth2"
	"gopkg.in/yaml.v3"
)

// Client wraps GitHub API client
type Client struct {
	client *github.Client
}

// NewClient creates a new GitHub client
func NewClient(token string) *Client {
	ctx := context.Background()
	ts := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: token},
	)
	tc := oauth2.NewClient(ctx, ts)
	return &Client{
		client: github.NewClient(tc),
	}
}

// ReadProjectInfo reads project-info.yaml from a repository
func (c *Client) ReadProjectInfo(ctx context.Context, owner, repo, branch string) (*types.ProjectInfo, error) {
	fileContent, _, _, err := c.client.Repositories.GetContents(ctx, owner, repo, "project-info.yaml", &github.RepositoryContentGetOptions{
		Ref: branch,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get project-info.yaml: %w", err)
	}

	// Decode base64 content
	content, err := fileContent.GetContent()
	if err != nil {
		return nil, fmt.Errorf("failed to decode file content: %w", err)
	}

	var projectInfo types.ProjectInfo
	if err := yaml.Unmarshal([]byte(content), &projectInfo); err != nil {
		return nil, fmt.Errorf("failed to parse project-info.yaml: %w", err)
	}

	return &projectInfo, nil
}

// ReadArgoCDConfig reads argocd-config.yaml from a chart directory
func (c *Client) ReadArgoCDConfig(ctx context.Context, owner, repo, branch, chartPath string) (*types.ArgoCDConfig, error) {
	configPath := fmt.Sprintf("%s/argocd-config.yaml", chartPath)
	fileContent, _, _, err := c.client.Repositories.GetContents(ctx, owner, repo, configPath, &github.RepositoryContentGetOptions{
		Ref: branch,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get argocd-config.yaml: %w", err)
	}

	// Decode base64 content
	content, err := fileContent.GetContent()
	if err != nil {
		return nil, fmt.Errorf("failed to decode file content: %w", err)
	}

	var argocdConfig types.ArgoCDConfig
	if err := yaml.Unmarshal([]byte(content), &argocdConfig); err != nil {
		return nil, fmt.Errorf("failed to parse argocd-config.yaml: %w", err)
	}

	return &argocdConfig, nil
}

// DiscoverCharts discovers chart directories in a given path
func (c *Client) DiscoverCharts(ctx context.Context, owner, repo, branch, envPath string) ([]string, error) {
	// List contents of the env path
	_, dirContents, _, err := c.client.Repositories.GetContents(ctx, owner, repo, envPath, &github.RepositoryContentGetOptions{
		Ref: branch,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get contents of %s: %w", envPath, err)
	}

	var charts []string
	for _, content := range dirContents {
		if content.Type != nil && *content.Type == "dir" && content.Name != nil {
			chartName := *content.Name
			if !strings.HasPrefix(chartName, ".") {
				// Check if it's a valid chart (has values.yaml - indicates env-specific override exists)
				chartPath := fmt.Sprintf("%s/%s", envPath, chartName)
				if c.hasValuesYaml(ctx, owner, repo, branch, chartPath) {
					charts = append(charts, chartName)
				}
			}
		}
	}

	return charts, nil
}

// ListChartFiles lists all files in a chart directory and returns a map of filename -> exists
func (c *Client) ListChartFiles(ctx context.Context, owner, repo, branch, chartDirPath string) (map[string]bool, error) {
	fileMap := make(map[string]bool)

	_, directoryContents, _, err := c.client.Repositories.GetContents(ctx, owner, repo, chartDirPath, &github.RepositoryContentGetOptions{
		Ref: branch,
	})
	if err != nil {
		// If the directory doesn't exist, return empty map
		return fileMap, nil
	}

	// Build map of filenames that exist
	if directoryContents != nil {
		for _, content := range directoryContents {
			if content.Type != nil && *content.Type == "file" && content.Name != nil {
				fileMap[*content.Name] = true
			}
		}
	}

	return fileMap, nil
}

// HasPath checks if a path exists in a repository
func (c *Client) HasPath(ctx context.Context, owner, repo, branch, path string) bool {
	fileContent, directoryContents, _, err := c.client.Repositories.GetContents(ctx, owner, repo, path, &github.RepositoryContentGetOptions{
		Ref: branch,
	})
	if err != nil {
		log.Printf("    Path check failed for %s/%s/%s: %v", owner, repo, path, err)
		return false
	}
	// If directoryContents is not nil, it means the path exists as a directory
	// If fileContent is not nil, it means the path exists as a file
	exists := directoryContents != nil || fileContent != nil
	log.Printf("    Path %s exists in %s/%s: %v (isDir: %v, isFile: %v)", path, owner, repo, exists, directoryContents != nil, fileContent != nil)
	return exists
}

// DiscoverRepos discovers repositories in an organization that have deployment/k8s/<env> paths
func (c *Client) DiscoverRepos(ctx context.Context, org string, envs []string, defaultBranch string) ([]string, error) {
	log.Printf("Discovering repos for org: %s, envs: %v", org, envs)

	var allRepos []string

	// List all repos in the organization
	opt := &github.RepositoryListByOrgOptions{
		Type:        "all",
		ListOptions: github.ListOptions{PerPage: 100},
	}

	for {
		repos, resp, err := c.client.Repositories.ListByOrg(ctx, org, opt)
		if err != nil {
			log.Printf("Error listing repos for org %s: %v", org, err)
			return nil, fmt.Errorf("failed to list repos for org %s: %w", org, err)
		}

		log.Printf("Found %d repos in org %s (page %d)", len(repos), org, opt.Page)

		for _, repo := range repos {
			if repo.Name == nil {
				continue
			}

			repoName := *repo.Name
			log.Printf("Checking repo: %s/%s", org, repoName)

			// Check if repo has any of the required env paths
			hasEnvPath := false
			for _, env := range envs {
				path := fmt.Sprintf("deployment/k8s/%s", env)
				exists := c.HasPath(ctx, org, repoName, defaultBranch, path)
				log.Printf("  Path %s exists: %v", path, exists)
				if exists {
					hasEnvPath = true
					break
				}
			}

			if hasEnvPath {
				log.Printf("  Adding repo: %s/%s", org, repoName)
				allRepos = append(allRepos, repoName)
			}
		}

		if resp.NextPage == 0 {
			break
		}
		opt.Page = resp.NextPage
	}

	log.Printf("Total repos found for org %s: %d", org, len(allRepos))
	return allRepos, nil
}

// hasValuesYaml checks if a directory contains values.yaml
func (c *Client) hasValuesYaml(ctx context.Context, owner, repo, branch, chartPath string) bool {
	valuesYaml := fmt.Sprintf("%s/values.yaml", chartPath)
	return c.HasPath(ctx, owner, repo, branch, valuesYaml)
}

