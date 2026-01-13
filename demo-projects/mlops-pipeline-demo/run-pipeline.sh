#!/bin/bash

# MLOps Pipeline Demo - Quick Start Script
# This script runs the complete ML pipeline

set -e

echo "========================================"
echo "MLOps Pipeline Demo - Quick Start"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${YELLOW}Error: Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

echo -e "${BLUE}Step 1: Starting services...${NC}"
docker-compose up -d
echo ""

# Wait for MLflow to be ready
echo -e "${BLUE}Step 2: Waiting for MLflow to be ready...${NC}"
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:5000/health > /dev/null 2>&1; then
        echo -e "${GREEN}MLflow is ready!${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for MLflow... ($attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${YELLOW}Warning: MLflow health check timed out, but continuing...${NC}"
fi
echo ""

# Run preprocessing
echo -e "${BLUE}Step 3: Running data preprocessing...${NC}"
docker-compose run --rm pipeline python -c "from pipeline.preprocess import preprocess_data; preprocess_data()"
echo ""

# Run training
echo -e "${BLUE}Step 4: Training model...${NC}"
docker-compose run --rm pipeline python pipeline/train.py
echo ""

# Run evaluation
echo -e "${BLUE}Step 5: Evaluating model...${NC}"
docker-compose run --rm pipeline python pipeline/evaluate.py
echo ""

echo -e "${GREEN}========================================"
echo "Pipeline completed successfully!"
echo "========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. View MLflow UI: http://localhost:5000"
echo "  2. Open Jupyter Lab: http://localhost:8888 (token: mlops-demo)"
echo "  3. Check metrics in: ./metrics/"
echo "  4. Check models in: ./models/"
echo ""
echo "To stop services: docker-compose down"
