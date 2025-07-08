#!/bin/bash

# Magma Deployment Script
# Simple bash-based deployment for Magma Core
# Author: Magma Deploy Tool
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="config/magma_config.env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Create directories
mkdir -p "$CONFIG_DIR" "$SCRIPTS_DIR"

# Logging
LOG_FILE="$SCRIPT_DIR/magma_deploy_bash.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Print functions
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

# Input functions
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " input
        input=${input:-$default}
    else
        read -p "$prompt: " input
        while [[ -z "$input" ]]; do
            echo "This field is required."
            read -p "$prompt: " input
        done
    fi
    
    eval "$var_name='$input'"
}

get_password() {
    local prompt="$1"
    local var_name="$2"
    
    read -s -p "$prompt: " input
    echo
    eval "$var_name='$input'"
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

# Validation functions
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Prerequisite checks
check_command() {
    local cmd=$1
    if command -v "$cmd" >/dev/null 2>&1; then
        print_success "$cmd is installed"
        return 0
    else
        print_error "$cmd is not installed"
        return 1
    fi
}

check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    local missing_deps=()
    
    # Check required commands
    for cmd in docker docker-compose kubectl helm git; do
        if ! check_command "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        if confirm "Do you want to install missing dependencies?"; then
            install_prerequisites "${missing_deps[@]}"
        else
            print_error "Please install missing dependencies and run again"
            exit 1
        fi
    else
        print_success "All prerequisites are available"
    fi
}

# Installation functions
install_prerequisites() {
    local deps=("$@")
    print_header "INSTALLING PREREQUISITES"
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            ubuntu|debian)
                install_ubuntu_deps "${deps[@]}"
                ;;
            centos|rhel|fedora)
                install_rhel_deps "${deps[@]}"
                ;;
            *)
                print_error "Unsupported OS: $ID"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

install_ubuntu_deps() {
    local deps=("$@")
    
    sudo apt-get update
    
    for dep in "${deps[@]}"; do
        case "$dep" in
            docker)
                install_docker_ubuntu
                ;;
            docker-compose)
                install_docker_compose
                ;;
            kubectl)
                install_kubectl
                ;;
            helm)
                install_helm
                ;;
            git)
                sudo apt-get install -y git
                ;;
        esac
    done
}

install_rhel_deps() {
    local deps=("$@")
    
    for dep in "${deps[@]}"; do
        case "$dep" in
            docker)
                install_docker_rhel
                ;;
            docker-compose)
                install_docker_compose
                ;;
            kubectl)
                install_kubectl
                ;;
            helm)
                install_helm
                ;;
            git)
                sudo yum install -y git
                ;;
        esac
    done
}

install_docker_ubuntu() {
    print_info "Installing Docker for Ubuntu/Debian"
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Install dependencies
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker "$USER"
    
    print_success "Docker installed successfully"
    print_warning "Please log out and log back in to use Docker without sudo"
}

install_docker_rhel() {
    print_info "Installing Docker for RHEL/CentOS"
    
    # Remove old versions
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    
    # Install dependencies
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    
    # Add repository
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker "$USER"
    
    print_success "Docker installed successfully"
    print_warning "Please log out and log back in to use Docker without sudo"
}

install_docker_compose() {
    print_info "Installing Docker Compose"
    
    # Download and install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Make it executable
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_success "Docker Compose installed successfully"
}

install_kubectl() {
    print_info "Installing kubectl"
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Clean up
    rm kubectl
    
    print_success "kubectl installed successfully"
}

install_helm() {
    print_info "Installing Helm"
    
    # Download and install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    print_success "Helm installed successfully"
}

