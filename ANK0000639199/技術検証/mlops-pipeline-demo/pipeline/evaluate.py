"""
Model Evaluation Module

This module handles detailed model evaluation and generates evaluation reports.
"""

import os
import json
import argparse
import pandas as pd
import numpy as np
import joblib
import mlflow
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import (
    confusion_matrix, classification_report,
    roc_curve, auc, precision_recall_curve
)


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Evaluate ML model')
    parser.add_argument('--model-path', type=str, default='models/churn_model.pkl',
                       help='Path to trained model')
    parser.add_argument('--data-dir', type=str, default='data/processed',
                       help='Directory containing processed data')
    parser.add_argument('--output-dir', type=str, default='metrics',
                       help='Directory to save evaluation results')
    return parser.parse_args()


def load_model_and_data(model_path, data_dir):
    """
    Load trained model and test data.

    Args:
        model_path: Path to trained model
        data_dir: Directory containing processed data

    Returns:
        tuple: (model, X_test, y_test)
    """
    print(f"Loading model from {model_path}...")
    model = joblib.load(model_path)

    print(f"Loading test data from {data_dir}...")
    X_test = pd.read_csv(f'{data_dir}/X_test.csv')
    y_test = pd.read_csv(f'{data_dir}/y_test.csv').values.ravel()

    print(f"Model loaded: {type(model).__name__}")
    print(f"Test set: {X_test.shape}")

    return model, X_test, y_test


def generate_confusion_matrix(y_true, y_pred, output_dir):
    """
    Generate and save confusion matrix visualization.

    Args:
        y_true: True labels
        y_pred: Predicted labels
        output_dir: Directory to save plot

    Returns:
        Path to saved plot
    """
    print("Generating confusion matrix...")

    cm = confusion_matrix(y_true, y_pred)

    plt.figure(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=['No Churn', 'Churn'],
                yticklabels=['No Churn', 'Churn'])
    plt.title('Confusion Matrix')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')

    output_path = f'{output_dir}/confusion_matrix.png'
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()

    print(f"Confusion matrix saved to {output_path}")
    return output_path


def generate_roc_curve(y_true, y_pred_proba, output_dir):
    """
    Generate and save ROC curve.

    Args:
        y_true: True labels
        y_pred_proba: Predicted probabilities
        output_dir: Directory to save plot

    Returns:
        tuple: (Path to saved plot, AUC score)
    """
    print("Generating ROC curve...")

    fpr, tpr, thresholds = roc_curve(y_true, y_pred_proba)
    roc_auc = auc(fpr, tpr)

    plt.figure(figsize=(8, 6))
    plt.plot(fpr, tpr, color='darkorange', lw=2,
             label=f'ROC curve (AUC = {roc_auc:.2f})')
    plt.plot([0, 1], [0, 1], color='navy', lw=2, linestyle='--',
             label='Random Classifier')
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.05])
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate')
    plt.title('Receiver Operating Characteristic (ROC) Curve')
    plt.legend(loc="lower right")
    plt.grid(alpha=0.3)

    output_path = f'{output_dir}/roc_curve.png'
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()

    print(f"ROC curve saved to {output_path}")
    print(f"AUC Score: {roc_auc:.4f}")

    return output_path, roc_auc


def generate_precision_recall_curve(y_true, y_pred_proba, output_dir):
    """
    Generate and save precision-recall curve.

    Args:
        y_true: True labels
        y_pred_proba: Predicted probabilities
        output_dir: Directory to save plot

    Returns:
        Path to saved plot
    """
    print("Generating precision-recall curve...")

    precision, recall, thresholds = precision_recall_curve(y_true, y_pred_proba)

    plt.figure(figsize=(8, 6))
    plt.plot(recall, precision, color='darkgreen', lw=2)
    plt.xlabel('Recall')
    plt.ylabel('Precision')
    plt.title('Precision-Recall Curve')
    plt.grid(alpha=0.3)

    output_path = f'{output_dir}/precision_recall_curve.png'
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()

    print(f"Precision-recall curve saved to {output_path}")
    return output_path


def generate_classification_report(y_true, y_pred, output_dir):
    """
    Generate and save detailed classification report.

    Args:
        y_true: True labels
        y_pred: Predicted labels
        output_dir: Directory to save report

    Returns:
        tuple: (Path to saved report, report dict)
    """
    print("Generating classification report...")

    report = classification_report(y_true, y_pred,
                                   target_names=['No Churn', 'Churn'],
                                   output_dict=True)

    # Print report
    print("\n" + "=" * 60)
    print("CLASSIFICATION REPORT")
    print("=" * 60)
    print(classification_report(y_true, y_pred,
                               target_names=['No Churn', 'Churn']))

    # Save as JSON
    output_path = f'{output_dir}/classification_report.json'
    with open(output_path, 'w') as f:
        json.dump(report, f, indent=2)

    print(f"Classification report saved to {output_path}")
    return output_path, report


