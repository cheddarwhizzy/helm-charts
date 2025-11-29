package types

// ArgoCDConfig represents the argocd-config.yaml structure
type ArgoCDConfig struct {
	SyncPolicy           *SyncPolicyConfig        `yaml:"syncPolicy,omitempty"`
	SyncOptions          []string                 `yaml:"syncOptions,omitempty"`
	IgnoreDifferences    []IgnoreDifferenceConfig `yaml:"ignoreDifferences,omitempty"`
	RevisionHistoryLimit *int                     `yaml:"revisionHistoryLimit,omitempty"`
}

type SyncPolicyConfig struct {
	Automated                *AutomatedConfig                `yaml:"automated,omitempty"`
	Retry                    *RetryConfig                    `yaml:"retry,omitempty"`
	ManagedNamespaceMetadata *ManagedNamespaceMetadataConfig `yaml:"managedNamespaceMetadata,omitempty"`
}

type AutomatedConfig struct {
	Prune      *bool `yaml:"prune,omitempty"`
	SelfHeal   *bool `yaml:"selfHeal,omitempty"`
	AllowEmpty *bool `yaml:"allowEmpty,omitempty"`
}

type RetryConfig struct {
	Limit   int          `yaml:"limit"`
	Backoff BackoffConfig `yaml:"backoff"`
}

type BackoffConfig struct {
	Duration    string `yaml:"duration"`
	Factor      int    `yaml:"factor"`
	MaxDuration string `yaml:"maxDuration"`
}

type ManagedNamespaceMetadataConfig struct {
	Labels      map[string]string `yaml:"labels,omitempty"`
	Annotations map[string]string `yaml:"annotations,omitempty"`
}

type IgnoreDifferenceConfig struct {
	Group             string   `yaml:"group,omitempty"`
	Kind              string   `yaml:"kind,omitempty"`
	JSONPointers      []string `yaml:"jsonPointers,omitempty"`
	JQPathExpressions []string `yaml:"jqPathExpressions,omitempty"`
}

