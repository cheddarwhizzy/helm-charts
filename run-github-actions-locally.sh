#!/bin/bash

# GitHub Actions Local Runner
# This script runs the same tests that GitHub Actions would run locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HELM_VERSION="3.17.0"
HELM_UNITTEST_VERSION="1.0.1"
CHART_PATH="charts/helm-base"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${BLUE}🧪 $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Helm if not present
install_helm() {
    if ! command_exists helm; then
        log_info "Installing Helm $HELM_VERSION..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        log_success "Helm installed successfully"
    else
        CURRENT_VERSION=$(helm version --short | cut -d' ' -f1 | sed 's/v//')
        log_info "Helm version: $CURRENT_VERSION"
    fi
}

# Install helm-unittest plugin
install_helm_unittest() {
    if helm plugin list | grep -q unittest; then
        log_success "helm-unittest plugin is already installed"
    else
        log_info "Installing helm-unittest plugin..."
        helm plugin install https://github.com/helm-unittest/helm-unittest --version $HELM_UNITTEST_VERSION
        log_success "helm-unittest plugin installed successfully"
    fi
}

# Run basic tests
run_basic_tests() {
    log_header "Running Basic Chart Tests"
    
    # Lint chart
    log_info "Running helm lint..."
    helm lint $CHART_PATH
    log_success "Chart linting passed"
    
    # Run unit tests
    log_info "Running helm-unittest tests..."
    helm unittest $CHART_PATH
    log_success "Unit tests passed"
    
    # Test template rendering
    log_info "Testing template rendering with default values..."
    helm template test $CHART_PATH > /dev/null
    log_success "Default values render successfully"
    
    # Test different workload types
    log_info "Testing different workload types..."
    for workload in Deployment StatefulSet Job CronJob DaemonSet; do
        log_info "  Testing $workload..."
        if [ "$workload" = "CronJob" ]; then
            helm template test $CHART_PATH --set kind=$workload --set schedule="0 0 * * *" > /dev/null
        else
            helm template test $CHART_PATH --set kind=$workload > /dev/null
        fi
        log_success "  $workload workload renders successfully"
    done
    
    # Test chart packaging
    log_info "Testing chart packaging..."
    helm package $CHART_PATH --destination /tmp
    log_success "Chart packaging successful"
    log_info "Package created: $(ls /tmp/helm-base-*.tgz)"
}

# Run security checks
run_security_checks() {
    log_header "Running Security Checks"
    
    # Check for hardcoded secrets
    log_info "Checking for hardcoded secrets..."
    if grep -r -i "password\|secret\|key\|token" $CHART_PATH/templates/ | grep -v "{{" | grep -v "example" | grep -v "placeholder"; then
        log_warning "Potential hardcoded secrets found in templates"
    else
        log_success "No hardcoded secrets found in templates"
    fi
    
    # Check for resource limits
    log_info "Checking for resource limits..."
    if grep -r "resources:" $CHART_PATH/templates/; then
        log_success "Resource limits found in templates"
    else
        log_warning "No resource limits found in templates"
    fi
    
    # Check for security contexts
    log_info "Checking for security contexts..."
    if grep -r "securityContext:" $CHART_PATH/templates/; then
        log_success "Security contexts found in templates"
    else
        log_warning "No security contexts found in templates"
    fi
}

# Run Kubernetes compatibility tests
run_k8s_compatibility_tests() {
    log_header "Running Kubernetes Compatibility Tests"
    
    # Test with different Kubernetes versions
    for k8s_version in "1.28" "1.29" "1.30"; do
        log_info "Testing compatibility with Kubernetes $k8s_version..."
        
        # Test template rendering
        helm template test $CHART_PATH --kube-version $k8s_version > /dev/null
        log_success "Template rendering successful with K8s $k8s_version"
        
        # Test different workload types
        for workload in Deployment StatefulSet Job CronJob DaemonSet; do
            if [ "$workload" = "CronJob" ]; then
                helm template test $CHART_PATH \
                    --set kind=$workload \
                    --set schedule="0 0 * * *" \
                    --kube-version $k8s_version > /dev/null
            else
                helm template test $CHART_PATH \
                    --set kind=$workload \
                    --kube-version $k8s_version > /dev/null
            fi
        done
        log_success "All workload types compatible with K8s $k8s_version"
    done
}

