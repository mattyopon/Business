"""
Data Preprocessing Module

This module handles data loading, cleaning, and preprocessing for the ML pipeline.
"""

import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler
import joblib


def load_data(data_path='data/sample_data.csv'):
    """
    Load raw data from CSV file.

    Args:
        data_path: Path to the CSV file

    Returns:
        DataFrame: Loaded data
    """
    print(f"Loading data from {data_path}...")
    df = pd.read_csv(data_path)
    print(f"Loaded {len(df)} rows and {len(df.columns)} columns")
    return df


def validate_data(df):
    """
    Validate data quality and integrity.

    Args:
        df: Input DataFrame

    Raises:
        ValueError: If data validation fails
    """
    print("Validating data...")

    # Check for required columns
    required_columns = ['Age', 'Tenure', 'MonthlyCharges', 'TotalCharges',
                       'Contract', 'PaymentMethod', 'Churn']
    missing_columns = set(required_columns) - set(df.columns)
    if missing_columns:
        raise ValueError(f"Missing required columns: {missing_columns}")

    # Check for null values
    null_counts = df.isnull().sum()
    if null_counts.sum() > 0:
        print(f"Warning: Found null values:\n{null_counts[null_counts > 0]}")

    # Check data types
    assert df['Age'].dtype in [np.int64, np.float64], "Age must be numeric"
    assert df['Tenure'].dtype in [np.int64, np.float64], "Tenure must be numeric"
    assert df['Churn'].dtype in [np.int64, np.float64], "Churn must be numeric"

    print("Data validation passed!")


def clean_data(df):
    """
    Clean and handle missing values.

    Args:
        df: Input DataFrame

    Returns:
        DataFrame: Cleaned data
    """
    print("Cleaning data...")
    df_clean = df.copy()

    # Handle missing values in TotalCharges
    if df_clean['TotalCharges'].isnull().any():
        df_clean['TotalCharges'].fillna(df_clean['TotalCharges'].median(), inplace=True)

    # Remove duplicates
    initial_rows = len(df_clean)
    df_clean.drop_duplicates(inplace=True)
    if len(df_clean) < initial_rows:
        print(f"Removed {initial_rows - len(df_clean)} duplicate rows")

    # Handle outliers in Age (keep reasonable range)
    df_clean = df_clean[(df_clean['Age'] >= 18) & (df_clean['Age'] <= 100)]

    # Ensure Tenure is non-negative
    df_clean = df_clean[df_clean['Tenure'] >= 0]

    print(f"Cleaned data: {len(df_clean)} rows remaining")
    return df_clean


def encode_features(df):
    """
    Encode categorical features and scale numerical features.

    Args:
        df: Input DataFrame

    Returns:
        tuple: (encoded DataFrame, label encoders dict, scaler)
    """
    print("Encoding features...")
    df_encoded = df.copy()
    encoders = {}

    # Encode categorical variables
    categorical_columns = ['Contract', 'PaymentMethod']
    for col in categorical_columns:
        le = LabelEncoder()
        df_encoded[col] = le.fit_transform(df_encoded[col])
        encoders[col] = le
        print(f"  Encoded {col}: {len(le.classes_)} categories")

    # Scale numerical features
    numerical_columns = ['Age', 'Tenure', 'MonthlyCharges', 'TotalCharges']
    scaler = StandardScaler()
    df_encoded[numerical_columns] = scaler.fit_transform(df_encoded[numerical_columns])

    print("Feature encoding completed!")
    return df_encoded, encoders, scaler


def split_data(df, test_size=0.2, random_state=42):
    """
    Split data into training and testing sets.

    Args:
        df: Input DataFrame
        test_size: Proportion of data for testing
        random_state: Random seed for reproducibility

    Returns:
        tuple: (X_train, X_test, y_train, y_test)
    """
    print(f"Splitting data (test_size={test_size})...")

    # Separate features and target
    X = df.drop('Churn', axis=1)
    y = df['Churn']

    # Drop CustomerID if exists
    if 'CustomerID' in X.columns:
        X = X.drop('CustomerID', axis=1)

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=random_state, stratify=y
    )

    print(f"Training set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")
    print(f"Churn rate - Train: {y_train.mean():.2%}, Test: {y_test.mean():.2%}")

    return X_train, X_test, y_train, y_test


def save_processed_data(X_train, X_test, y_train, y_test, encoders, scaler,
                       output_dir='data/processed'):
    """
    Save processed data and preprocessing artifacts.

    Args:
        X_train, X_test, y_train, y_test: Split datasets
        encoders: Dictionary of label encoders
        scaler: Fitted StandardScaler
        output_dir: Directory to save processed data
    """
    print(f"Saving processed data to {output_dir}...")
    os.makedirs(output_dir, exist_ok=True)

    # Save datasets
    X_train.to_csv(f'{output_dir}/X_train.csv', index=False)
    X_test.to_csv(f'{output_dir}/X_test.csv', index=False)
    y_train.to_csv(f'{output_dir}/y_train.csv', index=False)
    y_test.to_csv(f'{output_dir}/y_test.csv', index=False)

    # Save preprocessing artifacts
    joblib.dump(encoders, f'{output_dir}/encoders.pkl')
    joblib.dump(scaler, f'{output_dir}/scaler.pkl')

    print("Processed data saved successfully!")


def preprocess_data(data_path='data/sample_data.csv', output_dir='data/processed'):
    """
    Complete preprocessing pipeline.

    Args:
        data_path: Path to raw data CSV
        output_dir: Directory to save processed data

    Returns:
        tuple: (X_train, X_test, y_train, y_test)
    """
    print("=" * 60)
    print("STARTING DATA PREPROCESSING PIPELINE")
    print("=" * 60)

    # Load data
    df = load_data(data_path)

    # Validate data
    validate_data(df)

    # Clean data
    df_clean = clean_data(df)

    # Encode features
    df_encoded, encoders, scaler = encode_features(df_clean)

    # Split data
    X_train, X_test, y_train, y_test = split_data(df_encoded)

    # Save processed data
    save_processed_data(X_train, X_test, y_train, y_test, encoders, scaler, output_dir)

    print("=" * 60)
    print("PREPROCESSING PIPELINE COMPLETED SUCCESSFULLY")
    print("=" * 60)

    return X_train, X_test, y_train, y_test


if __name__ == '__main__':
    preprocess_data()
