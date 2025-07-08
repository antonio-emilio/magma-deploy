#!/bin/bash

# Magma Cleanup Script
# This script removes Magma deployment components

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

confirm() {
    local prompt="$1"
    while true; do
        read -p "$prompt [y/N]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* | "" ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

cleanup_docker() {
    print_header "CLEANING UP DOCKER COMPONENTS"
    
    # Stop and remove Magma containers
    containers=$(docker ps -a --format "{{.Names}}" | grep -i magma || true)
    if [[ -n "$containers" ]]; then
        print_info "Stopping Magma containers..."
        echo "$containers" | xargs -r docker stop
        print_info "Removing Magma containers..."
        echo "$containers" | xargs -r docker rm
        print_success "Magma containers cleaned up"
    else
        print_info "No Magma containers found"
    fi
    
    # Remove Magma networks
    networks=$(docker network ls --format "{{.Name}}" | grep -i magma || true)
    if [[ -n "$networks" ]]; then
        print_info "Removing Magma networks..."
        echo "$networks" | xargs -r docker network rm
        print_success "Magma networks cleaned up"
    else
        print_info "No Magma networks found"
    fi
    
    # Remove Magma volumes
    volumes=$(docker volume ls --format "{{.Name}}" | grep -i magma || true)
    if [[ -n "$volumes" ]]; then
        print_info "Removing Magma volumes..."
        echo "$volumes" | xargs -r docker volume rm
        print_success "Magma volumes cleaned up"
    else
        print_info "No Magma volumes found"
    fi
    
    # Clean up temporary directories
    if [[ -d "/tmp/magma-orc8r" ]]; then
        rm -rf /tmp/magma-orc8r
        print_success "Orchestrator temp directory cleaned up"
    fi
    
    if [[ -d "/tmp/magma-agw" ]]; then
        rm -rf /tmp/magma-agw
        print_success "AGW temp directory cleaned up"
    fi
    
    if [[ -d "/tmp/magma-fgw" ]]; then
        rm -rf /tmp/magma-fgw
        print_success "FGW temp directory cleaned up"
    fi
    
    if [[ -d "/tmp/magma-certs" ]]; then
        rm -rf /tmp/magma-certs
        print_success "Certificate temp directory cleaned up"
    fi
}

cleanup_kubernetes() {
    print_header "CLEANING UP KUBERNETES COMPONENTS"
    
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        print_warning "kubectl not found, skipping Kubernetes cleanup"
        return 0
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_warning "Cannot connect to Kubernetes cluster, skipping cleanup"
        return 0
    fi
    
    # Remove Magma namespace and all resources
    if kubectl get namespace magma >/dev/null 2>&1; then
        print_info "Removing Magma namespace and all resources..."
        kubectl delete namespace magma
        print_success "Magma namespace and resources cleaned up"
    else
        print_info "Magma namespace not found"
    fi
    
    # Remove Helm releases
    if command -v helm >/dev/null 2>&1; then
        releases=$(helm list --all-namespaces --output json | jq -r '.[] | select(.name | contains("magma") or contains("orc8r") or contains("nms")) | .name' 2>/dev/null || true)
        if [[ -n "$releases" ]]; then
            print_info "Removing Helm releases..."
            echo "$releases" | xargs -r helm uninstall
            print_success "Helm releases cleaned up"
        else
            print_info "No Magma Helm releases found"
        fi
    fi
}

cleanup_configuration() {
    print_header "CLEANING UP CONFIGURATION FILES"
    
    # Remove generated configuration files
    if [[ -f "config/magma_config.env" ]]; then
        if confirm "Remove configuration file config/magma_config.env?"; then
            rm -f config/magma_config.env
            print_success "Configuration file removed"
        else
            print_info "Configuration file kept"
        fi
    fi
    
    if [[ -f "config/deployment_config.yaml" ]]; then
        if confirm "Remove deployment configuration config/deployment_config.yaml?"; then
            rm -f config/deployment_config.yaml
            print_success "Deployment configuration removed"
        else
            print_info "Deployment configuration kept"
        fi
    fi
    
    # Remove certificates
    if [[ -d "/opt/magma/certs" ]]; then
        if confirm "Remove certificates from /opt/magma/certs?"; then
            sudo rm -rf /opt/magma/certs
            print_success "Certificates removed"
        else
            print_info "Certificates kept"
        fi
    fi
}

cleanup_logs() {
    print_header "CLEANING UP LOG FILES"
    
    # Remove deployment logs
    if [[ -f "magma_deploy.log" ]]; then
        if confirm "Remove deployment log magma_deploy.log?"; then
            rm -f magma_deploy.log
            print_success "Python deployment log removed"
        else
            print_info "Python deployment log kept"
        fi
    fi
    
    if [[ -f "magma_deploy_bash.log" ]]; then
        if confirm "Remove deployment log magma_deploy_bash.log?"; then
            rm -f magma_deploy_bash.log
            print_success "Bash deployment log removed"
        else
            print_info "Bash deployment log kept"
        fi
    fi
}

cleanup_system() {
    print_header "CLEANING UP SYSTEM RESOURCES"
    
    # Remove Magma directories
    if [[ -d "/etc/magma" ]]; then
        if confirm "Remove system configuration directory /etc/magma?"; then
            sudo rm -rf /etc/magma
            print_success "System configuration directory removed"
        else
            print_info "System configuration directory kept"
        fi
    fi
    
    if [[ -d "/var/log/magma" ]]; then
        if confirm "Remove system log directory /var/log/magma?"; then
            sudo rm -rf /var/log/magma
            print_success "System log directory removed"
        else
            print_info "System log directory kept"
        fi
    fi
    
    # Clean up systemd services
    services=$(systemctl list-unit-files | grep -i magma | awk '{print $1}' || true)
    if [[ -n "$services" ]]; then
        print_info "Found Magma systemd services:"
        echo "$services"
        if confirm "Stop and disable Magma systemd services?"; then
            echo "$services" | xargs -r sudo systemctl stop
            echo "$services" | xargs -r sudo systemctl disable
            print_success "Magma systemd services stopped and disabled"
        else
            print_info "Magma systemd services kept"
        fi
    fi
}

main() {
    print_header "MAGMA DEPLOYMENT CLEANUP"
    
    print_warning "This script will remove Magma deployment components."
    print_warning "This action cannot be undone!"
    echo
    
    if ! confirm "Do you want to continue with cleanup?"; then
        print_info "Cleanup cancelled"
        exit 0
    fi
    
    echo
    print_info "Starting cleanup process..."
    echo
    
    # Run cleanup functions
    cleanup_docker
    echo
    cleanup_kubernetes
    echo
    cleanup_configuration
    echo
    cleanup_logs
    echo
    cleanup_system
    
    echo
    print_success "Cleanup completed!"
    print_info "Magma deployment components have been removed"
    
    # Final verification
    echo
    print_info "Verifying cleanup..."
    
    # Check for remaining containers
    remaining_containers=$(docker ps -a --format "{{.Names}}" | grep -i magma || true)
    if [[ -n "$remaining_containers" ]]; then
        print_warning "Some Magma containers may still exist: $remaining_containers"
    else
        print_success "No Magma containers found"
    fi
    
    # Check for remaining Kubernetes resources
    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        if kubectl get namespace magma >/dev/null 2>&1; then
            print_warning "Magma namespace still exists"
        else
            print_success "Magma namespace removed"
        fi
    fi
    
    print_info "Cleanup verification completed"
}

# Run main function
main "$@"