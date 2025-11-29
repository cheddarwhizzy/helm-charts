package main

import (
	"log"
	"net/http"
	"os"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/generator"
	ghclient "github.com/cheddarwhizzy/argocd-scm-k8s-plugin/github"
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/handler"
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/utils"
)

func main() {
	// Load configuration from environment
	config := &types.Config{
		GitHubToken:   os.Getenv("GITHUB_TOKEN"),
		DefaultBranch: utils.GetEnvOrDefault("DEFAULT_BRANCH", "main"),
		DefaultClusters: []types.ClusterConfig{
			{Name: "in-cluster", DestinationName: "in-cluster"},
		},
	}

	if config.GitHubToken == "" {
		log.Fatal("GITHUB_TOKEN environment variable is required")
	}
	log.Printf("GitHub token loaded (length: %d)", len(config.GitHubToken))

	// Create GitHub client
	githubClient := ghclient.NewClient(config.GitHubToken)

	// Create generator
	gen := generator.NewGenerator(config, githubClient)

	// Create handler
	h := handler.NewHandler(gen)

	// Health check endpoint
	http.HandleFunc("/healthz", h.HandleHealthz)

	// Plugin endpoints - ArgoCD may use different paths depending on version
	// Handle all known endpoint formats for compatibility
	http.HandleFunc("/v1/generator.getParams", h.HandleGenerate)
	http.HandleFunc("/api/v1/getparams.execute", h.HandleGenerate)
	http.HandleFunc("/generate", h.HandleGenerate) // Legacy endpoint for direct testing
	// Catch-all handler to log what path ArgoCD is actually calling
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Received request: %s %s", r.Method, r.URL.Path)
		if r.URL.Path == "/healthz" {
			h.HandleHealthz(w, r)
			return
		}
		// Try to handle as plugin request
		h.HandleGenerate(w, r)
	})

	port := utils.GetEnvOrDefault("PORT", "8080")
	log.Printf("Starting plugin server on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
