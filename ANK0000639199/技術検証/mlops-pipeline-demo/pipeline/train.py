"""
Model Training Module

This module handles model training with MLflow experiment tracking.
"""

import os
import time
import argparse
import pandas as pd
import numpy as np
import joblib
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from preprocess import preprocess_data


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Train ML model')
    parser.add_argument('--n-estimators', type=int, default=100,
                       help='Number of trees in random forest')
    parser.add_argument('--max-depth', type=int, default=10,
                       help='Maximum depth of trees')
    parser.add_argument('--min-samples-split', type=int, default=2,
                       help='Minimum samples required to split node')
    parser.add_argument('--min-samples-leaf', type=int, default=1,
                       help='Minimum samples required at leaf node')
    parser.add_argument('--random-state', type=int, default=42,
                       help='Random state for reproducibility')
    parser.add_argument('--experiment-name', type=str, default='churn-prediction',
                       help='MLflow experiment name')
    return parser.parse_args()


def load_processed_data(data_dir='data/processed'):
    """
    Load preprocessed data.

    Args:
        data_dir: Directory containing processed data

    Returns:
        tuple: (X_train, X_test, y_train, y_test)
    """
    print(f"Loading processed data from {data_dir}...")

    # Check if processed data exists
    if not os.path.exists(f'{data_dir}/X_train.csv'):
        print("Processed data not found. Running preprocessing pipeline...")
        preprocess_data()

    X_train = pd.read_csv(f'{data_dir}/X_train.csv')
    X_test = pd.read_csv(f'{data_dir}/X_test.csv')
    y_train = pd.read_csv(f'{data_dir}/y_train.csv').values.ravel()
    y_test = pd.read_csv(f'{data_dir}/y_test.csv').values.ravel()

    print(f"Loaded training set: {X_train.shape}")
    print(f"Loaded test set: {X_test.shape}")

    return X_train, X_test, y_train, y_test


def train_model(X_train, y_train, hyperparameters):
    """
    Train Random Forest classifier.

    Args:
        X_train: Training features
        y_train: Training labels
        hyperparameters: Dictionary of hyperparameters

    Returns:
        Trained model
    """
    print("Training Random Forest model...")
    print(f"Hyperparameters: {hyperparameters}")

    start_time = time.time()

    model = RandomForestClassifier(
        n_estimators=hyperparameters['n_estimators'],
        max_depth=hyperparameters['max_depth'],
        min_samples_split=hyperparameters['min_samples_split'],
        min_samples_leaf=hyperparameters['min_samples_leaf'],
        random_state=hyperparameters['random_state'],
        n_jobs=-1,
        verbose=0
    )

    model.fit(X_train, y_train)

    training_time = time.time() - start_time
    print(f"Training completed in {training_time:.2f} seconds")

    return model, training_time


def evaluate_model(model, X_train, y_train, X_test, y_test):
    """
    Evaluate model performance on train and test sets.

    Args:
        model: Trained model
        X_train, y_train: Training data
        X_test, y_test: Test data

    Returns:
        Dictionary of metrics
    """
    print("Evaluating model...")

    # Training predictions
    y_train_pred = model.predict(X_train)
    train_accuracy = accuracy_score(y_train, y_train_pred)
    train_precision = precision_score(y_train, y_train_pred)
    train_recall = recall_score(y_train, y_train_pred)
    train_f1 = f1_score(y_train, y_train_pred)

    # Test predictions
    y_test_pred = model.predict(X_test)
    test_accuracy = accuracy_score(y_test, y_test_pred)
    test_precision = precision_score(y_test, y_test_pred)
    test_recall = recall_score(y_test, y_test_pred)
    test_f1 = f1_score(y_test, y_test_pred)

    metrics = {
        'train_accuracy': train_accuracy,
        'train_precision': train_precision,
        'train_recall': train_recall,
        'train_f1': train_f1,
        'test_accuracy': test_accuracy,
        'test_precision': test_precision,
        'test_recall': test_recall,
        'test_f1': test_f1
    }

    print("\nTraining Metrics:")
    print(f"  Accuracy:  {train_accuracy:.4f}")
    print(f"  Precision: {train_precision:.4f}")
    print(f"  Recall:    {train_recall:.4f}")
    print(f"  F1 Score:  {train_f1:.4f}")

    print("\nTest Metrics:")
    print(f"  Accuracy:  {test_accuracy:.4f}")
    print(f"  Precision: {test_precision:.4f}")
    print(f"  Recall:    {test_recall:.4f}")
    print(f"  F1 Score:  {test_f1:.4f}")

    return metrics


def get_feature_importance(model, feature_names):
    """
    Get feature importance from trained model.

    Args:
        model: Trained model
        feature_names: List of feature names

    Returns:
        DataFrame with feature importance
    """
    importance_df = pd.DataFrame({
        'feature': feature_names,
        'importance': model.feature_importances_
    }).sort_values('importance', ascending=False)

    print("\nTop 5 Important Features:")
    for idx, row in importance_df.head().iterrows():
        print(f"  {row['feature']}: {row['importance']:.4f}")

    return importance_df


def save_model(model, model_path='models/churn_model.pkl'):
    """
    Save trained model to disk.

    Args:
        model: Trained model
        model_path: Path to save model
    """
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    joblib.dump(model, model_path)
    print(f"\nModel saved to {model_path}")
    return model_path


def main():
    """Main training pipeline."""
    args = parse_args()

    print("=" * 60)
    print("STARTING MODEL TRAINING PIPELINE")
    print("=" * 60)

    # Set MLflow tracking URI
    mlflow_uri = os.getenv('MLFLOW_TRACKING_URI', 'http://mlflow:5000')
    mlflow.set_tracking_uri(mlflow_uri)
    print(f"\nMLflow Tracking URI: {mlflow_uri}")

    # Set experiment
    mlflow.set_experiment(args.experiment_name)

    # Load data
    X_train, X_test, y_train, y_test = load_processed_data()

    # Prepare hyperparameters
    hyperparameters = {
        'n_estimators': args.n_estimators,
        'max_depth': args.max_depth,
        'min_samples_split': args.min_samples_split,
        'min_samples_leaf': args.min_samples_leaf,
        'random_state': args.random_state
    }

    # Start MLflow run
    with mlflow.start_run():
        # Log parameters
        mlflow.log_params(hyperparameters)
        mlflow.log_param('train_size', len(X_train))
        mlflow.log_param('test_size', len(X_test))

        # Train model
        model, training_time = train_model(X_train, y_train, hyperparameters)
        mlflow.log_metric('training_time', training_time)

        # Evaluate model
        metrics = evaluate_model(model, X_train, y_train, X_test, y_test)
        mlflow.log_metrics(metrics)

        # Get feature importance
        feature_importance = get_feature_importance(model, X_train.columns.tolist())

        # Save feature importance as artifact
        importance_path = 'models/feature_importance.csv'
        feature_importance.to_csv(importance_path, index=False)
        mlflow.log_artifact(importance_path)

        # Save model
        model_path = save_model(model)

        # Log model with MLflow
        mlflow.sklearn.log_model(model, "model")

        # Log model file size
        model_size_mb = os.path.getsize(model_path) / (1024 * 1024)
        mlflow.log_metric('model_size_mb', model_size_mb)

        print(f"\nMLflow Run ID: {mlflow.active_run().info.run_id}")

    print("\n" + "=" * 60)
    print("TRAINING PIPELINE COMPLETED SUCCESSFULLY")
    print("=" * 60)
    print(f"\nView results at: {mlflow_uri}")


if __name__ == '__main__':
    main()