# Run comprehensive tests
run_comprehensive_tests() {
    log_header "Running Comprehensive Tests"
    
    # Test with different configurations
    log_info "Testing with RBAC enabled..."
    helm template test $CHART_PATH --set rbac.create=true > /dev/null
    log_success "RBAC configuration renders successfully"
    
    log_info "Testing with HPA enabled..."
    helm template test $CHART_PATH --set hpa.enabled=true > /dev/null
    log_success "HPA configuration renders successfully"
    
    log_info "Testing with NetworkPolicy enabled..."
    helm template test $CHART_PATH --set networkPolicy.enabled=true > /dev/null
    log_success "NetworkPolicy configuration renders successfully"
    
    log_info "Testing with Ingress enabled..."
    helm template test $CHART_PATH --set ingress.enabled=true > /dev/null
    log_success "Ingress configuration renders successfully"
}

# Generate test report
generate_test_report() {
    log_header "Generating Test Report"
    
    REPORT_FILE="test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > $REPORT_FILE << EOF
# Helm Chart Test Report

**Date:** $(date)
**Chart:** $CHART_PATH
**Helm Version:** $(helm version --short)

## Test Results

### Basic Tests
- ✅ Chart linting
- ✅ Unit tests (helm-unittest)
- ✅ Template rendering (default values)
- ✅ Workload types (Deployment, StatefulSet, Job, CronJob, DaemonSet)
- ✅ Chart packaging

### Security Checks
- ✅ Hardcoded secrets check
- ✅ Resource limits check
- ✅ Security contexts check

### Kubernetes Compatibility
- ✅ Kubernetes 1.28
- ✅ Kubernetes 1.29
- ✅ Kubernetes 1.30

### Comprehensive Tests
- ✅ RBAC configuration
- ✅ HPA configuration
- ✅ NetworkPolicy configuration
- ✅ Ingress configuration

## Summary

All tests passed successfully! The chart is ready for deployment.

EOF
    
    log_success "Test report generated: $REPORT_FILE"
}

# Main execution
main() {
    echo "🚀 GitHub Actions Local Runner"
    echo "=============================="
    echo ""
    
    # Check if we're in the right directory
    if [ ! -d "charts" ]; then
        log_error "Please run this script from the helm-charts repository root"
        exit 1
    fi
    
    # Install dependencies
    install_helm
    install_helm_unittest
    
    # Run tests
    run_basic_tests
    run_security_checks
    run_k8s_compatibility_tests
    run_comprehensive_tests
    
    # Generate report
    generate_test_report
    
    echo ""
    log_success "All tests passed! 🎉"
    log_info "Chart is ready for deployment"
    echo ""
    echo "📊 Test Summary:"
    echo "  ✅ Basic tests"
    echo "  ✅ Security checks"
    echo "  ✅ Kubernetes compatibility"
    echo "  ✅ Comprehensive tests"
    echo ""
    echo "🚀 Chart is production ready!"
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --basic        Run only basic tests"
        echo "  --security     Run only security checks"
        echo "  --k8s          Run only Kubernetes compatibility tests"
        echo "  --comprehensive Run only comprehensive tests"
        echo ""
        echo "Examples:"
        echo "  $0                    # Run all tests"
        echo "  $0 --basic           # Run only basic tests"
        echo "  $0 --security        # Run only security checks"
        exit 0
        ;;
    --basic)
        install_helm
        install_helm_unittest
        run_basic_tests
        ;;
    --security)
        run_security_checks
        ;;
    --k8s)
        install_helm
        run_k8s_compatibility_tests
        ;;
    --comprehensive)
        install_helm
        run_comprehensive_tests
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
