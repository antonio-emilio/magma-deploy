# Magma Core Deployment Tool

🎯 **Interactive deployment scripts for Magma Core components**

This repository provides comprehensive deployment tools for [Magma Core](https://magmacore.org/), an open-source software platform that gives network operators an open, flexible and extendable mobile core network solution.

## 🚀 Quick Start

### Prerequisites

- **Operating System**: Ubuntu 18.04+, CentOS 7+, or compatible Linux distribution
- **Resources**: 8GB+ RAM, 4+ CPU cores, 100GB+ disk space
- **Network**: Internet connectivity for downloading container images
- **Privileges**: sudo access for installing dependencies

### Option 1: Python Interactive Deployment (Recommended)

```bash
# Make executable and run
chmod +x deploy_magma.py
./deploy_magma.py
```

### Option 2: Bash Script Deployment

```bash
# Make executable and run
chmod +x deploy_magma.sh
./deploy_magma.sh
```

### Option 3: Configuration File Deployment

```bash
# Copy and customize configuration
cp config/magma_config.env.template config/magma_config.env
# Edit config/magma_config.env with your settings
./deploy_magma.py --config config/magma_config.env
```

## 📦 Components

The deployment tool supports the following Magma components:

### 🏗️ Orchestrator (ORC8R)
- **Function**: Central management plane for the Magma network
- **Deployment**: Kubernetes-based using Helm charts
- **Features**: 
  - Network configuration management
  - Policy enforcement
  - Metrics collection
  - Certificate management
  - Multi-tenancy support

### 📡 Access Gateway (AGW)
- **Function**: LTE access network gateway
- **Deployment**: Docker Compose on physical/virtual machine
- **Features**:
  - LTE core network functions (MME, SPGW, HSS)
  - eNodeB management
  - Subscriber session management
  - Traffic policy enforcement
  - Mobility management

### 🔗 Federated Gateway (FGW)
- **Function**: Federation with external core networks
- **Deployment**: Docker Compose on physical/virtual machine
- **Features**:
  - S8 interface support
  - Diameter protocol handling
  - Session proxy functionality
  - Multi-network federation
  - Health monitoring

### 💻 Network Management System (NMS)
- **Function**: Web-based network management interface
- **Deployment**: Kubernetes-based using Helm charts
- **Features**:
  - Graphical network topology view
  - Performance monitoring dashboards
  - Configuration management UI
  - Alarm and event management
  - User access control

## 🛠️ Installation Process

### Automatic Prerequisites Installation

The deployment scripts automatically detect and install missing dependencies:

- **Docker & Docker Compose**: Container runtime and orchestration
- **Kubernetes & kubectl**: Container orchestration platform
- **Helm**: Kubernetes package manager
- **Git**: Version control system
- **OpenSSL**: Certificate generation

### Interactive Configuration

Both deployment scripts provide interactive configuration collection:

1. **Component Selection**: Choose which components to deploy
2. **Network Configuration**: Set IP addresses, domain names, and network parameters
3. **Security Settings**: Configure TLS certificates and authentication
4. **Database Configuration**: Set up PostgreSQL connection details
5. **LTE Parameters**: Configure MCC, MNC, TAC for mobile networks
6. **Federation Settings**: Set up diameter and federation parameters

### Deployment Validation

The scripts perform comprehensive validation:

- ✅ Prerequisites check
- ✅ Network connectivity validation
- ✅ Resource availability check
- ✅ Configuration validation
- ✅ Service health monitoring

## 📋 Configuration Options

### Network Configuration
```bash
DOMAIN="magma.local"                    # Primary domain name
EXTERNAL_IP="192.168.1.100"           # External IP address
ADMIN_EMAIL="admin@magma.local"        # Administrator email
```

### Orchestrator Configuration
```bash
ORC8R_NAMESPACE="magma"                # Kubernetes namespace
ORC8R_STORAGE_CLASS="standard"         # Storage class for persistent volumes
ORC8R_DB_HOST="postgresql"             # Database host
ORC8R_DB_PORT="5432"                   # Database port
ORC8R_DB_USER="magma"                  # Database username
ORC8R_DB_PASSWORD="magma123"           # Database password
ORC8R_DB_NAME="magma"                  # Database name
```

### Access Gateway Configuration
```bash
AGW_INTERFACE="eth0"                   # Network interface
AGW_IP="192.168.1.101"                 # AGW IP address
AGW_MCC="001"                          # Mobile Country Code
AGW_MNC="01"                           # Mobile Network Code
AGW_TAC="1"                            # Tracking Area Code
AGW_S1AP_IP="192.168.1.101"           # S1AP interface IP
AGW_S1AP_PORT="36412"                  # S1AP port
```

### Federated Gateway Configuration
```bash
FGW_FEDERATION_ID="fgw01"              # Federation identifier
FGW_SERVED_NETWORKS="network1,network2" # Served network IDs
FGW_DIAMETER_HOST="fgw.magma.local"    # Diameter host
FGW_DIAMETER_REALM="magma.local"       # Diameter realm
FGW_DIAMETER_PORT="3868"               # Diameter port
```

## 🔐 Security Features

### TLS Certificate Management
- **Automatic Generation**: Self-signed certificates for testing
- **Custom Certificates**: Support for production certificates
- **Certificate Rotation**: Automated certificate renewal
- **Secure Communication**: All inter-component communication is encrypted

### Authentication & Authorization
- **Admin Account**: Configurable administrator credentials
- **Role-Based Access**: Multi-level user permissions
- **API Security**: Secure REST API with token-based authentication
- **Network Isolation**: Container network security

## 📊 Monitoring & Logging

### Built-in Monitoring
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboards
- **Health Checks**: Service health monitoring
- **Performance Metrics**: Network performance tracking

### Logging
- **Centralized Logging**: All components log to central location
- **Log Rotation**: Automatic log file management
- **Debug Mode**: Detailed logging for troubleshooting
- **Audit Trail**: Security and configuration change tracking

## 🌐 Network Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Orchestrator  │    │ Access Gateway  │    │Federated Gateway│
│     (ORC8R)     │    │     (AGW)       │    │     (FGW)       │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Configuration │    │ • MME           │    │ • S8 Interface  │
│ • Policy Mgmt   │    │ • SPGW          │    │ • Diameter      │
│ • Metrics       │    │ • SessionD      │    │ • Session Proxy │
│ • Certificates  │    │ • MobilityD     │    │ • Health        │
│ • Multi-tenancy │    │ • EnodeBD       │    │ • Federation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │       ┌─────────────────────────────────────┐ │
         └───────┤    Network Management System (NMS)  ├─┘
                 │           Web Interface             │
                 └─────────────────────────────────────┘
```

## 🚨 Troubleshooting

### Common Issues

1. **Docker Permission Denied**
   ```bash
   sudo usermod -aG docker $USER
   # Log out and log back in
   ```

2. **Kubernetes Connection Issues**
   ```bash
   kubectl cluster-info
   # Verify cluster connectivity
   ```

3. **Helm Chart Issues**
   ```bash
   helm repo update
   # Update Helm repositories
   ```

4. **Port Conflicts**
   ```bash
   netstat -tulpn | grep LISTEN
   # Check for port conflicts
   ```

### Log Locations
- **Python Script**: `magma_deploy.log`
- **Bash Script**: `magma_deploy_bash.log`
- **Container Logs**: `docker logs <container_name>`
- **Kubernetes Logs**: `kubectl logs <pod_name> -n <namespace>`

### Support Commands
```bash
# Check deployment status
./deploy_magma.py --status

# Restart services
docker-compose restart
kubectl rollout restart deployment/<deployment_name>

# Clean deployment
./deploy_magma.py --clean
```

## 🎯 Production Deployment

### Recommended Architecture
- **Orchestrator**: Kubernetes cluster with 3+ nodes
- **Access Gateway**: Dedicated physical server
- **Federated Gateway**: Dedicated physical server
- **Load Balancer**: For high availability
- **Database**: PostgreSQL cluster with replication

### Performance Tuning
- **Resource Limits**: Configure appropriate CPU/memory limits
- **Network Optimization**: Optimize network interfaces and routing
- **Storage**: Use SSD storage for database and high-IOPS workloads
- **Monitoring**: Set up comprehensive monitoring and alerting

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: [Magma Documentation](https://docs.magmacore.org/)
- **Community**: [Magma Slack](https://magmacore.slack.com/)
- **Issues**: [GitHub Issues](https://github.com/antonio-emilio/magma-deploy/issues)
- **Discussions**: [GitHub Discussions](https://github.com/antonio-emilio/magma-deploy/discussions)

## ⚡ Quick Commands

```bash
# Full deployment
./deploy_magma.py

# Orchestrator only
./deploy_magma.py --components orchestrator

# Custom configuration
./deploy_magma.py --config my_config.env

# Skip prerequisites check
./deploy_magma.py --skip-prerequisites

# Dry run (show what would be deployed)
./deploy_magma.py --dry-run

# Clean deployment
./deploy_magma.py --clean
```

---

**Made with ❤️ for the Magma Community**