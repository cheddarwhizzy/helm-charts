package utils

import (
	"crypto/md5"
	"fmt"
	"os"
	"strings"
)

// getEnvOrDefault returns environment variable value or default
func GetEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// generateApplicationName generates a safe Helm release name that:
// - Is <= 53 characters
// - Matches Helm's regex: ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$
// - Pattern: repository-chartName-cluster (env prefix not needed since environments are isolated)
func GenerateApplicationName(repository, chartName, cluster string) string {
	// Build name with pattern: repo-chart-cluster
	// Components separated by hyphens
	parts := []string{repository, chartName, cluster}

	// Calculate base length (hyphens between parts)
	baseLength := len(parts) - 1 // hyphens
	for _, part := range parts {
		baseLength += len(part)
	}

	// If name is already <= 53, use it as-is
	if baseLength <= 53 {
		name := strings.Join(parts, "-")
		name = strings.ToLower(name)
		name = strings.ReplaceAll(name, "_", "-")
		return name
	}

	// Need to truncate - reserve space for hash suffix (8 chars) and hyphen
	maxBaseLength := 44 // 53 - 9 (8 for hash + 1 hyphen)

	// Smart truncation: shorten repo and chart, keep cluster short
	truncatedParts := make([]string, len(parts))

	// Calculate how much space we have for repo + chart (keep cluster)
	fixedLength := len(cluster) + 2 // 2 hyphens
	availableForRepoChart := maxBaseLength - fixedLength

	// Ensure we have minimum space for repo and chart
	if availableForRepoChart < 10 {
		availableForRepoChart = 10
	}

	// Split available space between repo and chart (favor repo slightly)
	repoMaxLen := availableForRepoChart / 2
	chartMaxLen := availableForRepoChart - repoMaxLen

	truncatedParts[0] = TruncateString(repository, repoMaxLen)
	truncatedParts[1] = TruncateString(chartName, chartMaxLen)
	truncatedParts[2] = cluster

	// Build truncated name
	truncatedName := strings.Join(truncatedParts, "-")

	// If still too long, truncate cluster too
	if len(truncatedName) > maxBaseLength {
		clusterMaxLen := maxBaseLength - (len(truncatedName) - len(cluster)) - 1
		if clusterMaxLen > 0 {
			truncatedParts[2] = TruncateString(cluster, clusterMaxLen)
			truncatedName = strings.Join(truncatedParts, "-")
		}
	}

	// Generate hash suffix for uniqueness (8 chars of MD5)
	fullName := fmt.Sprintf("%s-%s-%s", repository, chartName, cluster)
	hash := md5.Sum([]byte(fullName))
	hashSuffix := fmt.Sprintf("%x", hash)[:8]

	// Combine truncated name with hash
	finalName := truncatedName + "-" + hashSuffix

	// Ensure final length is <= 53
	if len(finalName) > 53 {
		// Truncate to fit
		maxTruncatedLength := 53 - 9 // 9 for hash suffix and hyphen
		if maxTruncatedLength > 0 {
			finalName = truncatedName[:maxTruncatedLength] + "-" + hashSuffix
		} else {
			finalName = hashSuffix // Last resort: just use hash
		}
	}

	// Ensure it matches Helm regex: lowercase alphanumeric with hyphens
	finalName = strings.ToLower(finalName)
	finalName = strings.ReplaceAll(finalName, "_", "-")

	return finalName
}

// TruncateString truncates a string to maxLen, preserving the beginning
func TruncateString(s string, maxLen int) string {
	if maxLen <= 0 {
		return ""
	}
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen]
}

// ParseRepoURL extracts owner and repo name from a git URL
func ParseRepoURL(url string) (string, string, error) {
	// Handle git@github.com:owner/repo.git
	if strings.HasPrefix(url, "git@github.com:") {
		parts := strings.TrimPrefix(url, "git@github.com:")
		parts = strings.TrimSuffix(parts, ".git")
		split := strings.Split(parts, "/")
		if len(split) != 2 {
			return "", "", fmt.Errorf("invalid git URL format: %s", url)
		}
		return split[0], split[1], nil
	}

	// Handle https://github.com/owner/repo.git
	if strings.HasPrefix(url, "https://github.com/") {
		parts := strings.TrimPrefix(url, "https://github.com/")
		parts = strings.TrimSuffix(parts, ".git")
		split := strings.Split(parts, "/")
		if len(split) != 2 {
			return "", "", fmt.Errorf("invalid HTTPS URL format: %s", url)
		}
		return split[0], split[1], nil
	}

	return "", "", fmt.Errorf("unsupported URL format: %s", url)
}

