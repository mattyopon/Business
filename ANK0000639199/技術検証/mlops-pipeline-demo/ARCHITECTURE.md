# MLOps Pipeline Demo - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Compose Environment                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │   MLflow     │    │   Jupyter    │    │   Pipeline   │    │
│  │   Server     │    │     Lab      │    │  Container   │    │
│  │              │    │              │    │              │    │
│  │ Port: 5000   │    │ Port: 8888   │    │  (Workers)   │    │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘    │
│         │                   │                   │             │
│         └───────────────────┴───────────────────┘             │
│                            │                                   │
│                            ▼                                   │
│         ┌──────────────────────────────────┐                  │
│         │    Shared Volumes (Data Store)   │                  │
│         ├──────────────────────────────────┤                  │
│         │  - mlruns/ (experiment tracking) │                  │
│         │  - models/ (trained models)      │                  │
│         │  - data/ (datasets)              │                  │
│         │  - metrics/ (evaluation results) │                  │
│         └──────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. MLflow Tracking Server

**Purpose**: Experiment tracking and model registry

**Key Features**:
- Logs hyperparameters, metrics, and artifacts
- Provides web UI for comparing experiments
- Stores model versions and metadata
- Enables reproducibility

**Technology Stack**:
- MLflow 2.9.2
- File-based backend store
- Local artifact storage

**Endpoints**:
- UI: http://localhost:5000
- API: http://mlflow:5000 (internal)

### 2. Jupyter Lab

**Purpose**: Interactive development and data exploration

**Key Features**:
- Browser-based notebook interface
- Real-time code execution
- Visualization capabilities
- Direct access to all project files

**Technology Stack**:
- JupyterLab 4.0.5
- Python 3.10
- Scientific computing stack (numpy, pandas, matplotlib, seaborn)

**Access**:
- URL: http://localhost:8888
- Token: `mlops-demo`

### 3. Pipeline Container

**Purpose**: ML pipeline execution (training, evaluation, preprocessing)

**Key Features**:
- Isolated execution environment
- Reproducible builds
- Direct MLflow integration
- Batch job processing

**Technology Stack**:
- Python 3.10
- Scikit-learn 1.3.0
- Custom pipeline scripts

**Usage**:
```bash
docker-compose run --rm pipeline python pipeline/train.py
```

## Data Flow

```
┌─────────────┐
│  Raw Data   │
│ sample_data │
│   .csv      │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Preprocessing  │
│  - Clean data   │
│  - Encode       │
│  - Split        │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Processed Data  │
│  - X_train.csv  │
│  - X_test.csv   │
│  - y_train.csv  │
│  - y_test.csv   │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│    Training     │
│  - Fit model    │
│  - Log params   │
│  - Log metrics  │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Trained Model   │
│  .pkl file      │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│   Evaluation    │
│  - Generate     │
│    metrics      │
│  - Create       │
│    visualizations│
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│    Results      │
│  - Confusion    │
│    matrix       │
│  - ROC curve    │
│  - Reports      │
└─────────────────┘
```

## MLOps Workflow

### 1. Data Preparation Phase

```python
# preprocess.py workflow
load_data()
  → validate_data()
  → clean_data()
  → encode_features()
  → split_data()
  → save_processed_data()
```

**Outputs**:
- `data/processed/X_train.csv`
- `data/processed/X_test.csv`
- `data/processed/y_train.csv`
- `data/processed/y_test.csv`
- `data/processed/encoders.pkl`
- `data/processed/scaler.pkl`

### 2. Training Phase

```python
# train.py workflow
load_processed_data()
  → train_model()
  → evaluate_model()
  → save_model()
  → log_to_mlflow()
```

**Outputs**:
- `models/churn_model.pkl`
- `models/feature_importance.csv`
- MLflow experiment run with metrics

**Logged Metrics**:
- train_accuracy, test_accuracy
- train_precision, test_precision
- train_recall, test_recall
- train_f1, test_f1
- training_time
- model_size_mb

### 3. Evaluation Phase

```python
# evaluate.py workflow
load_model_and_data()
  → generate_predictions()
  → generate_confusion_matrix()
  → generate_roc_curve()
  → generate_pr_curve()
  → calculate_business_metrics()
```

