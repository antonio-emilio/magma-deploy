#!/bin/bash

# Magma Deployment Launcher
# This script provides a simple menu to choose deployment method

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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

main() {
    print_header "MAGMA DEPLOYMENT LAUNCHER"
    
    echo "Choose your deployment method:"
    echo
    echo "1. Python Interactive Deployment (Recommended)"
    echo "   - Full feature set with comprehensive validation"
    echo "   - Better error handling and logging"
    echo "   - Configuration management"
    echo
    echo "2. Bash Script Deployment"
    echo "   - Lightweight and fast"
    echo "   - Good for automation"
    echo "   - Shell-based configuration"
    echo
    echo "3. Configuration File Deployment"
    echo "   - Use pre-configured settings"
    echo "   - Non-interactive deployment"
    echo "   - Good for CI/CD pipelines"
    echo
    echo "4. Exit"
    echo
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            print_info "Starting Python interactive deployment..."
            if [[ -f "deploy_magma.py" ]]; then
                chmod +x deploy_magma.py
                ./deploy_magma.py
            else
                print_warning "deploy_magma.py not found!"
                exit 1
            fi
            ;;
        2)
            print_info "Starting Bash script deployment..."
            if [[ -f "deploy_magma.sh" ]]; then
                chmod +x deploy_magma.sh
                ./deploy_magma.sh
            else
                print_warning "deploy_magma.sh not found!"
                exit 1
            fi
            ;;
        3)
            print_info "Starting configuration file deployment..."
            if [[ -f "config/magma_config.env" ]]; then
                if [[ -f "deploy_magma.py" ]]; then
                    chmod +x deploy_magma.py
                    ./deploy_magma.py --config config/magma_config.env
                else
                    print_warning "deploy_magma.py not found!"
                    exit 1
                fi
            else
                print_warning "Configuration file not found!"
                print_info "Creating configuration file from template..."
                if [[ -f "config/magma_config.env.template" ]]; then
                    cp config/magma_config.env.template config/magma_config.env
                    print_success "Configuration template copied to config/magma_config.env"
                    print_info "Please edit config/magma_config.env and run this script again"
                else
                    print_warning "Configuration template not found!"
                    exit 1
                fi
            fi
            ;;
        4)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_warning "Invalid choice. Please try again."
            main
            ;;
    esac
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_warning "This script should not be run as root"
    print_info "Please run as a regular user with sudo privileges"
    exit 1
fi

# Run main function
main