@echo off
REM MLOps Pipeline Demo - Quick Start Script (Windows)
REM This script runs the complete ML pipeline

echo ========================================
echo MLOps Pipeline Demo - Quick Start
echo ========================================
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

echo Step 1: Starting services...
docker-compose up -d
echo.

echo Step 2: Waiting for MLflow to be ready...
timeout /t 10 /nobreak >nul
echo MLflow should be ready!
echo.

echo Step 3: Running data preprocessing...
docker-compose run --rm pipeline python -c "from pipeline.preprocess import preprocess_data; preprocess_data()"
echo.

echo Step 4: Training model...
docker-compose run --rm pipeline python pipeline/train.py
echo.

echo Step 5: Evaluating model...
docker-compose run --rm pipeline python pipeline/evaluate.py
echo.

echo ========================================
echo Pipeline completed successfully!
echo ========================================
echo.
echo Next steps:
echo   1. View MLflow UI: http://localhost:5000
echo   2. Open Jupyter Lab: http://localhost:8888 (token: mlops-demo)
echo   3. Check metrics in: .\metrics\
echo   4. Check models in: .\models\
echo.
echo To stop services: docker-compose down
pause
