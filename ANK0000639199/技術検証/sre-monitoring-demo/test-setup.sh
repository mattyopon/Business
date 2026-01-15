#!/bin/bash
# Test script to verify SRE Monitoring Demo setup

echo "========================================="
echo "SRE Monitoring Demo - Setup Verification"
echo "========================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check URL
check_url() {
    local url=$1
    local name=$2
    if curl -f -s "$url" > /dev/null; then
        echo "✓ $name is accessible"
        return 0
    else
        echo "✗ $name is NOT accessible"
        return 1
    fi
}

# Check prerequisites
echo "Checking prerequisites..."
if command_exists docker; then
    echo "✓ Docker is installed"
else
    echo "✗ Docker is NOT installed"
    exit 1
fi

if command_exists docker-compose; then
    echo "✓ Docker Compose is installed"
else
    echo "✗ Docker Compose is NOT installed"
    exit 1
fi

# Check if Docker is running
if docker info > /dev/null 2>&1; then
    echo "✓ Docker is running"
else
    echo "✗ Docker is NOT running. Please start Docker Desktop."
    exit 1
fi

echo ""
echo "Checking project structure..."

# Check key files
files=(
    "docker-compose.yml"
    "app/app.py"
    "app/Dockerfile"
    "app/requirements.txt"
    "prometheus/prometheus.yml"
    "prometheus/alerts.yml"
    "grafana/provisioning/datasources/prometheus.yml"
    "README.md"
)

all_files_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file is MISSING"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo ""
    echo "Some required files are missing. Please check the project structure."
    exit 1
fi

echo ""
echo "Checking Docker containers..."

# Check if containers are running
containers=("sre-prometheus" "sre-grafana" "sre-node-exporter" "sre-sample-app")
all_running=true

for container in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "✓ $container is running"
    else
        echo "✗ $container is NOT running"
        all_running=false
    fi
done

if [ "$all_running" = false ]; then
    echo ""
    echo "Some containers are not running. Start them with: docker-compose up -d"
    exit 0
fi

echo ""
echo "Checking service endpoints..."
sleep 3

# Check endpoints
check_url "http://localhost:8000/health" "Sample Application"
check_url "http://localhost:9090/-/healthy" "Prometheus"
check_url "http://localhost:3000/api/health" "Grafana"
check_url "http://localhost:9100/metrics" "Node Exporter"

echo ""
echo "Checking Prometheus targets..."
targets_up=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)
echo "✓ $targets_up targets are UP in Prometheus"

echo ""
echo "========================================="
echo "Setup Verification Complete!"
echo "========================================="
echo ""
echo "Access your services:"
echo "  Grafana:    http://localhost:3000 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo "  Sample App: http://localhost:8000"
echo ""
echo "Generate test traffic:"
echo "  curl http://localhost:8000/api/data"
echo ""
