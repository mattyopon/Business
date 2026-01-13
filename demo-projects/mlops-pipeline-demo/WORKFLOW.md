# MLOps Pipeline Demo - Workflow Guide

## Complete Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER ACTIONS                                │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │
                    ┌───────────┴───────────┐
                    │  docker-compose up -d │
                    └───────────┬───────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      DOCKER ENVIRONMENT                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐       │
│  │  MLflow Server │  │  Jupyter Lab   │  │Pipeline Worker │       │
│  │   Port: 5000   │  │   Port: 8888   │  │   (on-demand)  │       │
│  └────────────────┘  └────────────────┘  └────────────────┘       │
│           │                  │                    │                 │
│           └──────────────────┴────────────────────┘                 │
│                              │                                       │
│                    ┌─────────▼─────────┐                           │
│                    │  Shared Volumes   │                           │
│                    │  - data/          │                           │
│                    │  - models/        │                           │
│                    │  - mlruns/        │                           │
│                    │  - metrics/       │                           │
│                    └───────────────────┘                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ML PIPELINE                                  │
└─────────────────────────────────────────────────────────────────────┘

        ┌──────────────────────────────────────────┐
        │  STEP 1: Data Preprocessing              │
        │  Command: python pipeline/preprocess.py  │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  Load raw data (sample_data.csv)         │
        │  ↓                                        │
        │  Validate data integrity                  │
        │  ↓                                        │
        │  Clean data (handle nulls, outliers)     │
        │  ↓                                        │
        │  Encode categorical features              │
        │  ↓                                        │
        │  Scale numerical features                 │
        │  ↓                                        │
        │  Split train/test sets (80/20)           │
        │  ↓                                        │
        │  Save processed data                      │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  OUTPUT:                                  │
        │  - data/processed/X_train.csv            │
        │  - data/processed/X_test.csv             │
        │  - data/processed/y_train.csv            │
        │  - data/processed/y_test.csv             │
        │  - data/processed/encoders.pkl           │
        │  - data/processed/scaler.pkl             │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  STEP 2: Model Training                  │
        │  Command: python pipeline/train.py       │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  Load processed data                      │
        │  ↓                                        │
        │  Initialize Random Forest classifier      │
        │  ↓                                        │
        │  Train model on training set             │
        │  ↓                                        │
        │  Evaluate on train & test sets           │
        │  ↓                                        │
        │  Calculate feature importance             │
        │  ↓                                        │
        │  Save model to disk                       │
        │  ↓                                        │
        │  Log everything to MLflow                │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  MLflow Logging:                         │
        │  - Hyperparameters (n_estimators, etc.)  │
        │  - Metrics (accuracy, precision, etc.)   │
        │  - Model artifact                         │
        │  - Feature importance                     │
        │  - Training time                          │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  OUTPUT:                                  │
        │  - models/churn_model.pkl                │
        │  - models/feature_importance.csv         │
        │  - MLflow experiment run                 │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  STEP 3: Model Evaluation                │
        │  Command: python pipeline/evaluate.py    │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  Load trained model                       │
        │  ↓                                        │
        │  Load test data                           │
        │  ↓                                        │
        │  Generate predictions                     │
        │  ↓                                        │
        │  Create confusion matrix                  │
        │  ↓                                        │
        │  Generate ROC curve                       │
        │  ↓                                        │
        │  Generate precision-recall curve          │
        │  ↓                                        │
        │  Calculate business metrics               │
        │  ↓                                        │
        │  Save all visualizations                  │
        │  ↓                                        │
        │  Log to MLflow                            │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  OUTPUT:                                  │
        │  - metrics/confusion_matrix.png          │
        │  - metrics/roc_curve.png                 │
        │  - metrics/precision_recall_curve.png    │
        │  - metrics/classification_report.json    │
        │  - metrics/business_metrics.json         │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  STEP 4: Analysis & Exploration          │
        │  Tool: Jupyter Lab                       │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │  Open notebooks/exploration.ipynb        │
        │  ↓                                        │
        │  Load data and model                      │
        │  ↓                                        │
        │  Visualize data distributions             │
        │  ↓                                        │
        │  Analyze feature importance               │
        │  ↓                                        │
        │  Compare experiments in MLflow           │
        │  ↓                                        │
        │  Generate custom visualizations           │
        └──────────────────────────────────────────┘
