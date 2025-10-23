# PrestaShop Architecture

## 🏗️ Architecture Overview

### **ALL IN DOCKER** 🐳
- **PrestaShop App**: Docker container (Frontend + Backend)
- **MySQL Database**: Docker container
- **Jenkins**: Docker container (port 8080)
- **LGTM Stack**: Docker containers
- **Access**: `http://<EC2_IP>:3000`

## 🔄 Deployment Flow

```
GitHub (prestashop-app/) → Jenkins Pipeline → Frontend to /var/www/html/ + Backend to Docker
```

### **Step-by-Step:**
1. **Push PrestaShop code** to GitHub in `prestashop-app/` folder
2. **Jenkins Pipeline**:
   - Builds backend Docker image → ECR
   - Deploys to ECS
   - Clones GitHub repo to EC2
   - Copies `prestashop-app/` to `/var/www/html/`
   - Restarts Apache
3. **Result**:
   - PrestaShop frontend runs on Apache
   - MySQL runs in Docker
   - Monitoring via LGTM stack

## 📁 GitHub Repository Structure

```
your-github-repo/
├── prestashop-app/           # Your PrestaShop store
│   ├── index.php
│   ├── config/
│   ├── themes/
│   ├── modules/
│   └── ...
├── Dockerfile               # Backend services
├── Jenkinsfile             # CI/CD pipeline
└── infrastructure/         # Terraform files
```

## 🌐 Access Points

- **PrestaShop Store**: `http://<EC2_IP>`
- **PrestaShop Admin**: `http://<EC2_IP>/admin`
- **Jenkins**: `http://<EC2_IP>:8080`
- **Grafana**: `http://<EC2_IP>:3001`
- **Prometheus**: `http://<EC2_IP>:9090`

## 🔧 Services

### **On EC2 (Native)**
- Apache HTTP Server
- PHP 8.1
- PrestaShop Frontend

### **In Docker (EC2)**
- MySQL 8.0 (database)
- Jenkins (CI/CD)
- Grafana (monitoring)
- Prometheus (metrics)
- Loki (logs)

This setup gives you the best of both worlds: fast frontend performance and containerized backend services!