# Configuration collection
collect_config() {
    print_header "DEPLOYMENT CONFIGURATION"
    
    # Create config file
    cat > "$CONFIG_FILE" << EOF
# Magma Deployment Configuration
# Generated on $(date)

EOF
    
    # Component selection
    echo "Select components to deploy:"
    echo "1. Full Magma Stack (Orchestrator + AGW + FGW + NMS)"
    echo "2. Orchestrator only"
    echo "3. Access Gateway only"
    echo "4. Federated Gateway only"
    echo "5. Custom selection"
    
    get_input "Enter your choice (1-5)" "1" "DEPLOYMENT_CHOICE"
    
    case "$DEPLOYMENT_CHOICE" in
        1)
            COMPONENTS="orchestrator agw fgw nms"
            ;;
        2)
            COMPONENTS="orchestrator"
            ;;
        3)
            COMPONENTS="agw"
            ;;
        4)
            COMPONENTS="fgw"
            ;;
        5)
            COMPONENTS=""
            for comp in orchestrator agw fgw nms; do
                if confirm "Deploy $comp?"; then
                    COMPONENTS="$COMPONENTS $comp"
                fi
            done
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    echo "COMPONENTS=\"$COMPONENTS\"" >> "$CONFIG_FILE"
    
    # General configuration
    get_input "Domain name" "magma.local" "DOMAIN"
    echo "DOMAIN=\"$DOMAIN\"" >> "$CONFIG_FILE"
    
    get_input "Admin email address" "" "ADMIN_EMAIL"
    while ! validate_email "$ADMIN_EMAIL"; do
        print_error "Invalid email format"
        get_input "Admin email address" "" "ADMIN_EMAIL"
    done
    echo "ADMIN_EMAIL=\"$ADMIN_EMAIL\"" >> "$CONFIG_FILE"
    
    # Network configuration
    print_info "Network Configuration"
    get_input "External IP address" "" "EXTERNAL_IP"
    while ! validate_ip "$EXTERNAL_IP"; do
        print_error "Invalid IP address format"
        get_input "External IP address" "" "EXTERNAL_IP"
    done
    echo "EXTERNAL_IP=\"$EXTERNAL_IP\"" >> "$CONFIG_FILE"
    
    # Component-specific configuration
    if [[ "$COMPONENTS" == *"orchestrator"* ]]; then
        collect_orchestrator_config
    fi
    
    if [[ "$COMPONENTS" == *"agw"* ]]; then
        collect_agw_config
    fi
    
    if [[ "$COMPONENTS" == *"fgw"* ]]; then
        collect_fgw_config
    fi
    
    print_success "Configuration saved to $CONFIG_FILE"
}

collect_orchestrator_config() {
    print_info "Orchestrator Configuration"
    
    get_input "Kubernetes namespace" "magma" "ORC8R_NAMESPACE"
    echo "ORC8R_NAMESPACE=\"$ORC8R_NAMESPACE\"" >> "$CONFIG_FILE"
    
    get_input "Storage class" "standard" "ORC8R_STORAGE_CLASS"
    echo "ORC8R_STORAGE_CLASS=\"$ORC8R_STORAGE_CLASS\"" >> "$CONFIG_FILE"
    
    get_input "Database host" "postgresql" "ORC8R_DB_HOST"
    echo "ORC8R_DB_HOST=\"$ORC8R_DB_HOST\"" >> "$CONFIG_FILE"
    
    get_input "Database port" "5432" "ORC8R_DB_PORT"
    echo "ORC8R_DB_PORT=\"$ORC8R_DB_PORT\"" >> "$CONFIG_FILE"
    
    get_input "Database user" "magma" "ORC8R_DB_USER"
    echo "ORC8R_DB_USER=\"$ORC8R_DB_USER\"" >> "$CONFIG_FILE"
    
    get_password "Database password" "ORC8R_DB_PASSWORD"
    echo "ORC8R_DB_PASSWORD=\"$ORC8R_DB_PASSWORD\"" >> "$CONFIG_FILE"
    
    get_input "Database name" "magma" "ORC8R_DB_NAME"
    echo "ORC8R_DB_NAME=\"$ORC8R_DB_NAME\"" >> "$CONFIG_FILE"
}