**Outputs**:
- `metrics/confusion_matrix.png`
- `metrics/roc_curve.png`
- `metrics/precision_recall_curve.png`
- `metrics/classification_report.json`
- `metrics/business_metrics.json`

## Technology Stack

### Core ML Libraries
- **scikit-learn 1.3.0**: Model training and evaluation
- **pandas 2.0.3**: Data manipulation
- **numpy 1.24.3**: Numerical computing

### Experiment Tracking
- **MLflow 2.9.2**: Experiment tracking and model registry

### Visualization
- **matplotlib 3.7.2**: Plotting library
- **seaborn 0.12.2**: Statistical visualizations

### Development Tools
- **Jupyter 1.0.0**: Interactive notebooks
- **JupyterLab 4.0.5**: Enhanced notebook interface

### Containerization
- **Docker**: Container runtime
- **Docker Compose**: Multi-container orchestration

## Networking

### Internal Network (mlops-network)

All containers communicate via Docker's internal DNS:

```yaml
mlflow:      mlflow:5000
jupyter:     jupyter:8888
pipeline:    pipeline (no exposed port)
```

### External Access

Only MLflow and Jupyter are exposed to host:

```
localhost:5000  → mlflow:5000   (MLflow UI)
localhost:8888  → jupyter:8888  (Jupyter Lab)
```

## Storage Architecture

### Volume Mounts

```
Project Directory Structure:
├── data/           → /workspace/data      (shared)
├── models/         → /workspace/models    (shared)
├── metrics/        → /workspace/metrics   (shared)
├── mlruns/         → /workspace/mlruns    (shared)
├── notebooks/      → /workspace/notebooks (shared)
└── pipeline/       → /workspace/pipeline  (shared)
```

### Data Persistence

- **Persistent**: mlruns/, models/, data/
- **Temporary**: Container filesystems
- **Shared**: All directories mounted as volumes

## Scalability Considerations

### Current Setup (Local Development)
- Single machine
- File-based storage
- SQLite backend for MLflow

### Production Recommendations
1. **MLflow**:
   - PostgreSQL/MySQL backend
   - S3/Azure Blob for artifacts
   - Load balanced servers

2. **Pipeline**:
   - Kubernetes for orchestration
   - Airflow/Kubeflow for scheduling
   - GPU support for deep learning

3. **Data Storage**:
   - Data lake (S3, Azure Data Lake)
   - Feature store (Feast, Tecton)
   - Model registry (MLflow, DVC)

## Security Best Practices

### Current Implementation
- No authentication (development only)
- Local network only
- No sensitive data

### Production Requirements
1. **Authentication**:
   - MLflow: Basic auth or OAuth
   - Jupyter: Password protection
   - API: Token-based auth

2. **Network Security**:
   - TLS/SSL encryption
   - VPN/Private network
   - Firewall rules

3. **Data Security**:
   - Encryption at rest
   - Encryption in transit
   - Access control lists

## Performance Optimization

### Current Bottlenecks
1. File-based MLflow backend (slow for many experiments)
2. Single-threaded pipeline execution
3. No caching of intermediate results

### Optimization Strategies
1. **Database Backend**: Use PostgreSQL for MLflow
2. **Parallel Processing**: Use Dask or Ray for large datasets
3. **Caching**: Cache preprocessing results
4. **GPU Acceleration**: For deep learning models

## Monitoring and Observability

### Current Capabilities
- MLflow UI for experiment tracking
- Docker logs for debugging
- Manual metric inspection

### Production Additions
1. **Application Monitoring**: Prometheus + Grafana
2. **Log Aggregation**: ELK stack or Splunk
3. **Model Monitoring**: Data drift detection
4. **Alerting**: PagerDuty or custom webhooks

## Extension Points

### Adding New Models
1. Create new training script in `pipeline/`
2. Follow existing pattern for MLflow logging
3. Update docker-compose to run new pipeline

### Adding Data Sources
1. Implement new data loader in `preprocess.py`
2. Maintain consistent output format
3. Update validation logic

### Adding Deployment
1. Create `deploy/` directory
2. Add FastAPI or Flask service
3. Containerize serving layer
4. Update docker-compose

## References

- [MLflow Documentation](https://mlflow.org/docs/latest/)
- [Scikit-learn User Guide](https://scikit-learn.org/stable/user_guide.html)
- [Docker Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [MLOps Principles](https://ml-ops.org/)
