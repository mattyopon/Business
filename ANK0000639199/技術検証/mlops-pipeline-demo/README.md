# MLOps Pipeline Demo - Day 2

A practical MLOps pipeline demonstration that runs entirely on your local machine using Docker Compose. This project showcases fundamental MLOps concepts including data processing, model training, evaluation, and version control.

## Project Overview

This demo implements a complete ML pipeline for predicting customer churn using a simple yet realistic dataset. The pipeline demonstrates:

- **Data Processing**: Automated data validation and preprocessing
- **Model Training**: Scikit-learn based classification model
- **Model Evaluation**: Comprehensive metrics tracking
- **Experiment Tracking**: Local MLflow server for experiment management
- **Containerization**: Fully dockerized environment
- **Jupyter Integration**: Interactive exploration notebooks

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Data      │────>│   Training  │────>│  Evaluation │
│ Processing  │     │   Pipeline  │     │   & Metrics │
└─────────────┘     └─────────────┘     └─────────────┘
       │                    │                    │
       └────────────────────┴────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   MLflow    │
                    │   Tracking  │
                    └─────────────┘
```

## Prerequisites

- Docker Desktop installed and running
- Docker Compose (included with Docker Desktop)
- At least 4GB of RAM allocated to Docker
- 2GB of free disk space

## Quick Start

### 1. Clone and Navigate

```bash
cd c:/Users/matty/coachtech/mlops-pipeline-demo
```

### 2. Start the Environment

```bash
docker-compose up -d
```

This will start:
- **MLflow Server**: http://localhost:5000 (Experiment tracking UI)
- **Jupyter Lab**: http://localhost:8888 (Token: `mlops-demo`)
- **Pipeline Container**: Runs training and evaluation

### 3. Run the Complete Pipeline

```bash
# Run the full pipeline (data processing, training, evaluation)
docker-compose run --rm pipeline python pipeline/train.py
docker-compose run --rm pipeline python pipeline/evaluate.py
```

### 4. View Results

- Open MLflow UI: http://localhost:5000
- Check model metrics and parameters
- Compare different experiment runs

### 5. Explore with Jupyter

- Open Jupyter Lab: http://localhost:8888
- Navigate to `notebooks/exploration.ipynb`
- Run the cells to explore data and results

## Project Structure

```
mlops-pipeline-demo/
├── README.md                    # This file
├── docker-compose.yml           # Service orchestration
├── Dockerfile                   # Pipeline container image
├── .gitignore                  # Git ignore rules
│
├── pipeline/                    # ML Pipeline code
│   ├── train.py                # Training script
│   ├── evaluate.py             # Evaluation script
│   ├── preprocess.py           # Data preprocessing
│   └── requirements.txt        # Python dependencies
│
├── data/                        # Data directory
│   ├── sample_data.csv         # Sample dataset
│   └── processed/              # Processed data (generated)
│
├── models/                      # Trained models (generated)
│   └── .gitkeep
│
├── metrics/                     # Evaluation metrics (generated)
│   └── .gitkeep
│
└── notebooks/                   # Jupyter notebooks
    └── exploration.ipynb       # Data exploration notebook
```

## Pipeline Components

### 1. Data Processing (`pipeline/preprocess.py`)

- Loads raw CSV data
- Handles missing values
- Encodes categorical variables
- Splits into train/test sets
- Saves processed data

### 2. Training (`pipeline/train.py`)

- Loads processed data
- Trains Random Forest classifier
- Logs parameters to MLflow
- Saves trained model
- Logs metrics (accuracy, precision, recall, F1)

### 3. Evaluation (`pipeline/evaluate.py`)

- Loads trained model
- Evaluates on test set
- Generates confusion matrix
- Calculates detailed metrics
- Logs results to MLflow

## Usage Examples

### Run Individual Components

```bash
# Data preprocessing only
docker-compose run --rm pipeline python -c "from pipeline.preprocess import preprocess_data; preprocess_data()"