collect_agw_config() {
    print_info "Access Gateway Configuration"
    
    get_input "Network interface" "eth0" "AGW_INTERFACE"
    echo "AGW_INTERFACE=\"$AGW_INTERFACE\"" >> "$CONFIG_FILE"
    
    get_input "AGW IP address" "" "AGW_IP"
    while ! validate_ip "$AGW_IP"; do
        print_error "Invalid IP address format"
        get_input "AGW IP address" "" "AGW_IP"
    done
    echo "AGW_IP=\"$AGW_IP\"" >> "$CONFIG_FILE"
    
    get_input "Mobile Country Code (MCC)" "001" "AGW_MCC"
    echo "AGW_MCC=\"$AGW_MCC\"" >> "$CONFIG_FILE"
    
    get_input "Mobile Network Code (MNC)" "01" "AGW_MNC"
    echo "AGW_MNC=\"$AGW_MNC\"" >> "$CONFIG_FILE"
    
    get_input "Tracking Area Code (TAC)" "1" "AGW_TAC"
    echo "AGW_TAC=\"$AGW_TAC\"" >> "$CONFIG_FILE"
    
    get_input "S1AP IP address" "$AGW_IP" "AGW_S1AP_IP"
    echo "AGW_S1AP_IP=\"$AGW_S1AP_IP\"" >> "$CONFIG_FILE"
    
    get_input "S1AP port" "36412" "AGW_S1AP_PORT"
    echo "AGW_S1AP_PORT=\"$AGW_S1AP_PORT\"" >> "$CONFIG_FILE"
}

collect_fgw_config() {
    print_info "Federated Gateway Configuration"
    
    get_input "Federation ID" "fgw01" "FGW_FEDERATION_ID"
    echo "FGW_FEDERATION_ID=\"$FGW_FEDERATION_ID\"" >> "$CONFIG_FILE"
    
    get_input "Served network IDs (comma-separated)" "network1,network2" "FGW_SERVED_NETWORKS"
    echo "FGW_SERVED_NETWORKS=\"$FGW_SERVED_NETWORKS\"" >> "$CONFIG_FILE"
    
    get_input "Diameter host" "fgw.magma.local" "FGW_DIAMETER_HOST"
    echo "FGW_DIAMETER_HOST=\"$FGW_DIAMETER_HOST\"" >> "$CONFIG_FILE"
    
    get_input "Diameter realm" "magma.local" "FGW_DIAMETER_REALM"
    echo "FGW_DIAMETER_REALM=\"$FGW_DIAMETER_REALM\"" >> "$CONFIG_FILE"
    
    get_input "Diameter port" "3868" "FGW_DIAMETER_PORT"
    echo "FGW_DIAMETER_PORT=\"$FGW_DIAMETER_PORT\"" >> "$CONFIG_FILE"
}

# Deployment functions
deploy_components() {
    print_header "STARTING DEPLOYMENT"
    
    # Source configuration
    source "$CONFIG_FILE"
    
    for component in $COMPONENTS; do
        print_info "Deploying $component..."
        
        case "$component" in
            orchestrator)
                deploy_orchestrator
                ;;
            agw)
                deploy_agw
                ;;
            fgw)
                deploy_fgw
                ;;
            nms)
                deploy_nms
                ;;
            *)
                print_error "Unknown component: $component"
                ;;
        esac
        
        print_success "$component deployment completed"
    done
    
    print_success "All components deployed successfully!"
    display_summary
}

deploy_orchestrator() {
    print_info "Setting up Orchestrator..."
    
    # Create namespace
    kubectl create namespace "$ORC8R_NAMESPACE" || true
    
    # Add Helm repository
    helm repo add magma https://magma.github.io/magma/helm-charts
    helm repo update
    
    # Generate certificates if needed
    mkdir -p /tmp/magma-certs
    if [[ ! -f /tmp/magma-certs/tls.crt ]]; then
        print_info "Generating TLS certificates..."
        openssl req -x509 -newkey rsa:4096 -keyout /tmp/magma-certs/tls.key -out /tmp/magma-certs/tls.crt -days 365 -nodes -subj "/CN=$DOMAIN"
    fi
    
    # Deploy PostgreSQL
    print_info "Deploying PostgreSQL..."
    helm upgrade --install postgresql oci://registry-1.docker.io/bitnamicharts/postgresql \
        --namespace "$ORC8R_NAMESPACE" \
        --set auth.postgresPassword="$ORC8R_DB_PASSWORD" \
        --set auth.database="$ORC8R_DB_NAME" \
        --set auth.username="$ORC8R_DB_USER" \
        --set primary.persistence.storageClass="$ORC8R_STORAGE_CLASS"
    
    # Wait for PostgreSQL
    print_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n "$ORC8R_NAMESPACE" --timeout=300s
    
    # Deploy Orchestrator
    print_info "Deploying Orchestrator..."
    helm upgrade --install orc8r magma/orc8r \
        --namespace "$ORC8R_NAMESPACE" \
        --set global.domain="$DOMAIN" \
        --set postgresql.host="$ORC8R_DB_HOST" \
        --set postgresql.port="$ORC8R_DB_PORT" \
        --set postgresql.user="$ORC8R_DB_USER" \
        --set postgresql.password="$ORC8R_DB_PASSWORD" \
        --set postgresql.database="$ORC8R_DB_NAME" \
        --set-file tls.crt=/tmp/magma-certs/tls.crt \
        --set-file tls.key=/tmp/magma-certs/tls.key
}

