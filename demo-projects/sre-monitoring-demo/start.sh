#!/bin/bash
# Quick start script for SRE Monitoring Demo

echo "Starting SRE Monitoring Demo..."
echo "================================"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

echo "✓ Docker is running"
echo ""

# Start services
echo "Starting all services..."
docker-compose up -d

echo ""
echo "Waiting for services to start..."
sleep 10

# Check service status
echo ""
echo "Service Status:"
docker-compose ps

echo ""
echo "================================"
echo "Services are starting up!"
echo ""
echo "Access the following URLs:"
echo "  Grafana:    http://localhost:3000 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo "  Sample App: http://localhost:8000"
echo "  Node Exporter: http://localhost:9100/metrics"
echo ""
echo "View logs: docker-compose logs -f"
echo "Stop services: docker-compose down"
echo "================================"
