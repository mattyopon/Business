# SRE Monitoring Demo Project

A comprehensive Site Reliability Engineering (SRE) monitoring demonstration project showcasing industry-standard observability tools and practices.

## Overview

This project demonstrates a complete monitoring stack using **Prometheus**, **Grafana**, **Node Exporter**, and a custom **Flask application** with integrated metrics. It's designed to showcase SRE principles, monitoring best practices, and hands-on experience with modern observability tools.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                          │
│                                                               │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   Grafana    │◄─────│  Prometheus  │                     │
│  │  Port 3000   │      │  Port 9090   │                     │
│  └──────────────┘      └───────┬──────┘                     │
│                                 │                             │
│                    ┌────────────┼────────────┐               │
│                    │            │            │               │
│             ┌──────▼─────┐ ┌───▼────────┐ ┌▼──────────┐   │
│             │Node Exporter│ │ Sample App │ │Prometheus │   │
│             │ Port 9100   │ │ Port 8000  │ │   Self    │   │
│             └─────────────┘ └────────────┘ └───────────┘   │
│             System Metrics   App Metrics   Prom Metrics     │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### Monitoring Components
- **Prometheus**: Time-series database for metrics collection and storage
- **Grafana**: Beautiful, interactive dashboards for data visualization
- **Node Exporter**: System-level metrics (CPU, memory, disk, network)
- **Sample Application**: Custom Flask app with business metrics

### Metrics Collected
- **System Metrics**: CPU usage, memory consumption, disk space, network I/O
- **Application Metrics**: Request rate, response time, error rate, active requests
- **Business Metrics**: Custom metrics specific to application logic

### Alert Rules
- Instance availability monitoring
- High CPU/memory usage detection
- Low disk space warnings
- High request rate alerts
- Error rate threshold monitoring
- Response time SLA tracking

## Quick Start

### Prerequisites
- Docker Desktop installed and running
- Docker Compose v2.0 or higher
- 4GB RAM available for containers
- Ports 3000, 8000, 9090, 9100 available

### Start the Stack

```bash
# Clone or navigate to the project directory
cd sre-monitoring-demo

# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### Access the Services

Once all containers are running:

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana Dashboard | http://localhost:3000 | admin / admin |
| Prometheus UI | http://localhost:9090 | - |
| Sample Application | http://localhost:8000 | - |
| Node Exporter Metrics | http://localhost:9100/metrics | - |

### First-Time Setup

1. **Access Grafana**: Navigate to http://localhost:3000
2. **Login**: Use credentials `admin` / `admin`
3. **View Dashboard**: The "SRE Monitoring - System Overview" dashboard is pre-configured
4. **Explore Metrics**: Visit Prometheus at http://localhost:9090 to query raw metrics

### Generate Load

Test the monitoring stack by generating traffic:

```bash
# Install curl or use your browser

# Normal requests
curl http://localhost:8000/api/data

# Slow requests (tests latency alerts)
curl http://localhost:8000/api/slow

# Error-prone requests (tests error rate alerts)
curl http://localhost:8000/api/error

# CPU-intensive requests
curl http://localhost:8000/api/compute
```

Or use a load testing tool:

```bash
# Using Apache Bench
ab -n 1000 -c 10 http://localhost:8000/api/data

# Using wrk
wrk -t4 -c10 -d30s http://localhost:8000/api/data
```

## Project Structure

```
sre-monitoring-demo/
├── app/
│   ├── app.py              # Flask application with metrics
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile          # Application container image
├── prometheus/
│   ├── prometheus.yml      # Prometheus configuration
│   └── alerts.yml          # Alert rules definitions
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/    # Auto-configured datasources
│   │   └── dashboards/     # Dashboard provisioning
│   └── dashboards/
│       └── system-overview.json  # Pre-built dashboard
├── docs/
│   ├── SETUP.md            # Detailed setup guide
│   ├── USAGE.md            # Usage instructions
│   ├── ARCHITECTURE.md     # Architecture deep dive
│   ├── INTERVIEW_GUIDE.md  # Interview talking points
│   └── TROUBLESHOOTING.md  # Common issues and solutions
├── docker-compose.yml      # Complete stack definition
├── .gitignore
└── README.md               # This file
```

## Key Concepts Demonstrated

### SRE Principles
- **Service Level Indicators (SLIs)**: Request rate, error rate, latency
- **Monitoring Best Practices**: Multi-layer observability
- **Alert Design**: Actionable alerts with proper thresholds
- **Operational Visibility**: Real-time system insights

### Technical Skills
- Docker containerization and orchestration
- Prometheus metrics collection and querying (PromQL)
- Grafana dashboard creation and provisioning
- Application instrumentation with prometheus-client
- Health check implementation
- Alert rule configuration

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[SETUP.md](docs/SETUP.md)**: Step-by-step installation and configuration
- **[USAGE.md](docs/USAGE.md)**: How to use each component effectively
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)**: Deep dive into system design
- **[INTERVIEW_GUIDE.md](docs/INTERVIEW_GUIDE.md)**: Talking points for interviews
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**: Solutions to common issues

## Stopping the Stack

```bash
# Stop all services (preserves data)
docker-compose stop

# Stop and remove containers (preserves volumes)
docker-compose down

# Stop and remove everything including volumes
docker-compose down -v
```

## Learning Outcomes

After working with this project, you'll understand:

1. How to set up a production-grade monitoring stack
2. How to instrument applications with Prometheus metrics
3. How to create meaningful dashboards in Grafana
4. How to write effective alert rules
5. How to troubleshoot system and application issues using metrics
6. SRE best practices for observability

## Interview Talking Points

This project demonstrates:
- Experience with modern monitoring and observability tools
- Understanding of SRE principles and metrics
- Docker and containerization skills
- Infrastructure as Code practices
- Full-stack development (backend app + monitoring)
- Production operations knowledge

## Technologies Used

- **Prometheus v2.48.0**: Metrics collection and storage
- **Grafana v10.2.2**: Visualization and dashboards
- **Node Exporter v1.7.0**: System metrics
- **Python 3.11**: Application development
- **Flask 3.0.0**: Web framework
- **prometheus-client 0.19.0**: Python metrics library
- **Docker & Docker Compose**: Containerization

## Next Steps

1. Explore the pre-configured Grafana dashboard
2. Create custom queries in Prometheus
3. Trigger alerts by generating load
4. Modify alert thresholds to match your requirements
5. Add your own custom metrics to the sample app
6. Create additional Grafana dashboards

## License

This is a demonstration project for educational purposes.

## Support

For detailed information, check the documentation in the `docs/` directory.

---

**Built with best practices for production monitoring and observability.**
