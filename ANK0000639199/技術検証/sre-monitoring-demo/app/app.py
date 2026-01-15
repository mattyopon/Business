"""
SRE Monitoring Demo - Sample Flask Application
This application demonstrates Prometheus metrics integration
"""

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
import time
import random
import os

app = Flask(__name__)

# Prometheus Metrics
REQUEST_COUNT = Counter(
    'flask_http_request_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'flask_http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

ACTIVE_REQUESTS = Gauge(
    'flask_http_requests_active',
    'Number of active requests'
)

BUSINESS_METRIC = Gauge(
    'business_metric_value',
    'Sample business metric',
    ['metric_type']
)

# Middleware to track metrics
@app.before_request
def before_request():
    request.start_time = time.time()
    ACTIVE_REQUESTS.inc()

@app.after_request
def after_request(response):
    request_duration = time.time() - request.start_time
    
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown'
    ).observe(request_duration)
    
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    
    ACTIVE_REQUESTS.dec()
    
    return response

# Application Routes
@app.route('/')
def index():
    return jsonify({
        'service': 'SRE Monitoring Demo',
        'status': 'running',
        'version': '1.0.0',
        'endpoints': {
            '/': 'This page',
            '/health': 'Health check endpoint',
            '/metrics': 'Prometheus metrics',
            '/api/data': 'Sample data endpoint',
            '/api/slow': 'Simulated slow endpoint',
            '/api/error': 'Simulated error endpoint'
        }
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': time.time()
    }), 200

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    # Update business metrics before returning
    BUSINESS_METRIC.labels(metric_type='random').set(random.randint(1, 100))
    BUSINESS_METRIC.labels(metric_type='timestamp').set(time.time())
    
    return generate_latest(REGISTRY), 200, {'Content-Type': 'text/plain; charset=utf-8'}

@app.route('/api/data')
def api_data():
    """Sample API endpoint that returns data"""
    # Simulate some processing time
    time.sleep(random.uniform(0.01, 0.1))
    
    return jsonify({
        'data': [
            {'id': 1, 'name': 'Item 1', 'value': random.randint(1, 100)},
            {'id': 2, 'name': 'Item 2', 'value': random.randint(1, 100)},
            {'id': 3, 'name': 'Item 3', 'value': random.randint(1, 100)}
        ],
        'timestamp': time.time()
    })

@app.route('/api/slow')
def api_slow():
    """Simulated slow endpoint for testing latency alerts"""
    # Simulate slow processing (1-3 seconds)
    delay = random.uniform(1.0, 3.0)
    time.sleep(delay)
    
    return jsonify({
        'message': 'This was a slow request',
        'delay': delay,
        'timestamp': time.time()
    })

@app.route('/api/error')
def api_error():
    """Simulated error endpoint for testing error rate alerts"""
    # Randomly return errors
    if random.random() < 0.5:
        return jsonify({
            'error': 'Internal Server Error',
            'message': 'This is a simulated error for testing'
        }), 500
    
    return jsonify({
        'message': 'Success',
        'timestamp': time.time()
    })

@app.route('/api/compute')
def api_compute():
    """CPU-intensive endpoint for testing CPU alerts"""
    # Simulate CPU work
    result = sum([i ** 2 for i in range(100000)])
    
    return jsonify({
        'result': result,
        'timestamp': time.time()
    })

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=False)