deploy_agw() {
    print_info "Setting up Access Gateway..."
    
    # Create AGW configuration
    mkdir -p /tmp/magma-agw
    cat > /tmp/magma-agw/docker-compose.yml << EOF
version: '3.8'

services:
  magmad:
    image: magma/magmad:latest
    container_name: magmad
    privileged: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./configs:/etc/magma
    environment:
      - MAGMA_PRINT_GRPC_PAYLOAD=0
    
  mme:
    image: magma/mme:latest
    container_name: mme
    network_mode: host
    depends_on:
      - magmad
    volumes:
      - ./configs:/etc/magma
    environment:
      - MAGMA_PRINT_GRPC_PAYLOAD=0
    
  spgw:
    image: magma/spgw:latest
    container_name: spgw
    network_mode: host
    depends_on:
      - magmad
    volumes:
      - ./configs:/etc/magma
    environment:
      - MAGMA_PRINT_GRPC_PAYLOAD=0
    
  sessiond:
    image: magma/sessiond:latest
    container_name: sessiond
    network_mode: host
    depends_on:
      - magmad
    volumes:
      - ./configs:/etc/magma
    environment:
      - MAGMA_PRINT_GRPC_PAYLOAD=0
EOF
    
    # Create AGW configuration files
    mkdir -p /tmp/magma-agw/configs
    cat > /tmp/magma-agw/configs/gateway.mconfig << EOF
---
magmad_config:
  checkin_interval: 60
  checkin_timeout: 30
  autoupgrade_enabled: false
  autoupgrade_poll_interval: 300
  package_version: "0.0.0-0"
  images: []
  tier: "default"
  feature_flags: {}
  dynamic_services: []

mconfig:
  mme_config:
    mcc: "$AGW_MCC"
    mnc: "$AGW_MNC"
    tac: $AGW_TAC
    mme_code: 1
    mme_gid: 1
    enable_dns_caching: false
    non_eps_service_control: 0
    csfb_mcc: "$AGW_MCC"
    csfb_mnc: "$AGW_MNC"
    lac: 1
    s1ap_ip: "$AGW_S1AP_IP"
    s1ap_port: $AGW_S1AP_PORT
    
  spgw_config:
    enable_nat: true
    gtpu_endpoint: "$AGW_IP"
    
  mobility_config:
    ip_pool: "192.168.128.0/24"
    static_ip_enabled: false
    multi_apn_ip_alloc: false
    nat_enabled: true
    enable_static_ip_assignments: false
EOF
    
    # Deploy AGW
    cd /tmp/magma-agw
    docker-compose up -d
    
    print_success "Access Gateway deployed"
}

