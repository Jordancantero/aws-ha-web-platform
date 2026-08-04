#!/bin/bash
set -e

echo "Updating system..."
dnf update -y

echo "Installing SSM Agent..."
dnf install -y amazon-ssm-agent || true
systemctl enable amazon-ssm-agent
systemctl restart amazon-ssm-agent

echo "Installing CloudWatch Agent..."
dnf install -y amazon-cloudwatch-agent

echo "Installing Docker..."
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user


echo "Logging into ECR..."
ACCOUNT_ID=${account_id}
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    ${account_id}.dkr.ecr.us-east-1.amazonaws.com

echo "Pulling image..."
IMAGE="${account_id}.dkr.ecr.us-east-1.amazonaws.com/task-manager-app:latest"
docker pull $IMAGE
docker inspect --format='{{index .RepoDigests 0}}' $IMAGE

echo "Running container..."
docker stop flask-container || true
docker rm flask-container   || true

echo "Creating log directory..."
mkdir -p /var/log/task-manager

docker run -d \
  --name flask-container \
  -p 5000:5000 \
  --restart always \
  -v /var/log/task-manager:/app/logs \
  -e AWS_REGION=${aws_region} \
  -e SECRET_NAME=${secret_name} \
  -e S3_BUCKET=${bucket_name} \
  $IMAGE

echo "Configuring CloudWatch Agent..."

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/task-manager/app.log",
            "log_group_name": "/aws/ec2/task-manager",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

echo "Starting CloudWatch Agent..."

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config \
-m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
-s  

echo "Verifying container..."
sleep 3
if docker ps | grep -q flask-container; then
  echo "DONE — container is running"
else
  echo "ERROR — container failed to start" >&2
  docker logs flask-container
  exit 1
fi