```

## Detailed Step-by-Step Workflow

### Phase 1: Environment Setup

```
User Action → Start Docker Desktop
           ↓
User Action → Run: docker-compose up -d
           ↓
Docker     → Pull base images (python:3.10-slim, mlflow:v2.9.2)
           ↓
Docker     → Build custom pipeline image
           ↓
Docker     → Create network (mlops-network)
           ↓
Docker     → Start MLflow container
           ↓
Docker     → Start Jupyter container
           ↓
Docker     → Start Pipeline container (idle)
           ↓
System     → Ready for pipeline execution
```

### Phase 2: Data Preprocessing

```
User Action → docker-compose run --rm pipeline python pipeline/preprocess.py
           ↓
Pipeline   → Load data/sample_data.csv (100 rows, 8 columns)
           ↓
Pipeline   → Validate columns and data types
           ↓
Pipeline   → Check for missing values
           ↓
Pipeline   → Clean data:
           │  - Remove duplicates
           │  - Handle outliers in Age
           │  - Fill missing TotalCharges
           ↓
Pipeline   → Encode categorical variables:
           │  - Contract (3 categories → 0,1,2)
           │  - PaymentMethod (4 categories → 0,1,2,3)
           ↓
Pipeline   → Scale numerical features:
           │  - Age, Tenure, MonthlyCharges, TotalCharges
           │  - Using StandardScaler (mean=0, std=1)
           ↓
Pipeline   → Split data:
           │  - Training: 80% (stratified by Churn)
           │  - Testing: 20% (stratified by Churn)
           ↓
Pipeline   → Save to data/processed/:
           │  - X_train.csv (features)
           │  - y_train.csv (labels)
           │  - X_test.csv (features)
           │  - y_test.csv (labels)
           │  - encoders.pkl (for inference)
           │  - scaler.pkl (for inference)
           ↓
Output     → Preprocessing complete
```

### Phase 3: Model Training

```
User Action → docker-compose run --rm pipeline python pipeline/train.py
           ↓
