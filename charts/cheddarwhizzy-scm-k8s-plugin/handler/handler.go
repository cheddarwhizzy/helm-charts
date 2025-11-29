package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/generator"
	"github.com/cheddarwhizzy/argocd-scm-k8s-plugin/types"
)

// Handler handles HTTP requests
type Handler struct {
	generator *generator.Generator
}

// NewHandler creates a new handler
func NewHandler(gen *generator.Generator) *Handler {
	return &Handler{
		generator: gen,
	}
}

// HandleHealthz handles health check requests
func (h *Handler) HandleHealthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

// HandleGenerate handles parameter generation requests
func (h *Handler) HandleGenerate(w http.ResponseWriter, r *http.Request) {
	log.Printf("generateHandler called: %s %s", r.Method, r.URL.Path)

	if r.Method != http.MethodPost {
		log.Printf("Method not allowed: %s", r.Method)
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Log request body for debugging
	bodyBytes := make([]byte, 0)
	if r.Body != nil {
		var err error
		bodyBytes, err = io.ReadAll(r.Body)
		if err != nil {
			log.Printf("Error reading body: %v", err)
			http.Error(w, fmt.Sprintf("Failed to read request body: %v", err), http.StatusBadRequest)
			return
		}
		r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
		log.Printf("Request body: %s", string(bodyBytes))
	}

	var input types.PluginInput
	if err := json.NewDecoder(bytes.NewBuffer(bodyBytes)).Decode(&input); err != nil {
		log.Printf("Failed to decode request: %v", err)
		http.Error(w, fmt.Sprintf("Failed to decode request: %v", err), http.StatusBadRequest)
		return
	}

	// Generate parameters
	parameters, err := h.generator.GenerateParameters(input.Input.Parameters)
	if err != nil {
		log.Printf("Failed to generate parameters: %v", err)
		http.Error(w, fmt.Sprintf("Failed to generate parameters: %v", err), http.StatusInternalServerError)
		return
	}

	// ArgoCD expects response wrapped in "output" object
	response := types.PluginResponse{}
	response.Output.Parameters = parameters

	log.Printf("Generated %d parameter sets", len(parameters))

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Failed to encode response: %v", err)
		http.Error(w, fmt.Sprintf("Failed to encode response: %v", err), http.StatusInternalServerError)
		return
	}
}

