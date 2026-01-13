"""
Sample Flask Application with Prometheus Metrics
Demonstrates SRE best practices for application monitoring
"""

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
import time
import random
import psutil
import os

app = Flask(__name__)

# Custom Metrics
# Counter: monotonically increasing value
request_count = Counter(
    'app_requests_total',
    'Total number of requests',
    ['method', 'endpoint', 'status']
)

# Histogram: track distribution of values
request_duration = Histogram(
    'app_request_duration_seconds',
    'Request duration in seconds',
    ['method', 'endpoint']
)

# Gauge: can go up or down
active_users = Gauge('app_active_users', 'Number of active users')
error_rate = Gauge('app_error_rate', 'Current error rate')
database_connections = Gauge('app_database_connections', 'Active database connections')

# Business Metrics
orders_total = Counter('app_orders_total', 'Total orders processed', ['status'])
revenue_total = Counter('app_revenue_total', 'Total revenue in cents')

# System Metrics
cpu_usage = Gauge('app_cpu_usage_percent', 'CPU usage percentage')
memory_usage = Gauge('app_memory_usage_bytes', 'Memory usage in bytes')

# Simulate some state
active_user_count = 0
db_connections = 0


def update_system_metrics():
    """Update system-level metrics"""
    cpu_usage.set(psutil.cpu_percent(interval=0.1))
    memory_usage.set(psutil.Process(os.getpid()).memory_info().rss)


@app.before_request
def before_request():
    """Track request start time"""
    request.start_time = time.time()


@app.after_request
def after_request(response):
    """Record metrics after each request"""
    request_latency = time.time() - request.start_time

    # Record metrics
    request_count.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()

    request_duration.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown'
    ).observe(request_latency)

    update_system_metrics()

    return response


@app.route('/')
def index():
    """Homepage with API documentation"""
    return jsonify({
        'service': 'SRE Monitoring Demo Application',
        'version': '1.0.0',
        'endpoints': {
            '/': 'This documentation',
            '/health': 'Health check endpoint',
            '/metrics': 'Prometheus metrics endpoint',
            '/api/users': 'Simulate user activity',
            '/api/orders': 'Simulate order processing',
            '/api/slow': 'Slow endpoint (>1s)',
            '/api/error': 'Endpoint that fails randomly',
            '/api/heavy': 'CPU intensive operation'
        }
    })


@app.route('/health')
def health():
    """Health check endpoint for monitoring"""
    health_status = {
        'status': 'healthy',
        'timestamp': time.time(),
        'checks': {
            'database': 'ok',
            'cache': 'ok',
            'disk_space': 'ok'
        }
    }

    # Simulate health check logic
    if random.random() > 0.95:  # 5% chance of degraded
        health_status['status'] = 'degraded'
        health_status['checks']['database'] = 'slow'
        return jsonify(health_status), 503

    return jsonify(health_status), 200


@app.route('/api/users', methods=['POST', 'GET'])
def users():
    """Simulate user activity"""
    global active_user_count

    if request.method == 'POST':
        active_user_count += 1
        active_users.set(active_user_count)
        return jsonify({'message': 'User logged in', 'active_users': active_user_count})
    else:
        return jsonify({'active_users': active_user_count})


@app.route('/api/orders', methods=['POST'])
def create_order():
    """Simulate order processing"""
    # Random order processing
    processing_time = random.uniform(0.1, 0.5)
    time.sleep(processing_time)

    # 90% success rate
    if random.random() > 0.1:
        order_value = random.randint(1000, 50000)  # in cents
        orders_total.labels(status='success').inc()
        revenue_total.inc(order_value)

        return jsonify({
            'status': 'success',
            'order_id': random.randint(10000, 99999),
            'amount': order_value / 100,
            'processing_time': processing_time
        })
    else:
        orders_total.labels(status='failed').inc()
        return jsonify({'status': 'failed', 'error': 'Payment processing failed'}), 500


@app.route('/api/slow')
def slow_endpoint():
    """Simulate a slow endpoint (SLO violation)"""
    delay = random.uniform(1.0, 3.0)
    time.sleep(delay)
    return jsonify({
        'message': 'This was a slow request',
        'delay': delay
    })


@app.route('/api/error')
def error_endpoint():
    """Endpoint that fails randomly (40% failure rate)"""
    if random.random() > 0.6:
        return jsonify({'status': 'success'})
    else:
        error_rate.set(0.4)
        return jsonify({'error': 'Random failure occurred'}), 500


@app.route('/api/heavy')
def heavy_endpoint():
    """Simulate CPU intensive operation"""
    # CPU intensive calculation
    result = sum([i ** 2 for i in range(100000)])

    global db_connections
    db_connections = random.randint(5, 50)
    database_connections.set(db_connections)

    return jsonify({
        'message': 'Heavy computation completed',
        'result': result,
        'db_connections': db_connections
    })


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(REGISTRY)


# Background task simulator
@app.route('/api/simulate-traffic', methods=['POST'])
def simulate_traffic():
    """Simulate various traffic patterns for demo purposes"""
    import threading

    def generate_traffic():
        import requests
        base_url = 'http://localhost:5000'

        for _ in range(50):
            try:
                # Mix of different endpoints
                endpoints = ['/api/orders', '/api/users', '/api/heavy', '/api/error']
                endpoint = random.choice(endpoints)

                if endpoint == '/api/orders':
                    requests.post(f'{base_url}{endpoint}')
                else:
                    requests.get(f'{base_url}{endpoint}')

                time.sleep(random.uniform(0.1, 0.5))
            except:
                pass

    thread = threading.Thread(target=generate_traffic)
    thread.daemon = True
    thread.start()

    return jsonify({'message': 'Traffic simulation started'})


if __name__ == '__main__':
    print("Starting SRE Monitoring Demo Application...")
    print("Metrics available at http://localhost:5000/metrics")
    app.run(host='0.0.0.0', port=5000, debug=False)
