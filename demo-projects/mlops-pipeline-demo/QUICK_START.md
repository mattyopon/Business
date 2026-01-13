# Quick Start Guide - MLOps Pipeline Demo

Get started in 5 minutes!

## Prerequisites

- Docker Desktop installed and running
- 4GB RAM allocated to Docker
- Internet connection (for first-time setup)

## Option 1: Automated Script (Recommended)

### Windows
```bash
cd c:/Users/matty/coachtech/mlops-pipeline-demo
run-pipeline.bat
```

### Linux/Mac
```bash
cd c:/Users/matty/coachtech/mlops-pipeline-demo
chmod +x run-pipeline.sh
./run-pipeline.sh
```

## Option 2: Manual Steps

### 1. Start Services
```bash
docker-compose up -d
```

Wait 10-15 seconds for services to initialize.

### 2. Run Pipeline
```bash
# Preprocessing
docker-compose run --rm pipeline python -c "from pipeline.preprocess import preprocess_data; preprocess_data()"

# Training
docker-compose run --rm pipeline python pipeline/train.py

# Evaluation
docker-compose run --rm pipeline python pipeline/evaluate.py
```

### 3. Access Services

- **MLflow UI**: http://localhost:5000
- **Jupyter Lab**: http://localhost:8888 (token: `mlops-demo`)

## Verify Installation

### Check Services are Running
```bash
docker-compose ps
```

You should see 3 services running:
- mlops-mlflow
- mlops-jupyter
- mlops-pipeline

### Test Pipeline
```bash
# Quick test
docker-compose run --rm pipeline python -c "import pandas as pd; print('Pipeline works!')"
```

## Common Issues

### Port Already in Use
```bash
# Stop containers
docker-compose down

# Check what's using port 5000
netstat -ano | findstr :5000

# Kill the process or change port in docker-compose.yml
```

### Docker Not Running
```bash
# Start Docker Desktop manually
# Or run from command line:
"C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

### Services Not Starting
```bash
# Check logs
docker-compose logs mlflow
docker-compose logs jupyter
docker-compose logs pipeline

# Rebuild if needed
docker-compose build --no-cache
docker-compose up -d
```

### Out of Memory
```bash
# Increase Docker memory
# Docker Desktop > Settings > Resources > Memory
# Set to at least 4GB
```

## Quick Commands

```bash
# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Restart services
docker-compose restart

# Remove everything (fresh start)
docker-compose down -v
rm -rf data/processed/ models/*.pkl metrics/*.json mlruns/

# Run custom training
docker-compose run --rm pipeline python pipeline/train.py --n-estimators 200 --max-depth 15
```

## Next Steps

1. Open Jupyter Lab and run `notebooks/exploration.ipynb`
2. View experiment results in MLflow UI
3. Modify hyperparameters in `pipeline/train.py`
4. Add your own data to `data/` directory
5. Experiment with different models

## Getting Help

- Check the main README.md for detailed documentation
- View logs: `docker-compose logs`
- Check Docker: `docker ps` and `docker stats`

## Clean Up

```bash
# Stop containers
docker-compose down

# Remove volumes (keeps code, removes data)
docker-compose down -v

# Remove images
docker-compose down --rmi all
```

---

**Happy Learning!** For detailed documentation, see README.md
