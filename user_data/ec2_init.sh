#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Java for Jenkins
yum install -y java-11-openjdk java-11-openjdk-devel

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins
systemctl start jenkins
systemctl enable jenkins

# Install Git
yum install -y git

# Create application directory
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# Configure ECR login
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repository_url}

# Create docker-compose.yml for LGTM stack + Jenkins
cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  monitoring:
    driver: bridge

services:
  # PrestaShop Application (Frontend + Backend)
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
      - PS_INSTALL_AUTO=1
    depends_on:
      - mysql
    networks:
      - monitoring
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # MySQL Database for PrestaShop
  mysql:
    image: mysql:8.0
    container_name: mysql
    environment:
      - MYSQL_ROOT_PASSWORD=root123
      - MYSQL_DATABASE=prestashop
      - MYSQL_USER=prestashop
      - MYSQL_PASSWORD=prestashop123
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
    environment:
      - JENKINS_OPTS=--httpPort=8080
    volumes:
      - jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /usr/bin/docker:/usr/bin/docker
    networks:
      - monitoring
    restart: unless-stopped
    user: root

  # Grafana
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
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - monitoring
    restart: unless-stopped

  # Loki
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

  # Promtail
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

  # Prometheus
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

volumes:
  grafana-data:
  loki-data:
  prometheus-data:
  jenkins-data:
  mysql-data:
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
  
  - job_name: 'prestashop-app'
    static_configs:
      - targets: ['prestashop-app:80']
    
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'jenkins'
    static_configs:
      - targets: ['jenkins:8080']
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
          expression: (?P<container_name>(?:[^|]*))\|
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

# Create Grafana provisioning directories
mkdir -p grafana/provisioning/{datasources,dashboards}

# Create Grafana datasources
cat > grafana/provisioning/datasources/datasources.yml << 'EOF'
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
EOF

# Set ownership
chown -R ec2-user:ec2-user /home/ec2-user/app

# Create update script
cat > /home/ec2-user/update-app.sh << 'EOF'
#!/bin/bash
set -e
cd /home/ec2-user/app
echo "Updating PrestaShop application..."
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repository_url}
docker-compose pull prestashop-app
docker-compose up -d prestashop-app
echo "PrestaShop application updated successfully!"
EOF

chmod +x /home/ec2-user/update-app.sh
chown ec2-user:ec2-user /home/ec2-user/update-app.sh

# Start the stack
cd /home/ec2-user/app
docker-compose up -d

echo "EC2 initialization completed successfully!"
echo "Services will be available at:"
echo "- Application: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "- Jenkins: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "- Grafana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3001"
echo "- Prometheus: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"