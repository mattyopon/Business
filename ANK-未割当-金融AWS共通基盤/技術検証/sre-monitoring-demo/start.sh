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

# Bootstrap .env (Grafana 認証情報など compose 起動必須変数)
# docker-compose.yml で ${GF_SECURITY_ADMIN_PASSWORD:?...} を必須化済み。
# 弱い既定値を避けるため、.env が無ければ .env.example をコピーしランダム password を自動生成する。
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "Bootstrapping .env from .env.example (set strong values before sharing!)..."
        cp .env.example .env
        if command -v openssl >/dev/null 2>&1; then
            RAND_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
            if sed --version >/dev/null 2>&1; then
                sed -i "s|^GF_SECURITY_ADMIN_PASSWORD=.*|GF_SECURITY_ADMIN_PASSWORD=${RAND_PASS}|" .env
            else
                sed -i '' "s|^GF_SECURITY_ADMIN_PASSWORD=.*|GF_SECURITY_ADMIN_PASSWORD=${RAND_PASS}|" .env
            fi
            echo "  → Generated random GF_SECURITY_ADMIN_PASSWORD (32 chars) into .env"
        else
            echo "  → openssl not found. Edit .env to set a strong GF_SECURITY_ADMIN_PASSWORD before continuing." >&2
        fi
    else
        echo "Error: neither .env nor .env.example found. Cannot continue." >&2
        exit 1
    fi
fi

# Start services
echo "Starting all services..."
docker-compose --env-file .env up -d

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
echo "  Grafana:    http://localhost:3000 (${GF_SECURITY_ADMIN_USER}/${GF_SECURITY_ADMIN_PASSWORD} (.env で生成))"
echo "  Prometheus: http://localhost:9090"
echo "  Sample App: http://localhost:8000"
echo "  Node Exporter: http://localhost:9100/metrics"
echo ""
echo "View logs: docker-compose logs -f"
echo "Stop services: docker-compose down"
echo "================================"
