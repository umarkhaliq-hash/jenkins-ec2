#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user data script at $(date)"

# Update system
apt-get update -y
apt-get upgrade -y

# Install Docker
apt-get install -y docker.io curl unzip git ca-certificates gnupg lsb-release
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu

# Install Docker Compose (standalone)
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify Docker Compose installation
docker-compose --version

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create application directory
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# Configure ECR login
echo "Configuring ECR login..."
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repository_url}
echo "ECR login completed"

# Create COMPLETE LGTM + Jenkins + MySQL stack
cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  monitoring:
    driver: bridge

services:
  # PrestaShop Application
  prestashop-app:
    image: ${ecr_repository_url}:latest
    container_name: prestashop-app
    ports:
      - "3000:80"
    environment:
      - DB_SERVER=mysql
      - DB_NAME=prestashop
      - DB_USER=prestashop
      - DB_PASSWD=prestashop123
    depends_on:
      - mysql
    networks:
      - monitoring
    restart: unless-stopped

  # MySQL Database
  mysql:
    image: mysql:8.0
    container_name: mysql
    environment:
      - MYSQL_ROOT_PASSWORD=root123
      - MYSQL_DATABASE=prestashop
      - MYSQL_USER=prestashop
      - MYSQL_PASSWORD=prestashop123
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - monitoring
    restart: unless-stopped

  # Jenkins
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - monitoring
    restart: unless-stopped
    user: root

  # Loki (L in LGTM)
  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - loki-data:/loki
    networks:
      - monitoring
    restart: unless-stopped

  # Grafana (G in LGTM)
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    networks:
      - monitoring
    restart: unless-stopped

  # Tempo (T in LGTM)
  tempo:
    image: grafana/tempo:latest
    container_name: tempo
    ports:
      - "3200:3200"
      - "14268:14268"
    volumes:
      - tempo-data:/tmp/tempo
    networks:
      - monitoring
    restart: unless-stopped

  # Mimir (M in LGTM)
  mimir:
    image: grafana/mimir:latest
    container_name: mimir
    ports:
      - "9009:9009"
    volumes:
      - mimir-data:/data
    networks:
      - monitoring
    restart: unless-stopped

  # Prometheus (Metrics Collection)
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - monitoring
    restart: unless-stopped

  # Promtail (Log Shipping)
  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring
    restart: unless-stopped

volumes:
  mysql-data:
  jenkins-data:
  loki-data:
  grafana-data:
  tempo-data:
  mimir-data:
  prometheus-data:
EOF

# Create Prometheus config
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'jenkins'
    static_configs:
      - targets: ['jenkins:8080']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'tempo'
    static_configs:
      - targets: ['tempo:3200']

  - job_name: 'mimir'
    static_configs:
      - targets: ['mimir:9009']

  - job_name: 'prestashop-app'
    static_configs:
      - targets: ['prestashop-app:80']
EOF

# Create Promtail config
cat > promtail-config.yml << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log

    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*))
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
      - output:
          source: output
EOF

# Create Grafana datasources
cat > grafana-datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200

  - name: Mimir
    type: prometheus
    access: proxy
    url: http://mimir:9009/prometheus
EOF

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/app

# Create update script
cat > /home/ubuntu/update-app.sh << 'EOF'
#!/bin/bash
set -e
cd /home/ubuntu/app
echo "Updating PrestaShop application..."
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repository_url}
docker-compose pull prestashop-app
docker-compose up -d prestashop-app
echo "PrestaShop application updated successfully!"
EOF

chmod +x /home/ubuntu/update-app.sh
chown ubuntu:ubuntu /home/ubuntu/update-app.sh

# Verify Docker is working
echo "Verifying Docker installation..."
docker --version
docker-compose --version

# Start the COMPLETE LGTM + Jenkins + MySQL stack
echo "Starting ALL Docker services..."
cd /home/ubuntu/app
docker-compose up -d mysql jenkins loki grafana tempo mimir prometheus promtail

# Wait a moment and check status
sleep 10
echo "Checking container status..."
docker ps

echo "User data script completed successfully at $(date)"

echo "EC2 initialization completed successfully!"
echo "COMPLETE LGTM + Jenkins + MySQL Stack Ready!"
echo "Services available at:"
echo "- PrestaShop App: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "- Jenkins: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "- Grafana (G): http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3001 (admin/admin123)"
echo "- Prometheus: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "- Loki (L): http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3100"
echo "- Tempo (T): http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3200"
echo "- Mimir (M): http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9009"
echo "- MySQL: localhost:3306 (root/root123)"