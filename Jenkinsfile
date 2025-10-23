pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-2'
        ECR_REPOSITORY = credentials('ecr-repository-url')
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${ECR_REPOSITORY}:${IMAGE_TAG}")
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_REPOSITORY}:latest
                        docker push ${ECR_REPOSITORY}:${IMAGE_TAG}
                        docker push ${ECR_REPOSITORY}:latest
                    """
                }
            }
        }
        
        stage('Deploy to ECS') {
            steps {
                script {
                    sh """
                        aws ecs update-service --cluster ecommerce-dev-cluster --service ecommerce-dev-service --force-new-deployment --region ${AWS_REGION}
                    """
                }
            }
        }
        
        stage('Update EC2 Docker App') {
            steps {
                script {
                    sh """
                        EC2_IP=\$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ecommerce-dev-app-server" --query "Reservations[*].Instances[*].PublicIpAddress" --output text --region ${AWS_REGION})
                        ssh -o StrictHostKeyChecking=no -i ssh-keys/ecommerce-key ubuntu@\$EC2_IP 'bash /home/ubuntu/update-app.sh'
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}