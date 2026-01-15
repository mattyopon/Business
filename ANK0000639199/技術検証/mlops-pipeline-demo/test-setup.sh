#!/bin/bash

# MLOps Pipeline Demo - Setup Test Script
# This script verifies that all components are working correctly

set -e

echo "========================================"
echo "MLOps Pipeline Demo - Setup Test"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
tests_passed=0
tests_failed=0

# Test function
test_step() {
    echo -n "Testing: $1... "
    if eval "$2" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}FAIL${NC}"
        tests_failed=$((tests_failed + 1))
    fi
}

# 1. Check Docker is running
test_step "Docker is running" "docker info"

# 2. Check Docker Compose is available
test_step "Docker Compose is available" "docker-compose --version"

# 3. Check project structure
test_step "Project structure exists" "[ -f docker-compose.yml ] && [ -f Dockerfile ] && [ -d pipeline ]"

# 4. Check required files exist
test_step "Pipeline files exist" "[ -f pipeline/train.py ] && [ -f pipeline/evaluate.py ] && [ -f pipeline/preprocess.py ]"

# 5. Check data file exists
test_step "Sample data exists" "[ -f data/sample_data.csv ]"

# 6. Check requirements.txt exists
test_step "Requirements file exists" "[ -f pipeline/requirements.txt ]"

# 7. Check notebook exists
test_step "Jupyter notebook exists" "[ -f notebooks/exploration.ipynb ]"

# 8. Try to build Docker image
echo -n "Testing: Building Docker image... "
if docker-compose build --quiet > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}FAIL${NC}"
    tests_failed=$((tests_failed + 1))
fi

# 9. Try to start services
echo -n "Testing: Starting services... "
if docker-compose up -d > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    tests_passed=$((tests_passed + 1))

    # Wait a bit for services to start
    sleep 5

    # 10. Check if MLflow is accessible
    test_step "MLflow service is running" "docker-compose ps | grep mlflow | grep Up"

    # 11. Check if Jupyter is accessible
    test_step "Jupyter service is running" "docker-compose ps | grep jupyter | grep Up"

    # 12. Check if pipeline container exists
    test_step "Pipeline container is ready" "docker-compose ps | grep pipeline"

    # 13. Test Python imports in pipeline
    echo -n "Testing: Python dependencies... "
    if docker-compose run --rm pipeline python -c "import pandas; import sklearn; import mlflow" 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}FAIL${NC}"
        tests_failed=$((tests_failed + 1))
    fi

    # 14. Test data loading
    echo -n "Testing: Data loading... "
    if docker-compose run --rm pipeline python -c "import pandas as pd; df = pd.read_csv('data/sample_data.csv'); assert len(df) > 0" 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}FAIL${NC}"
        tests_failed=$((tests_failed + 1))
    fi

    # Clean up
    echo ""
    echo "Cleaning up test environment..."
    docker-compose down > /dev/null 2>&1
else
    echo -e "${RED}FAIL${NC}"
    tests_failed=$((tests_failed + 1))
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Tests Passed: ${GREEN}$tests_passed${NC}"
echo -e "Tests Failed: ${RED}$tests_failed${NC}"
echo ""

if [ $tests_failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed! Setup is correct.${NC}"
    echo ""
    echo "You can now run the pipeline with:"
    echo "  ./run-pipeline.sh"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the errors above.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. Ensure Docker Desktop is running"
    echo "  2. Check Docker has enough memory (4GB minimum)"
    echo "  3. Rebuild containers: docker-compose build --no-cache"
    exit 1
fi