Pipeline   → Connect to MLflow server (http://mlflow:5000)
           ↓
Pipeline   → Create/Get experiment: "churn-prediction"
           ↓
Pipeline   → Start MLflow run
           ↓
Pipeline   → Load processed data from data/processed/
           ↓
Pipeline   → Initialize model:
           │  RandomForestClassifier(
           │    n_estimators=100,
           │    max_depth=10,
           │    min_samples_split=2,
           │    min_samples_leaf=1,
           │    random_state=42,
           │    n_jobs=-1
           │  )
           ↓
Pipeline   → Train model on X_train, y_train
           │  - Takes ~2 seconds for 100 samples
           │  - Creates 100 decision trees
           │  - Each tree uses bootstrap sampling
           ↓
Pipeline   → Evaluate on training set:
           │  - Accuracy
           │  - Precision
           │  - Recall
           │  - F1 Score
           ↓
Pipeline   → Evaluate on test set:
           │  - Same metrics as training
           │  - Detect overfitting
           ↓
Pipeline   → Calculate feature importance:
           │  - Based on Gini impurity
           │  - Normalized to sum=1.0
           ↓
Pipeline   → Log to MLflow:
           │  - Hyperparameters
           │  - Training metrics
           │  - Test metrics
           │  - Training time
           │  - Model size
           │  - Feature importance CSV
           │  - Model artifact
           ↓
Pipeline   → Save model to models/churn_model.pkl
           ↓
Pipeline   → End MLflow run
           ↓
Output     → Training complete
           │  View at: http://localhost:5000
```

### Phase 4: Model Evaluation

```
User Action → docker-compose run --rm pipeline python pipeline/evaluate.py
           ↓
Pipeline   → Load model from models/churn_model.pkl
           ↓
Pipeline   → Load test data from data/processed/
           ↓
Pipeline   → Generate predictions:
           │  - y_pred (class labels: 0 or 1)
           │  - y_pred_proba (probabilities: 0.0 to 1.0)
           ↓
Pipeline   → Create confusion matrix:
           │  ┌──────────────────┐
           │  │  TN  │  FP       │
           │  ├──────┼───────────┤
           │  │  FN  │  TP       │
           │  └──────────────────┘
           │  - Save as PNG with heatmap
           ↓
Pipeline   → Generate ROC curve:
           │  - Calculate TPR vs FPR at different thresholds
           │  - Calculate AUC (Area Under Curve)
           │  - Plot curve with baseline
           │  - Save as PNG
           ↓
Pipeline   → Generate Precision-Recall curve:
           │  - Calculate precision vs recall
           │  - Useful for imbalanced datasets
           │  - Save as PNG
           ↓
Pipeline   → Generate classification report:
           │  - Per-class metrics
           │  - Support (number of samples)
           │  - Macro and weighted averages
           │  - Save as JSON
           ↓
Pipeline   → Calculate business metrics:
           │  - Total customers analyzed
           │  - Actual churners
           │  - Predicted churners
           │  - Correctly identified
           │  - Missed churners (false negatives)
           │  - False alarms (false positives)
           │  - Churn detection rate
           │  - False alarm rate
           │  - Save as JSON
           ↓
Pipeline   → Start MLflow evaluation run
           ↓
Pipeline   → Log all artifacts to MLflow:
           │  - Confusion matrix PNG
           │  - ROC curve PNG
           │  - PR curve PNG
           │  - Classification report JSON
           │  - Business metrics JSON
           │  - AUC score
           ↓
Pipeline   → End MLflow run
           ↓
Output     → Evaluation complete
           │  Metrics saved to metrics/
           │  View in MLflow: http://localhost:5000
```

### Phase 5: Interactive Exploration

```
User Action → Open browser: http://localhost:8888
           ↓
Browser    → Jupyter Lab login (token: mlops-demo)
           ↓
User       → Open notebooks/exploration.ipynb
           ↓
Notebook   → Import libraries (pandas, matplotlib, seaborn)
           ↓
Notebook   → Load raw data (sample_data.csv)
           ↓
Notebook   → Display data summary:
           │  - Shape, columns, dtypes
           │  - Statistical summary
           │  - Missing values
           ↓
Notebook   → Visualize churn distribution:
           │  - Count plot
           │  - Percentage plot
           ↓
Notebook   → Analyze features:
           │  - Age distribution by churn
           │  - Tenure vs Monthly Charges scatter
           │  - Contract type vs churn rate
           │  - Correlation matrix
           ↓
Notebook   → Load trained model
           ↓
Notebook   → Display feature importance:
           │  - Horizontal bar chart
           │  - Sorted by importance
           ↓
Notebook   → Show model predictions:
           │  - Classification report
           │  - Confusion matrix
           ↓
Notebook   → Connect to MLflow
           ↓
Notebook   → Display experiment runs:
           │  - Run IDs
           │  - Parameters
           │  - Metrics
           │  - Comparisons
           ↓
User       → Experiment with different visualizations
           │  - Custom plots
           │  - Statistical tests
           │  - Feature engineering ideas
```

### Phase 6: Experiment Tracking (MLflow)

```
Browser    → Open http://localhost:5000
           ↓
MLflow UI  → Show experiments list
           │  - churn-prediction
           │  - Default
           ↓
User       → Click "churn-prediction" experiment
           ↓
MLflow UI  → Show all runs:
           │  - Run name
           │  - Start time
           │  - Duration
           │  - Status
           │  - Metrics preview
           ↓
User       → Click on a specific run
           ↓
MLflow UI  → Show run details:
           │
           │  Parameters:
           │    n_estimators: 100
           │    max_depth: 10
           │    min_samples_split: 2
           │    min_samples_leaf: 1
           │    random_state: 42
           │    train_size: 80
           │    test_size: 20
           │
           │  Metrics:
           │    train_accuracy: 0.95
           │    test_accuracy: 0.85
           │    train_f1: 0.93
           │    test_f1: 0.82
           │    training_time: 2.1s
           │    model_size_mb: 0.15
           │    roc_auc: 0.88
           │
           │  Artifacts:
           │    - model/
           │    - feature_importance.csv
           │    - confusion_matrix.png
           │    - roc_curve.png
           │    - classification_report.json
           ↓
User       → Compare multiple runs
           ↓
MLflow UI  → Show comparison table:
           │  - Side-by-side parameters
           │  - Metric differences
           │  - Best performing runs
           ↓
User       → Download model or artifacts
```

## Workflow Variations

### Quick Test Run
```bash
# Minimal workflow to verify everything works
docker-compose up -d
docker-compose run --rm pipeline python -c "import pandas as pd; print('OK')"
docker-compose down
```

### Full Automated Run
```bash
# Complete pipeline with one command
./run-pipeline.sh  # or run-pipeline.bat on Windows
```

### Custom Hyperparameters
```bash
# Train with different parameters
docker-compose run --rm pipeline python pipeline/train.py \
  --n-estimators 200 \
  --max-depth 15 \
  --min-samples-split 5
```

### Multiple Experiments
```bash
# Run multiple experiments to compare
for depth in 5 10 15 20; do
  docker-compose run --rm pipeline python pipeline/train.py \
    --max-depth $depth \
    --experiment-name "depth-tuning"
done
```

### Development Workflow
```bash
# 1. Start services
docker-compose up -d

# 2. Work in Jupyter
# Open http://localhost:8888

# 3. Test changes
docker-compose run --rm pipeline python pipeline/train.py

# 4. Check MLflow
# Open http://localhost:5000

# 5. Iterate
# Repeat steps 2-4

# 6. Clean up
docker-compose down
```

## Data Flow Through Pipeline

```
Raw Data (CSV)
  │
  │ [100 rows × 8 columns]
  │
  ▼
Validation
  │ - Check schema
  │ - Check data types
  │ - Check for nulls
  ▼
Cleaning
  │ - Remove duplicates
  │ - Handle outliers
  │ - Fill missing values
  │ [~100 rows remain]
  ▼
Feature Engineering
  │ - Encode: Contract → [0,1,2]
  │ - Encode: PaymentMethod → [0,1,2,3]
  │ - Scale: Age, Tenure, Charges → [-2, +2]
  │ [100 rows × 6 features]
  ▼
Train/Test Split
  │
  ├─→ Training Set (80%)
  │   [80 rows × 6 features]
  │
  └─→ Test Set (20%)
      [20 rows × 6 features]
      │
      ▼
Model Training
  │ Random Forest (100 trees)
  │ Train on 80 samples
  │ Validate on 20 samples
  ▼
Model (PKL file)
  │ [~150 KB]
  │
  ├─→ Predictions
  │   [20 predictions]
  │
  └─→ Metrics
      - Accuracy: ~85%
      - Precision: ~82%
      - Recall: ~78%
      - F1: ~80%
```

## Success Metrics

### Pipeline Execution
- Preprocessing: < 5 seconds
- Training: < 5 seconds
- Evaluation: < 5 seconds
- Total: < 15 seconds

### Model Performance
- Test Accuracy: > 80%
- ROC AUC: > 0.80
- F1 Score: > 0.75

### System Health
- All containers: Running
- MLflow UI: Accessible
- Jupyter Lab: Accessible
- No error logs

---

**Next Steps**: Follow the workflow above to run your first experiment!
