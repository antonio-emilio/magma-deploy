#!/usr/bin/env python3
"""
Magma Interactive Deployment Script
===================================

This script provides an interactive deployment solution for Magma Core components:
- Orchestrator (ORC8R)
- Access Gateway (AGW)
- Federated Gateway (FGW)
- Network Management System (NMS)

Author: Magma Deploy Tool
Version: 1.0
"""

import os
import sys
import json
import yaml
import subprocess
import argparse
import logging
from typing import Dict, List, Optional, Any
from pathlib import Path
import getpass
import ipaddress

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('magma_deploy.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class MagmaDeployment:
    """Main deployment class for Magma components"""
    
    def __init__(self):
        self.config = {}
        self.deployment_dir = Path(__file__).parent
        self.config_dir = self.deployment_dir / "config"
        self.scripts_dir = self.deployment_dir / "scripts"
        self.templates_dir = self.deployment_dir / "templates"
        
        # Ensure directories exist
        self.config_dir.mkdir(exist_ok=True)
        self.scripts_dir.mkdir(exist_ok=True)
        self.templates_dir.mkdir(exist_ok=True)
    
    def welcome_message(self):
        """Display welcome message and overview"""
        print("=" * 60)
        print("🎯 MAGMA CORE DEPLOYMENT TOOL")
        print("=" * 60)
        print("\nThis tool will guide you through deploying Magma Core components:")
        print("📡 Orchestrator (ORC8R) - Central management plane")
        print("🌐 Access Gateway (AGW) - Radio access network gateway")
        print("🔗 Federated Gateway (FGW) - Federation with external networks")
        print("💻 Network Management System (NMS) - Web-based management")
        print("\nPrerequisites:")
        print("- Docker and Docker Compose installed")
        print("- Kubernetes cluster (for orchestrator)")
        print("- Sufficient system resources (8GB+ RAM recommended)")
        print("- Network connectivity for downloading images")
        print("=" * 60)
        
        if not self.confirm_action("Do you want to continue with the deployment?"):
            print("Deployment cancelled.")
            sys.exit(0)
    
    def confirm_action(self, message: str) -> bool:
        """Get user confirmation for actions"""
        while True:
            response = input(f"{message} [y/N]: ").lower().strip()
            if response in ['y', 'yes']:
                return True
            elif response in ['n', 'no', '']:
                return False
            else:
                print("Please enter 'y' for yes or 'n' for no.")
    
    def get_user_input(self, prompt: str, default: str = None, required: bool = True) -> str:
        """Get user input with optional default value"""
        if default:
            full_prompt = f"{prompt} [{default}]: "
        else:
            full_prompt = f"{prompt}: "
        
        while True:
            response = input(full_prompt).strip()
            if response:
                return response
            elif default:
                return default
            elif not required:
                return ""
            else:
                print("This field is required. Please enter a value.")
    
    def get_password(self, prompt: str) -> str:
        """Get password input securely"""
        return getpass.getpass(f"{prompt}: ")
    
    def validate_ip_address(self, ip: str) -> bool:
        """Validate IP address format"""
        try:
            ipaddress.ip_address(ip)
            return True
        except ValueError:
            return False
    
    def validate_email(self, email: str) -> bool:
        """Basic email validation"""
        return "@" in email and "." in email.split("@")[1]
    
    def run_command(self, command: str, shell: bool = True, check: bool = True) -> subprocess.CompletedProcess:
        """Execute shell command with logging"""
        logger.info(f"Executing command: {command}")
        try:
            result = subprocess.run(
                command,
                shell=shell,
                check=check,
                capture_output=True,
                text=True
            )
            if result.stdout:
                logger.info(f"Command output: {result.stdout}")
            return result
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {e}")
            logger.error(f"Error output: {e.stderr}")
            raise
    
    def check_prerequisites(self) -> bool:
        """Check if prerequisites are installed"""
        print("\n🔍 Checking prerequisites...")
        
        prerequisites = [
            ("docker", "Docker is required for container deployment"),
            ("docker-compose", "Docker Compose is required for multi-container deployment"),
            ("kubectl", "Kubernetes CLI is required for orchestrator deployment"),
            ("helm", "Helm is required for Kubernetes deployments"),
            ("git", "Git is required for cloning repositories")
        ]
        
        missing_deps = []
        
        for cmd, description in prerequisites:
            try:
                result = self.run_command(f"which {cmd}", check=False)
                if result.returncode == 0:
                    print(f"✅ {cmd} found")
                else:
                    print(f"❌ {cmd} not found - {description}")
                    missing_deps.append(cmd)
            except Exception as e:
                print(f"❌ Error checking {cmd}: {e}")
                missing_deps.append(cmd)
        
        if missing_deps:
            print(f"\n⚠️  Missing dependencies: {', '.join(missing_deps)}")
            if self.confirm_action("Do you want to install missing dependencies automatically?"):
                return self.install_prerequisites(missing_deps)
            else:
                print("Please install missing dependencies manually and run the script again.")
                return False
        
        print("✅ All prerequisites are available!")
        return True
    
    def install_prerequisites(self, missing_deps: List[str]) -> bool:
        """Install missing prerequisites"""
        print("\n📦 Installing prerequisites...")
        
        # Detect OS
        try:
            os_release = self.run_command("cat /etc/os-release").stdout
            if "ubuntu" in os_release.lower() or "debian" in os_release.lower():
                package_manager = "apt"
            elif "centos" in os_release.lower() or "rhel" in os_release.lower():
                package_manager = "yum"
            else:
                print("Unsupported OS. Please install prerequisites manually.")
                return False
        except:
            print("Could not detect OS. Please install prerequisites manually.")
            return False
        
        # Install packages
        for dep in missing_deps:
            try:
                if dep == "docker":
                    self.install_docker(package_manager)
                elif dep == "docker-compose":
                    self.install_docker_compose()
                elif dep == "kubectl":
                    self.install_kubectl()
                elif dep == "helm":
                    self.install_helm()
                elif dep == "git":
                    if package_manager == "apt":
                        self.run_command("sudo apt-get update && sudo apt-get install -y git")
                    else:
                        self.run_command("sudo yum install -y git")
            except Exception as e:
                logger.error(f"Failed to install {dep}: {e}")
                return False
        
        return True
    
    def install_docker(self, package_manager: str):
        """Install Docker"""
        if package_manager == "apt":
            commands = [
                "sudo apt-get update",
                "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",
                "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
                "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
                "sudo apt-get update",
                "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
            ]
        else:
            commands = [
                "sudo yum install -y yum-utils",
                "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
                "sudo yum install -y docker-ce docker-ce-cli containerd.io"
            ]
        
        for cmd in commands:
            self.run_command(cmd)
        
        # Start Docker service
        self.run_command("sudo systemctl start docker")
        self.run_command("sudo systemctl enable docker")
        
        # Add user to docker group
        username = self.run_command("whoami").stdout.strip()
        self.run_command(f"sudo usermod -aG docker {username}")
        print("⚠️  Please log out and log back in to use Docker without sudo")
    
    def install_docker_compose(self):
        """Install Docker Compose"""
        self.run_command("sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose")
        self.run_command("sudo chmod +x /usr/local/bin/docker-compose")
    
    def install_kubectl(self):
        """Install kubectl"""
        commands = [
            "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
            "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
        ]
        for cmd in commands:
            self.run_command(cmd)
    
    def install_helm(self):
        """Install Helm"""
        commands = [
            "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        ]
        for cmd in commands:
            self.run_command(cmd)
    
    def collect_deployment_config(self):
        """Collect deployment configuration from user"""
        print("\n📋 DEPLOYMENT CONFIGURATION")
        print("=" * 40)
        
        # Deployment type selection
        print("\nSelect components to deploy:")
        print("1. Full Magma Stack (Orchestrator + AGW + FGW + NMS)")
        print("2. Orchestrator only")
        print("3. Access Gateway only")
        print("4. Federated Gateway only")
        print("5. Custom selection")
        
        choice = self.get_user_input("Enter your choice (1-5)", "1")
        
        if choice == "1":
            self.config["components"] = ["orchestrator", "agw", "fgw", "nms"]
        elif choice == "2":
            self.config["components"] = ["orchestrator"]
        elif choice == "3":
            self.config["components"] = ["agw"]
        elif choice == "4":
            self.config["components"] = ["fgw"]
        elif choice == "5":
            self.config["components"] = []
            components = ["orchestrator", "agw", "fgw", "nms"]
            for comp in components:
                if self.confirm_action(f"Deploy {comp.upper()}?"):
                    self.config["components"].append(comp)
        
        # General configuration
        self.config["domain"] = self.get_user_input("Domain name", "magma.local")
        self.config["admin_email"] = self.get_user_input("Admin email address")
        while not self.validate_email(self.config["admin_email"]):
            print("Invalid email format.")
            self.config["admin_email"] = self.get_user_input("Admin email address")
        
        # Network configuration
        print("\n🌐 Network Configuration")
        self.config["network"] = {}
        self.config["network"]["external_ip"] = self.get_user_input("External IP address")
        while not self.validate_ip_address(self.config["network"]["external_ip"]):
            print("Invalid IP address format.")
            self.config["network"]["external_ip"] = self.get_user_input("External IP address")
        
        # Component-specific configuration
        if "orchestrator" in self.config["components"]:
            self.collect_orchestrator_config()
        
        if "agw" in self.config["components"]:
            self.collect_agw_config()
        
        if "fgw" in self.config["components"]:
            self.collect_fgw_config()
        
        # Save configuration
        config_file = self.config_dir / "deployment_config.yaml"
        with open(config_file, 'w') as f:
            yaml.dump(self.config, f, default_flow_style=False)
        
        print(f"\n✅ Configuration saved to {config_file}")
    
    def collect_orchestrator_config(self):
        """Collect orchestrator-specific configuration"""
        print("\n🏗️  Orchestrator Configuration")
        self.config["orchestrator"] = {}
        
        # Kubernetes configuration
        self.config["orchestrator"]["namespace"] = self.get_user_input("Kubernetes namespace", "magma")
        self.config["orchestrator"]["storage_class"] = self.get_user_input("Storage class", "standard")
        
        # Database configuration
        self.config["orchestrator"]["db_host"] = self.get_user_input("Database host", "postgresql")
        self.config["orchestrator"]["db_port"] = self.get_user_input("Database port", "5432")
        self.config["orchestrator"]["db_user"] = self.get_user_input("Database user", "magma")
        self.config["orchestrator"]["db_password"] = self.get_password("Database password")
        self.config["orchestrator"]["db_name"] = self.get_user_input("Database name", "magma")
        
        # TLS configuration
        self.config["orchestrator"]["tls_cert_path"] = self.get_user_input("TLS certificate path", "/opt/magma/certs/tls.crt", required=False)
        self.config["orchestrator"]["tls_key_path"] = self.get_user_input("TLS key path", "/opt/magma/certs/tls.key", required=False)
    
    def collect_agw_config(self):
        """Collect AGW-specific configuration"""
        print("\n📡 Access Gateway Configuration")
        self.config["agw"] = {}
        
        # Network configuration
        self.config["agw"]["interface"] = self.get_user_input("Network interface", "eth0")
        self.config["agw"]["ip_address"] = self.get_user_input("AGW IP address")
        while not self.validate_ip_address(self.config["agw"]["ip_address"]):
            print("Invalid IP address format.")
            self.config["agw"]["ip_address"] = self.get_user_input("AGW IP address")
        
        # LTE configuration
        self.config["agw"]["mcc"] = self.get_user_input("Mobile Country Code (MCC)", "001")
        self.config["agw"]["mnc"] = self.get_user_input("Mobile Network Code (MNC)", "01")
        self.config["agw"]["tac"] = self.get_user_input("Tracking Area Code (TAC)", "1")
        
        # S1AP configuration
        self.config["agw"]["s1ap_ip"] = self.get_user_input("S1AP IP address", self.config["agw"]["ip_address"])
        self.config["agw"]["s1ap_port"] = self.get_user_input("S1AP port", "36412")
    
    def collect_fgw_config(self):
        """Collect FGW-specific configuration"""
        print("\n🔗 Federated Gateway Configuration")
        self.config["fgw"] = {}
        
        # Federation configuration
        self.config["fgw"]["federation_id"] = self.get_user_input("Federation ID", "fgw01")
        self.config["fgw"]["served_network_ids"] = self.get_user_input("Served network IDs (comma-separated)", "network1,network2").split(",")
        
        # Diameter configuration
        self.config["fgw"]["diameter_host"] = self.get_user_input("Diameter host", "fgw.magma.local")
        self.config["fgw"]["diameter_realm"] = self.get_user_input("Diameter realm", "magma.local")
        self.config["fgw"]["diameter_port"] = self.get_user_input("Diameter port", "3868")
    
    def deploy_components(self):
        """Deploy selected components"""
        print("\n🚀 STARTING DEPLOYMENT")
        print("=" * 40)
        
        for component in self.config["components"]:
            print(f"\n📦 Deploying {component.upper()}...")
            
            if component == "orchestrator":
                self.deploy_orchestrator()
            elif component == "agw":
                self.deploy_agw()
            elif component == "fgw":
                self.deploy_fgw()
            elif component == "nms":
                self.deploy_nms()
            
            print(f"✅ {component.upper()} deployment completed")
        
        print("\n🎉 All selected components deployed successfully!")
        self.display_deployment_summary()
    
    def deploy_orchestrator(self):
        """Deploy the orchestrator component"""
        print("Setting up Orchestrator...")
        
        # Create namespace
        try:
            self.run_command(f"kubectl create namespace {self.config['orchestrator']['namespace']}")
        except subprocess.CalledProcessError:
            print("Namespace already exists or error creating it")
        
        # Generate orchestrator deployment script
        orc8r_script = self.scripts_dir / "deploy_orchestrator.sh"
        self.generate_orchestrator_script(orc8r_script)
        
        # Execute deployment
        self.run_command(f"chmod +x {orc8r_script}")
        self.run_command(str(orc8r_script))
    
    def deploy_agw(self):
        """Deploy the Access Gateway component"""
        print("Setting up Access Gateway...")
        
        # Generate AGW deployment script
        agw_script = self.scripts_dir / "deploy_agw.sh"
        self.generate_agw_script(agw_script)
        
        # Execute deployment
        self.run_command(f"chmod +x {agw_script}")
        self.run_command(str(agw_script))
    
    def deploy_fgw(self):
        """Deploy the Federated Gateway component"""
        print("Setting up Federated Gateway...")
        
        # Generate FGW deployment script
        fgw_script = self.scripts_dir / "deploy_fgw.sh"
        self.generate_fgw_script(fgw_script)
        
        # Execute deployment
        self.run_command(f"chmod +x {fgw_script}")
        self.run_command(str(fgw_script))
    
    def deploy_nms(self):
        """Deploy the Network Management System"""
        print("Setting up Network Management System...")
        
        # Generate NMS deployment script
        nms_script = self.scripts_dir / "deploy_nms.sh"
        self.generate_nms_script(nms_script)
        
        # Execute deployment
        self.run_command(f"chmod +x {nms_script}")
        self.run_command(str(nms_script))
    
    def generate_orchestrator_script(self, script_path: Path):
        """Generate orchestrator deployment script"""
        script_content = f"""#!/bin/bash
set -e

echo "🏗️  Deploying Magma Orchestrator..."

# Add Magma Helm repository
helm repo add magma https://magma.github.io/magma/helm-charts
helm repo update

# Create TLS certificates if not provided
if [[ ! -f "{self.config['orchestrator'].get('tls_cert_path', '/opt/magma/certs/tls.crt')}" ]]; then
    echo "Generating TLS certificates..."
    mkdir -p /opt/magma/certs
    openssl req -x509 -newkey rsa:4096 -keyout /opt/magma/certs/tls.key -out /opt/magma/certs/tls.crt -days 365 -nodes -subj "/CN={self.config['domain']}"
fi

# Deploy PostgreSQL
helm upgrade --install postgresql oci://registry-1.docker.io/bitnamicharts/postgresql \\
    --namespace {self.config['orchestrator']['namespace']} \\
    --set auth.postgresPassword={self.config['orchestrator']['db_password']} \\
    --set auth.database={self.config['orchestrator']['db_name']} \\
    --set auth.username={self.config['orchestrator']['db_user']} \\
    --set primary.persistence.storageClass={self.config['orchestrator']['storage_class']}

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n {self.config['orchestrator']['namespace']} --timeout=300s

# Deploy Orchestrator
helm upgrade --install orc8r magma/orc8r \\
    --namespace {self.config['orchestrator']['namespace']} \\
    --set global.domain={self.config['domain']} \\
    --set postgresql.host={self.config['orchestrator']['db_host']} \\
    --set postgresql.port={self.config['orchestrator']['db_port']} \\
    --set postgresql.user={self.config['orchestrator']['db_user']} \\
    --set postgresql.password={self.config['orchestrator']['db_password']} \\
    --set postgresql.database={self.config['orchestrator']['db_name']} \\
    --set-file tls.crt={self.config['orchestrator'].get('tls_cert_path', '/opt/magma/certs/tls.crt')} \\
    --set-file tls.key={self.config['orchestrator'].get('tls_key_path', '/opt/magma/certs/tls.key')}

echo "✅ Orchestrator deployment completed"
"""
        
        with open(script_path, 'w') as f:
            f.write(script_content)
    
    def generate_agw_script(self, script_path: Path):
        """Generate AGW deployment script"""
        script_content = f"""#!/bin/bash
set -e

echo "📡 Deploying Access Gateway..."

# Clone Magma repository
if [[ ! -d "magma" ]]; then
    git clone https://github.com/magma/magma.git
fi

cd magma

# Build AGW
cd lte/gateway
make build

# Configure AGW
mkdir -p /etc/magma
cat > /etc/magma/gateway.mconfig << EOF
---
magmad_config:
  checkin_interval: 60
  checkin_timeout: 30
  autoupgrade_enabled: false
  autoupgrade_poll_interval: 300
  package_version: "0.0.0-0"
  images: []
  tier: "default"
  feature_flags: {{}}
  dynamic_services: []

mconfig:
  mobility_config:
    ip_pool: "192.168.128.0/24"
    static_ip_enabled: false
    multi_apn_ip_alloc: false
    nat_enabled: true
    enable_static_ip_assignments: false
    
  mme_config:
    mcc: "{self.config['agw']['mcc']}"
    mnc: "{self.config['agw']['mnc']}"
    tac: {self.config['agw']['tac']}
    mme_code: 1
    mme_gid: 1
    enable_dns_caching: false
    non_eps_service_control: 0
    csfb_mcc: "{self.config['agw']['mcc']}"
    csfb_mnc: "{self.config['agw']['mnc']}"
    lac: 1
    s1ap_ip: "{self.config['agw']['s1ap_ip']}"
    s1ap_port: {self.config['agw']['s1ap_port']}
    
  spgw_config:
    enable_nat: true
    gtpu_endpoint: "{self.config['agw']['ip_address']}"
    
  enodebd_config:
    earfcndl: 44490
    subframe_assignment: 2
    special_subframe_pattern: 7
    pci: 260
    plmn_ids:
      - mcc: "{self.config['agw']['mcc']}"
        mnc: "{self.config['agw']['mnc']}"
EOF

# Start AGW services
sudo systemctl enable magma@*
sudo systemctl start magma@*

echo "✅ Access Gateway deployment completed"
"""
        
        with open(script_path, 'w') as f:
            f.write(script_content)
    
    def generate_fgw_script(self, script_path: Path):
        """Generate FGW deployment script"""
        script_content = f"""#!/bin/bash
set -e

echo "🔗 Deploying Federated Gateway..."

# Clone Magma repository
if [[ ! -d "magma" ]]; then
    git clone https://github.com/magma/magma.git
fi

cd magma

# Build FGW
cd feg/gateway
make build

# Configure FGW
mkdir -p /etc/magma
cat > /etc/magma/feg_gateway.mconfig << EOF
---
magmad_config:
  checkin_interval: 60
  checkin_timeout: 30
  autoupgrade_enabled: false
  autoupgrade_poll_interval: 300
  package_version: "0.0.0-0"
  images: []
  tier: "default"
  feature_flags: {{}}
  dynamic_services: []

mconfig:
  federation_config:
    federation_id: "{self.config['fgw']['federation_id']}"
    served_network_ids: {self.config['fgw']['served_network_ids']}
    
  diameter_config:
    host: "{self.config['fgw']['diameter_host']}"
    realm: "{self.config['fgw']['diameter_realm']}"
    port: {self.config['fgw']['diameter_port']}
    
  health_config:
    health_service_enabled: true
    update_interval_secs: 10
    cloud_disable_period_secs: 10
    local_disable_period_secs: 1
    
  session_proxy_config:
    request_timeout: 30
    endpoint_timeout: 30
EOF

# Start FGW services
sudo systemctl enable magma@*
sudo systemctl start magma@*

echo "✅ Federated Gateway deployment completed"
"""
        
        with open(script_path, 'w') as f:
            f.write(script_content)
    
    def generate_nms_script(self, script_path: Path):
        """Generate NMS deployment script"""
        script_content = f"""#!/bin/bash
set -e

echo "💻 Deploying Network Management System..."

# Add Magma Helm repository
helm repo add magma https://magma.github.io/magma/helm-charts
helm repo update

# Deploy NMS
helm upgrade --install nms magma/nms \\
    --namespace {self.config['orchestrator']['namespace']} \\
    --set global.domain={self.config['domain']} \\
    --set nms.admin.email={self.config['admin_email']} \\
    --set nms.host={self.config['domain']} \\
    --set nms.port=8080

echo "✅ Network Management System deployment completed"
"""
        
        with open(script_path, 'w') as f:
            f.write(script_content)
    
    def display_deployment_summary(self):
        """Display deployment summary and access information"""
        print("\n🎉 DEPLOYMENT SUMMARY")
        print("=" * 40)
        
        if "orchestrator" in self.config["components"]:
            print(f"📡 Orchestrator: https://{self.config['domain']}")
            print(f"   Namespace: {self.config['orchestrator']['namespace']}")
        
        if "nms" in self.config["components"]:
            print(f"💻 NMS Portal: https://{self.config['domain']}:8080")
            print(f"   Admin Email: {self.config['admin_email']}")
        
        if "agw" in self.config["components"]:
            print(f"📡 Access Gateway: {self.config['agw']['ip_address']}")
            print(f"   Network: {self.config['agw']['mcc']}-{self.config['agw']['mnc']}")
        
        if "fgw" in self.config["components"]:
            print(f"🔗 Federated Gateway: {self.config['fgw']['federation_id']}")
            print(f"   Diameter: {self.config['fgw']['diameter_host']}:{self.config['fgw']['diameter_port']}")
        
        print("\n📋 Next Steps:")
        print("1. Verify all services are running")
        print("2. Configure your network devices to connect to the gateways")
        print("3. Access the NMS portal to manage your network")
        print("4. Monitor logs for any issues")
        
        print(f"\n📝 Configuration saved in: {self.config_dir}")
        print(f"📝 Logs available in: magma_deploy.log")
    
    def run_deployment(self):
        """Main deployment workflow"""
        try:
            self.welcome_message()
            
            if not self.check_prerequisites():
                return False
            
            self.collect_deployment_config()
            
            if self.confirm_action("Do you want to proceed with the deployment?"):
                self.deploy_components()
                return True
            else:
                print("Deployment cancelled by user.")
                return False
                
        except KeyboardInterrupt:
            print("\n\n⚠️  Deployment interrupted by user.")
            return False
        except Exception as e:
            logger.error(f"Deployment failed: {e}")
            print(f"\n❌ Deployment failed: {e}")
            return False

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Magma Core Interactive Deployment Tool')
    parser.add_argument('--config', help='Path to configuration file', type=str)
    parser.add_argument('--skip-prerequisites', help='Skip prerequisite checks', action='store_true')
    parser.add_argument('--dry-run', help='Show what would be deployed without actually deploying', action='store_true')
    
    args = parser.parse_args()
    
    # Create deployment instance
    deployment = MagmaDeployment()
    
    # Load configuration if provided
    if args.config:
        try:
            with open(args.config, 'r') as f:
                deployment.config = yaml.safe_load(f)
            print(f"✅ Configuration loaded from {args.config}")
        except Exception as e:
            print(f"❌ Error loading configuration: {e}")
            sys.exit(1)
    
    # Run deployment
    if deployment.run_deployment():
        print("\n🎉 Deployment completed successfully!")
        sys.exit(0)
    else:
        print("\n❌ Deployment failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()