#!/bin/bash

# Helm Test Script using helm-unittest
# Comprehensive testing for helm-base chart

set -e

CHART_PATH="charts/helm-base"
RELEASE_NAME="test-release"

echo "🧪 Starting Helm Chart Testing with helm-unittest..."

# Function to print colored output
print_status() {
    echo -e "\033[1;32m✅ $1\033[0m"
}

print_error() {
    echo -e "\033[1;31m❌ $1\033[0m"
}

print_info() {
    echo -e "\033[1;34mℹ️  $1\033[0m"
}

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install Helm 3.x"
    exit 1
fi

print_info "Helm version: $(helm version --short)"

# Check if helm-unittest plugin is installed
if ! helm plugin list | grep -q "unittest"; then
    print_info "Installing helm-unittest plugin..."
    helm plugin install https://github.com/helm-unittest/helm-unittest.git
    if [ $? -ne 0 ]; then
        print_error "Failed to install helm-unittest plugin"
        exit 1
    fi
    print_status "helm-unittest plugin installed successfully"
else
    print_status "helm-unittest plugin is already installed"
fi

# 1. Lint the chart
print_info "Running helm lint..."
if helm lint "$CHART_PATH"; then
    print_status "Chart linting passed"
else
    print_error "Chart linting failed"
    exit 1
fi

# 2. Run helm-unittest tests
print_info "Running helm-unittest tests..."
if helm unittest "$CHART_PATH"; then
    print_status "All unit tests passed"
else
    print_error "Unit tests failed"
    exit 1
fi

# 3. Test template rendering with default values
print_info "Testing template rendering with default values..."
if helm template "$RELEASE_NAME" "$CHART_PATH" --dry-run > /tmp/default.yaml; then
    print_status "Default values render successfully"
else
    print_error "Default values rendering failed"
    exit 1
fi

# 4. Test with different workload types
print_info "Testing different workload types..."

workloads=("Deployment" "StatefulSet" "Job" "CronJob" "DaemonSet")
for workload in "${workloads[@]}"; do
    if helm template "$RELEASE_NAME" "$CHART_PATH" --set "kind=$workload" --dry-run > "/tmp/${workload,,}.yaml"; then
        print_status "$workload workload renders successfully"
    else
        print_error "$workload workload rendering failed"
        exit 1
    fi
done

# 5. Test with example values if they exist
if [ -f "$CHART_PATH/examples/node-app.yaml" ]; then
    print_info "Testing with example values..."
    if helm template "$RELEASE_NAME" "$CHART_PATH" -f "$CHART_PATH/examples/node-app.yaml" --dry-run > /tmp/example.yaml; then
        print_status "Example values render successfully"
    else
        print_error "Example values rendering failed"
        exit 1
    fi
fi

# 6. Test chart packaging
print_info "Testing chart packaging..."
if helm package "$CHART_PATH" --destination /tmp; then
    print_status "Chart packaging successful"
    PACKAGE_FILE=$(ls /tmp/helm-base-*.tgz | head -1)
    print_info "Package created: $PACKAGE_FILE"
else
    print_error "Chart packaging failed"
    exit 1
fi

# 7. Test chart installation (dry-run)
print_info "Testing chart installation (dry-run)..."
if helm install "$RELEASE_NAME" "$PACKAGE_FILE" --dry-run --debug; then
    print_status "Chart installation test passed"
else
    print_error "Chart installation test failed"
    exit 1
fi

# Cleanup
print_info "Cleaning up test files..."
rm -f /tmp/*.yaml /tmp/helm-base-*.tgz

print_status "All tests passed! 🎉"
print_info "Chart is ready for deployment"

# Summary
echo ""
echo "📊 Test Summary:"
echo "  ✅ Chart linting"
echo "  ✅ Unit tests (helm-unittest)"
echo "  ✅ Template rendering (default values)"
echo "  ✅ Workload types (Deployment, StatefulSet, Job, CronJob, DaemonSet)"
echo "  ✅ Example values"
echo "  ✅ Chart packaging"
echo "  ✅ Installation test"
echo ""
echo "🚀 Chart is production ready!"
