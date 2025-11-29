package types

// PluginInput represents the input from ArgoCD ApplicationSet
type PluginInput struct {
	Input struct {
		Parameters struct {
			// Standalone mode: discover repos by org
			Orgs []string `json:"orgs,omitempty"`
			// Matrix mode: receive repo info from scmProvider
			URL          string `json:"url,omitempty"`
			Repository   string `json:"repository,omitempty"`
			Organization string `json:"organization,omitempty"`
			// Path mode: receive path from git directory generator
			Path    string `json:"path,omitempty"`
			RepoURL string `json:"repoURL,omitempty"`
			// Common parameters
			Envs            []string `json:"envs"`
			IncludePatterns []string `json:"includePatterns,omitempty"`
			Branch          string   `json:"branch,omitempty"`
		} `json:"parameters"`
	} `json:"input"`
}

// ProjectInfo represents the project-info.yaml structure
type ProjectInfo struct {
	Name       string                `yaml:"name"`
	Deployment ProjectInfoDeployment `yaml:"deployment"`
}

type ProjectInfoDeployment struct {
	Namespace    string                       `yaml:"namespace"`
	Environments map[string]EnvironmentConfig `yaml:"environments"`
}

type EnvironmentConfig struct {
	Clusters []ClusterConfig `yaml:"clusters"`
}

type ClusterConfig struct {
	Name            string `yaml:"name"`
	DestinationName string `yaml:"destinationName"`
}

// Parameter represents a single ApplicationSet parameter
type Parameter struct {
	Organization         string                   `json:"organization"`
	Repository           string                   `json:"repository"`
	URL                  string                   `json:"url"`
	Branch               string                   `json:"branch"`
	Env                  string                   `json:"env"`
	ChartName            string                   `json:"chartName"`
	ChartPath            string                   `json:"chartPath"`
	Cluster              string                   `json:"cluster"`
	DestinationName      string                   `json:"destinationName"`
	Namespace            string                   `json:"namespace"`
	ValueFiles           []string                 `json:"valueFiles"`
	ApplicationName      string                   `json:"applicationName"`
	SyncOptions          []string                 `json:"syncOptions,omitempty"`
	SyncPolicy           *SyncPolicyConfig        `json:"syncPolicy,omitempty"`
	IgnoreDifferences    []IgnoreDifferenceConfig `json:"ignoreDifferences,omitempty"`
	RevisionHistoryLimit *int                     `json:"revisionHistoryLimit,omitempty"`
}

// PluginResponse represents the response from the plugin (ArgoCD format)
// Must wrap parameters in "output" object per ArgoCD plugin spec
type PluginResponse struct {
	Output struct {
		Parameters []Parameter `json:"parameters"`
	} `json:"output"`
}

// Config holds the plugin configuration
type Config struct {
	GitHubToken     string
	DefaultClusters []ClusterConfig
	DefaultBranch   string
}