def calculate_business_metrics(y_true, y_pred, y_pred_proba):
    """
    Calculate business-relevant metrics.

    Args:
        y_true: True labels
        y_pred: Predicted labels
        y_pred_proba: Predicted probabilities

    Returns:
        Dictionary of business metrics
    """
    print("Calculating business metrics...")

    cm = confusion_matrix(y_true, y_pred)
    tn, fp, fn, tp = cm.ravel()

    # Calculate metrics
    total_customers = len(y_true)
    actual_churners = y_true.sum()
    predicted_churners = y_pred.sum()

    # True positive rate (how many actual churners we caught)
    churn_detection_rate = tp / actual_churners if actual_churners > 0 else 0

    # False positive rate (how many non-churners we incorrectly flagged)
    false_alarm_rate = fp / (fp + tn) if (fp + tn) > 0 else 0

    # Precision (of those we flagged, how many actually churned)
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0

    metrics = {
        'total_customers': int(total_customers),
        'actual_churners': int(actual_churners),
        'predicted_churners': int(predicted_churners),
        'correctly_identified_churners': int(tp),
        'missed_churners': int(fn),
        'false_alarms': int(fp),
        'churn_detection_rate': float(churn_detection_rate),
        'false_alarm_rate': float(false_alarm_rate),
        'precision': float(precision)
    }

    print("\nBusiness Metrics:")
    print(f"  Total Customers: {metrics['total_customers']}")
    print(f"  Actual Churners: {metrics['actual_churners']}")
    print(f"  Predicted Churners: {metrics['predicted_churners']}")
    print(f"  Correctly Identified: {metrics['correctly_identified_churners']}")
    print(f"  Missed Churners: {metrics['missed_churners']}")
    print(f"  False Alarms: {metrics['false_alarms']}")
    print(f"  Churn Detection Rate: {metrics['churn_detection_rate']:.2%}")
    print(f"  False Alarm Rate: {metrics['false_alarm_rate']:.2%}")
    print(f"  Precision: {metrics['precision']:.2%}")

    return metrics


def main():
    """Main evaluation pipeline."""
    args = parse_args()

    print("=" * 60)
    print("STARTING MODEL EVALUATION PIPELINE")
    print("=" * 60)

    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)

    # Set MLflow tracking URI
    mlflow_uri = os.getenv('MLFLOW_TRACKING_URI', 'http://mlflow:5000')
    mlflow.set_tracking_uri(mlflow_uri)

    # Load model and data
    model, X_test, y_test = load_model_and_data(args.model_path, args.data_dir)

    # Generate predictions
    print("\nGenerating predictions...")
    y_pred = model.predict(X_test)
    y_pred_proba = model.predict_proba(X_test)[:, 1]

    # Start MLflow run for evaluation
    with mlflow.start_run(run_name="evaluation"):
        # Generate confusion matrix
        cm_path = generate_confusion_matrix(y_test, y_pred, args.output_dir)
        mlflow.log_artifact(cm_path)

        # Generate ROC curve
        roc_path, roc_auc = generate_roc_curve(y_test, y_pred_proba, args.output_dir)
        mlflow.log_artifact(roc_path)
        mlflow.log_metric('roc_auc', roc_auc)

        # Generate precision-recall curve
        pr_path = generate_precision_recall_curve(y_test, y_pred_proba, args.output_dir)
        mlflow.log_artifact(pr_path)

        # Generate classification report
        report_path, report_dict = generate_classification_report(
            y_test, y_pred, args.output_dir
        )
        mlflow.log_artifact(report_path)

        # Calculate business metrics
        business_metrics = calculate_business_metrics(y_test, y_pred, y_pred_proba)

        # Save business metrics
        business_metrics_path = f'{args.output_dir}/business_metrics.json'
        with open(business_metrics_path, 'w') as f:
            json.dump(business_metrics, f, indent=2)
        mlflow.log_artifact(business_metrics_path)

        # Log key metrics to MLflow
        mlflow.log_metrics({
            'churn_detection_rate': business_metrics['churn_detection_rate'],
            'false_alarm_rate': business_metrics['false_alarm_rate']
        })

    print("\n" + "=" * 60)
    print("EVALUATION PIPELINE COMPLETED SUCCESSFULLY")
    print("=" * 60)
    print(f"\nView results at: {mlflow_uri}")
    print(f"Evaluation artifacts saved to: {args.output_dir}")


if __name__ == '__main__':
    main()
