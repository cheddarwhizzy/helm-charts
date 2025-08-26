#!/bin/bash

# Test script to verify virtualservice template rendering

set -e

echo "🧪 Testing VirtualService template rendering..."

# Create a temporary values file for testing
cat > /tmp/test-values.yaml << EOF
services:
  - name: web
    type: ClusterIP
    ports:
      - name: http
        port: 8080

virtualservice:
  enabled: true
  host: "example.com"
  gateway: "mesh"
  port: 8080
  annotations:
    test.annotation: "value"
  routes:
    - name: default
      host: "app.example.com"
      port: 8080
      path: /
      corsPolicy:
        allowOrigins:
          - exact: "https://example.com"
        allowMethods:
          - GET
          - POST
        allowHeaders:
          - authorization
          - content-type
      retries:
        attempts: 3
        perTryTimeout: 2s
      timeout: 30s
  aliases:
    - "www.example.com"
EOF

echo "📋 Test values created"

# Test template rendering
echo "🔍 Rendering VirtualService template..."
helm template test charts/helm-base -f /tmp/test-values.yaml --debug

echo "✅ Template rendering test completed"

# Clean up
rm -f /tmp/test-values.yaml

echo "🎉 VirtualService template test passed!"
