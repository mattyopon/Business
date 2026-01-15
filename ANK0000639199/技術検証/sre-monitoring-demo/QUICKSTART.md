# Quick Start Guide

Get the SRE Monitoring Demo running in 5 minutes!

## Prerequisites

- Docker Desktop installed and running
- Ports 3000, 8000, 9090, 9100 available

## Start the Demo

```bash
# Navigate to project directory
cd c:/Users/matty/coachtech/sre-monitoring-demo

# Start all services
docker-compose up -d

# Wait for services to initialize (about 30 seconds)

# Check status
docker-compose ps
```

## Access the Services

1. **Grafana Dashboard** (Main Interface)
   - URL: http://localhost:3000
   - Login: `admin` / `admin`
   - Go to: Dashboards → Browse → "SRE Monitoring - System Overview"

2. **Prometheus UI** (Metrics Explorer)
   - URL: http://localhost:9090
   - Navigate to: Status → Targets (verify all targets are UP)

3. **Sample Application** (Test API)
   - URL: http://localhost:8000
   - Health Check: http://localhost:8000/health
   - Metrics: http://localhost:8000/metrics

## Generate Some Traffic

```bash
# Simple test
curl http://localhost:8000/api/data

# Generate load (run in a loop)
for i in {1..100}; do 
  curl http://localhost:8000/api/data
  sleep 0.1
done
```

Watch the metrics update in real-time on the Grafana dashboard!

## Key Metrics to Watch

In Grafana dashboard, you'll see:
- **CPU Usage**: System CPU utilization
- **Memory Usage**: System memory consumption  
- **Request Rate**: HTTP requests per second
- **Response Time**: p95 and p99 latency
- **Error Rate**: Percentage of failed requests
- **Service Health**: Up/Down status indicators

## Test Different Scenarios

```bash
# Normal requests
curl http://localhost:8000/api/data

# Slow requests (1-3 second delay)
curl http://localhost:8000/api/slow

# Error-prone requests (50% failure rate)
curl http://localhost:8000/api/error

# CPU-intensive requests
curl http://localhost:8000/api/compute
```

## Explore Prometheus Queries

Open http://localhost:9090 and try these queries:

**CPU Usage:**
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Request Rate:**
```promql
rate(flask_http_request_total[5m])
```

**Error Rate:**
```promql
sum(rate(flask_http_request_total{status=~"5.."}[5m])) / sum(rate(flask_http_request_total[5m])) * 100
```

## Stopping the Demo

```bash
# Stop all services (keeps data)
docker-compose stop

# Stop and remove containers (keeps volumes)
docker-compose down

# Remove everything including data
docker-compose down -v
```

## Troubleshooting

**Services won't start?**
```bash
docker-compose logs -f
```

**Prometheus targets down?**
- Check: http://localhost:9090/targets
- Solution: `docker-compose restart <service>`

**Grafana showing no data?**
- Verify Prometheus is accessible: http://localhost:9090
- Check data source in Grafana: Configuration → Data Sources → Prometheus → Test

**Need a fresh start?**
```bash
docker-compose down -v
docker-compose up -d --build
```

## Next Steps

1. Read the full [README.md](README.md) for detailed information
2. Check [docs/SETUP.md](docs/SETUP.md) for complete setup instructions
3. Review [docs/USAGE.md](docs/USAGE.md) for operational guidance
4. Study [docs/INTERVIEW_GUIDE.md](docs/INTERVIEW_GUIDE.md) for talking points
5. Refer to [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for system details

## Key Commands Reference

```bash
# Start
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Restart service
docker-compose restart app

# Stop
docker-compose down

# Complete reset
docker-compose down -v && docker-compose up -d --build
```

---

**That's it! You now have a fully functional SRE monitoring stack running locally.**