# Training only
docker-compose run --rm pipeline python pipeline/train.py

# Evaluation only
docker-compose run --rm pipeline python pipeline/evaluate.py
```

### Run with Custom Parameters

```bash
# Train with different hyperparameters
docker-compose run --rm pipeline python pipeline/train.py --n-estimators 200 --max-depth 10

# Evaluate specific model
docker-compose run --rm pipeline python pipeline/evaluate.py --model-path models/model_v2.pkl
```

### Access Services

```bash
# View MLflow UI
open http://localhost:5000

# Access Jupyter Lab
open http://localhost:8888

# View container logs
docker-compose logs -f pipeline
```

## MLflow Experiment Tracking

### Key Features

- **Experiment Comparison**: Compare multiple runs side-by-side
- **Parameter Tracking**: Log hyperparameters automatically
- **Metric Tracking**: Track accuracy, precision, recall, F1
- **Model Registry**: Save and version models
- **Artifact Storage**: Store models, plots, and data

### Example Tracked Metrics

- Training accuracy
- Test accuracy
- Precision, Recall, F1-score
- Training time
- Model size
- Confusion matrix

## Data Schema

The demo uses a synthetic customer churn dataset:

| Column | Type | Description |
|--------|------|-------------|
| CustomerID | int | Unique customer identifier |
| Age | int | Customer age (18-80) |
| Tenure | int | Months as customer |
| MonthlyCharges | float | Monthly fee |
| TotalCharges | float | Total amount charged |
| Contract | string | Month-to-month, One year, Two year |
| PaymentMethod | string | Payment method type |
| Churn | int | Target variable (0=No, 1=Yes) |

## Best Practices Demonstrated

1. **Reproducibility**: Fixed random seeds, version tracking
2. **Modularity**: Separated preprocessing, training, evaluation
3. **Logging**: Comprehensive experiment tracking with MLflow
4. **Containerization**: Isolated, reproducible environment
5. **Documentation**: Clear README and code comments
6. **Version Control**: .gitignore for generated files
7. **Data Validation**: Input data checks and validation

## Troubleshooting

### Port Already in Use

```bash
# Stop existing containers
docker-compose down

# Check for processes using ports 5000 or 8888
netstat -ano | findstr :5000
netstat -ano | findstr :8888
```

### Permission Issues

```bash
# On Windows, ensure Docker has access to the drive
# Docker Desktop > Settings > Resources > File Sharing
```

### Container Won't Start

```bash
# Check logs
docker-compose logs

# Rebuild containers
docker-compose build --no-cache
docker-compose up -d
```

### Out of Memory

```bash
# Increase Docker memory limit
# Docker Desktop > Settings > Resources > Memory
# Recommended: 4GB minimum
```

## Cleanup

```bash
# Stop all containers
docker-compose down

# Remove all containers and volumes
docker-compose down -v

# Remove generated files
rm -rf data/processed/ models/*.pkl metrics/*.json
```

## Next Steps

1. **Experiment**: Try different model types (SVM, XGBoost, etc.)
2. **Hyperparameter Tuning**: Implement GridSearchCV or RandomizedSearchCV
3. **Feature Engineering**: Add new features to improve performance
4. **Model Serving**: Add FastAPI endpoint for predictions
5. **CI/CD**: Add automated testing and deployment
6. **Monitoring**: Add model drift detection
7. **Cloud Deployment**: Deploy to AWS, Azure, or GCP

## Learning Resources

- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [Scikit-learn User Guide](https://scikit-learn.org/stable/user_guide.html)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [MLOps Best Practices](https://ml-ops.org/)

## License

MIT License - Feel free to use this for learning and demonstration purposes.

## Author

Created as part of Day 2 MLOps training - MLOps Pipeline Demo

---

**Happy Learning!** If you have questions or suggestions, feel free to open an issue or contribute.