deploy_fgw() {
    print_info "Setting up Federated Gateway..."
    
    # Create FGW configuration
    mkdir -p /tmp/magma-fgw
    cat > /tmp/magma-fgw/docker-compose.yml << EOF
version: '3.8'

services:
  feg_hello:
    image: magma/feg_hello:latest
    container_name: feg_hello
    network_mode: host
    volumes:
      - ./configs:/etc/magma
    environment:
      - MAGMA_PRINT_GRPC_PAYLOAD=0
    
  feg_session_proxy:
    image: magma/feg_session_proxy:latest
    container_name: feg_session_proxy
    network_mode: host
    depends_on:
      - feg_hello
    volumes:
      - ./configs:/etc/magma
    environment:
      - MAGMA_PRINT_GRPC_PAYLOAD=0
    
  health:
    image: magma/health:latest
    container_name: health
    network_mode: host
    depends_on:
      - feg_hello
    volumes:
      - ./configs:/etc/magma
    environment:
      - MAGMA_PRINT_GRPC_PAYLOAD=0
EOF
    
    # Create FGW configuration files
    mkdir -p /tmp/magma-fgw/configs
    cat > /tmp/magma-fgw/configs/feg_gateway.mconfig << EOF
---
magmad_config:
  checkin_interval: 60
  checkin_timeout: 30
  autoupgrade_enabled: false
  autoupgrade_poll_interval: 300
  package_version: "0.0.0-0"
  images: []
  tier: "default"
  feature_flags: {}
  dynamic_services: []

mconfig:
  federation_config:
    federation_id: "$FGW_FEDERATION_ID"
    served_network_ids: ["$(echo $FGW_SERVED_NETWORKS | sed 's/,/","/g')"]
    
  diameter_config:
    host: "$FGW_DIAMETER_HOST"
    realm: "$FGW_DIAMETER_REALM"
    port: $FGW_DIAMETER_PORT
    
  health_config:
    health_service_enabled: true
    update_interval_secs: 10
    cloud_disable_period_secs: 10
    local_disable_period_secs: 1
    
  session_proxy_config:
    request_timeout: 30
    endpoint_timeout: 30
EOF
    
    # Deploy FGW
    cd /tmp/magma-fgw
    docker-compose up -d
    
    print_success "Federated Gateway deployed"
}

deploy_nms() {
    print_info "Setting up Network Management System..."
    
    # Source configuration
    source "$CONFIG_FILE"
    
    # Add Helm repository
    helm repo add magma https://magma.github.io/magma/helm-charts
    helm repo update
    
    # Deploy NMS
    helm upgrade --install nms magma/nms \
        --namespace "$ORC8R_NAMESPACE" \
        --set global.domain="$DOMAIN" \
        --set nms.admin.email="$ADMIN_EMAIL" \
        --set nms.host="$DOMAIN" \
        --set nms.port=8080
    
    print_success "Network Management System deployed"
}

display_summary() {
    print_header "DEPLOYMENT SUMMARY"
    
    source "$CONFIG_FILE"
    
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo
    
    if [[ "$COMPONENTS" == *"orchestrator"* ]]; then
        echo -e "${BLUE}📡 Orchestrator:${NC} https://$DOMAIN"
        echo -e "${BLUE}   Namespace:${NC} $ORC8R_NAMESPACE"
    fi
    
    if [[ "$COMPONENTS" == *"nms"* ]]; then
        echo -e "${BLUE}💻 NMS Portal:${NC} https://$DOMAIN:8080"
        echo -e "${BLUE}   Admin Email:${NC} $ADMIN_EMAIL"
    fi
    
    if [[ "$COMPONENTS" == *"agw"* ]]; then
        echo -e "${BLUE}📡 Access Gateway:${NC} $AGW_IP"
        echo -e "${BLUE}   Network:${NC} $AGW_MCC-$AGW_MNC"
    fi
    
    if [[ "$COMPONENTS" == *"fgw"* ]]; then
        echo -e "${BLUE}🔗 Federated Gateway:${NC} $FGW_FEDERATION_ID"
        echo -e "${BLUE}   Diameter:${NC} $FGW_DIAMETER_HOST:$FGW_DIAMETER_PORT"
    fi
    
    echo
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo "1. Verify all services are running"
    echo "2. Configure your network devices"
    echo "3. Access the NMS portal"
    echo "4. Monitor deployment logs"
    echo
    echo -e "${BLUE}📝 Configuration:${NC} $CONFIG_FILE"
    echo -e "${BLUE}📝 Logs:${NC} $LOG_FILE"
}

# Main execution
main() {
    print_header "MAGMA CORE DEPLOYMENT TOOL"
    
    echo "This script will deploy Magma Core components:"
    echo "📡 Orchestrator (ORC8R)"
    echo "🌐 Access Gateway (AGW)"
    echo "🔗 Federated Gateway (FGW)"
    echo "💻 Network Management System (NMS)"
    echo
    
    if ! confirm "Do you want to continue?"; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Collect configuration
    collect_config
    
    # Confirm deployment
    echo
    if confirm "Do you want to proceed with deployment?"; then
        deploy_components
    else
        print_info "Deployment cancelled"
        exit 0
    fi
}

# Handle script interruption
trap 'print_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"