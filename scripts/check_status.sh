#!/bin/bash

# Magma Status Check Script
# This script checks the status of deployed Magma components

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_docker_services() {
    print_header "DOCKER SERVICES STATUS"
    
    # Check if Docker is running
    if ! systemctl is-active --quiet docker; then
        print_error "Docker service is not running"
        return 1
    fi
    
    print_success "Docker service is running"
    
    # Check for Magma containers
    containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -i magma || true)
    
    if [[ -n "$containers" ]]; then
        print_info "Running Magma containers:"
        echo "$containers"
    else
        print_warning "No Magma containers found"
    fi
}

check_kubernetes_services() {
    print_header "KUBERNETES SERVICES STATUS"
    
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        print_warning "kubectl not found"
        return 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    print_success "Kubernetes cluster is accessible"
    
    # Check for Magma namespace
    if kubectl get namespace magma >/dev/null 2>&1; then
        print_success "Magma namespace exists"
        
        # Check pods in magma namespace
        pods=$(kubectl get pods -n magma --no-headers 2>/dev/null | wc -l)
        if [[ $pods -gt 0 ]]; then
            print_info "Magma pods status:"
            kubectl get pods -n magma
        else
            print_warning "No pods found in magma namespace"
        fi
    else
        print_warning "Magma namespace not found"
    fi
}

check_network_connectivity() {
    print_header "NETWORK CONNECTIVITY CHECK"
    
    # Check internet connectivity
    if ping -c 1 google.com >/dev/null 2>&1; then
        print_success "Internet connectivity is available"
    else
        print_error "No internet connectivity"
    fi
    
    # Check Docker Hub connectivity
    if curl -s --connect-timeout 5 https://hub.docker.com >/dev/null 2>&1; then
        print_success "Docker Hub is accessible"
    else
        print_warning "Docker Hub may not be accessible"
    fi
    
    # Check GitHub connectivity
    if curl -s --connect-timeout 5 https://github.com >/dev/null 2>&1; then
        print_success "GitHub is accessible"
    else
        print_warning "GitHub may not be accessible"
    fi
}

check_system_resources() {
    print_header "SYSTEM RESOURCES CHECK"
    
    # Check memory
    total_mem=$(free -m | awk 'NR==2{print $2}')
    available_mem=$(free -m | awk 'NR==2{print $7}')
    
    if [[ $total_mem -ge 8192 ]]; then
        print_success "Total memory: ${total_mem}MB (sufficient for Magma)"
    else
        print_warning "Total memory: ${total_mem}MB (minimum 8GB recommended)"
    fi
    
    if [[ $available_mem -ge 4096 ]]; then
        print_success "Available memory: ${available_mem}MB (sufficient)"
    else
        print_warning "Available memory: ${available_mem}MB (may be low)"
    fi
    
    # Check CPU
    cpu_cores=$(nproc)
    if [[ $cpu_cores -ge 4 ]]; then
        print_success "CPU cores: $cpu_cores (sufficient)"
    else
        print_warning "CPU cores: $cpu_cores (minimum 4 recommended)"
    fi
    
    # Check disk space
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    available_space=$(df -h / | awk 'NR==2 {print $4}')
    
    if [[ $disk_usage -lt 80 ]]; then
        print_success "Disk usage: ${disk_usage}% (${available_space} available)"
    else
        print_warning "Disk usage: ${disk_usage}% (${available_space} available - may be low)"
    fi
}

check_log_files() {
    print_header "LOG FILES CHECK"
    
    # Check for deployment logs
    if [[ -f "magma_deploy.log" ]]; then
        log_size=$(du -h magma_deploy.log | cut -f1)
        print_info "Python deployment log: magma_deploy.log (${log_size})"
        
        # Check for recent errors
        error_count=$(grep -c "ERROR" magma_deploy.log 2>/dev/null || echo "0")
        if [[ $error_count -gt 0 ]]; then
            print_warning "Found $error_count errors in deployment log"
        else
            print_success "No errors found in deployment log"
        fi
    else
        print_info "No Python deployment log found"
    fi
    
    if [[ -f "magma_deploy_bash.log" ]]; then
        log_size=$(du -h magma_deploy_bash.log | cut -f1)
        print_info "Bash deployment log: magma_deploy_bash.log (${log_size})"
    else
        print_info "No Bash deployment log found"
    fi
}

check_configuration() {
    print_header "CONFIGURATION CHECK"
    
    # Check for configuration files
    if [[ -f "config/magma_config.env" ]]; then
        print_success "Configuration file found: config/magma_config.env"
    else
        print_warning "No configuration file found"
    fi
    
    if [[ -f "config/deployment_config.yaml" ]]; then
        print_success "Deployment configuration found: config/deployment_config.yaml"
    else
        print_info "No deployment configuration found"
    fi
    
    # Check templates
    template_count=$(find templates -name "*.yml" 2>/dev/null | wc -l)
    if [[ $template_count -gt 0 ]]; then
        print_success "Found $template_count deployment templates"
    else
        print_warning "No deployment templates found"
    fi
}

main() {
    print_header "MAGMA DEPLOYMENT STATUS CHECK"
    
    echo "Checking Magma deployment status..."
    echo
    
    # Run all checks
    check_system_resources
    echo
    check_network_connectivity
    echo
    check_docker_services
    echo
    check_kubernetes_services
    echo
    check_configuration
    echo
    check_log_files
    
    echo
    print_info "Status check completed"
    print_info "For detailed logs, check: magma_deploy.log or magma_deploy_bash.log"
}

# Run main function
main "$@"