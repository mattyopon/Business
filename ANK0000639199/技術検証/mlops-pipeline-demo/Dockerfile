FROM python:3.10-slim

# Set working directory
WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY pipeline/requirements.txt /workspace/pipeline/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r pipeline/requirements.txt

# Copy project files
COPY . /workspace/

# Create necessary directories
RUN mkdir -p /workspace/data/processed \
    /workspace/models \
    /workspace/metrics \
    /workspace/mlruns

# Set environment variables
ENV PYTHONPATH=/workspace
ENV MLFLOW_TRACKING_URI=http://mlflow:5000

# Default command (can be overridden)
CMD ["python", "pipeline/train.py"]
