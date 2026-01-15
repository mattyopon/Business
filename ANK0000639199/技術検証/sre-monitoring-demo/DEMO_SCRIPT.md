# SRE Monitoring Demo Script

Use this script to guide someone through the demo in an interview or presentation.

## Demo Duration: 10-15 minutes

## Setup (Before Demo)

```bash
cd sre-monitoring-demo
docker-compose up -d
# Wait 30 seconds for all services to be ready
```

## Part 1: Architecture Overview (2 minutes)

### Talking Points:
"I've built a comprehensive SRE monitoring stack that demonstrates production-ready observability practices. Let me walk you through the architecture."

**Show the README architecture diagram**

"The stack consists of:
- **Prometheus** as the central metrics collection system using a pull-based model
- **Grafana** for visualization with pre-configured dashboards
- **A sample application** instrumented with custom business and technical metrics
- **Node Exporter** for infrastructure metrics
- **cAdvisor** for container-level metrics
- **AlertManager** for alert routing and management

This demonstrates a multi-layered monitoring approach: application, container, and infrastructure."

## Part 2: Metrics Collection (3 minutes)

### Show Prometheus Targets

1. Open http://localhost:9090/targets

**Talking Points:**
"Prometheus uses a pull model, scraping metrics from various endpoints every 15 seconds. As you can see, all targets are healthy and being scraped successfully."

### Show Raw Metrics

2. Open http://localhost:5000/metrics

**Talking Points:**
"The application exposes metrics in Prometheus format. We're tracking:
- **RED metrics**: Rate, Errors, Duration for every endpoint
- **Business metrics**: Orders, revenue, active users
- **Resource metrics**: CPU, memory, database connections

This follows the 'instrument everything' principle of observability."

### Execute Some PromQL Queries

3. In Prometheus (http://localhost:9090), run these queries:

```promql
# Request rate
rate(app_requests_total[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(app_request_duration_seconds_bucket[5m]))

# Error rate
rate(app_requests_total{status=~"5.."}[5m]) / rate(app_requests_total[5m])
```

**Talking Points:**
"PromQL is powerful for querying time-series data. These queries show the Golden Signals:
- Traffic (request rate)
- Latency (using histograms for percentiles)
- Errors (5xx error rate)
- Saturation (CPU, memory) - shown in dashboards"

## Part 3: Grafana Dashboards (4 minutes)

### Application Dashboard

1. Open http://localhost:3000 (login: admin/admin)
2. Navigate to Application Metrics Dashboard

**Talking Points:**
"I've created pre-configured dashboards that auto-provision on startup. The Application Dashboard shows:
- **Request Rate**: Traffic patterns by endpoint
- **Response Time**: p95 and p50 latencies with SLO thresholds
- **Error Rate**: Gauge showing current error percentage
- **Business Metrics**: Active users, database connections, order rates, revenue

These dashboards answer the question: 'Is the service working correctly from a user perspective?'"

### Generate Traffic

3. Run these commands in a terminal:

```bash
# Generate orders
for i in {1..20}; do curl -X POST http://localhost:5000/api/orders; sleep 0.2; done

# Generate errors
for i in {1..10}; do curl http://localhost:5000/api/error; sleep 0.1; done

# Simulate traffic
curl -X POST http://localhost:5000/api/simulate-traffic
```

**Talking Points:**
"Watch how the metrics update in real-time as we generate traffic. This demonstrates the full observability pipeline: application → Prometheus → Grafana."

### Infrastructure Dashboard

4. Switch to Infrastructure Metrics Dashboard

**Talking Points:**
"The Infrastructure Dashboard provides system-level visibility:
- CPU, memory, disk usage with appropriate thresholds (yellow at 70%, red at 85%)
- Network I/O
- Container-level resource usage

This helps identify if application issues are due to infrastructure constraints."

## Part 4: Alerting (3 minutes)

### Show Alert Rules

1. Open http://localhost:9090/alerts

**Talking Points:**
"I've configured comprehensive alert rules covering:
- **Application alerts**: High error rate, high latency, service down
- **Infrastructure alerts**: High CPU/memory/disk usage
- **Business alerts**: Low order success rate, database connection exhaustion

Alerts have:
- Multiple severity levels (critical, warning, info)
- Appropriate thresholds based on SLOs
- 'for' durations to prevent alert fatigue from transient issues
- Clear descriptions with actionable information"

### Trigger an Alert

2. Generate high error rate:

```bash
# This will trigger the HighErrorRate alert after 2 minutes
for i in {1..100}; do curl http://localhost:5000/api/error; done
```

3. Wait and show the alert firing (or explain it would fire after 2 minutes)

4. Open http://localhost:9093 (AlertManager)

**Talking Points:**
"AlertManager handles:
- Alert grouping and deduplication
- Routing to different receivers based on severity
- Silencing during maintenance windows
- Inhibition rules (suppressing lower-severity alerts when critical ones fire)

In production, this would integrate with PagerDuty, Slack, or email."

## Part 5: SRE Best Practices (2-3 minutes)

### Key Points to Emphasize:

**1. Service Level Indicators (SLIs)**
"The application tracks key SLIs:
- Availability: uptime percentage
- Latency: request duration percentiles
- Error rate: percentage of failed requests
- Throughput: requests per second"

**2. Observability vs. Monitoring**
"This demonstrates observability - the ability to ask arbitrary questions about your system:
- Why is this endpoint slow?
- What's the correlation between error rate and CPU usage?
- How does traffic pattern affect resource consumption?"

**3. Instrumentation Strategy**
"I've instrumented at multiple levels:
- Application code with custom metrics
- HTTP middleware for automatic request tracking
- System-level exporters for infrastructure
- Container metrics for resource usage"

**4. Production-Ready Features**
"This stack includes production best practices:
- Health check endpoints for liveness/readiness probes
- Histogram metrics for accurate percentile calculation
- High cardinality metrics carefully managed (using labels appropriately)
- Dashboard as code (JSON provisioning)
- Infrastructure as code (docker-compose)"

## Part 6: Q&A Preparation

### Common Interview Questions:

**Q: How would you scale this for production?**
A:
- Use Prometheus federation or Thanos for multi-region setup
- Implement remote storage for long-term retention
- Use service discovery instead of static configs
- Add authentication and encryption
- Implement HA with multiple Prometheus/Grafana instances

**Q: What's missing from this demo?**
A:
- Distributed tracing (Jaeger/Tempo)
- Log aggregation (ELK/Loki)
- Synthetic monitoring / uptime checks
- Integration with incident management (PagerDuty)
- Cost tracking and resource optimization

**Q: How do you prevent alert fatigue?**
A:
- Appropriate 'for' durations
- Alert on symptoms, not causes
- Use severity levels correctly
- Implement inhibition rules
- Regular alert review and tuning

**Q: How do you set SLO thresholds?**
A:
- Analyze historical data
- Understand business requirements
- Start conservative, tune over time
- Balance between sensitivity and noise
- Consider error budgets

## Cleanup

```bash
docker-compose down
# Or keep volumes for next demo
docker-compose down -v
```

## Tips for Delivery

1. **Practice**: Run through this script 2-3 times before the interview
2. **Have it running**: Start the stack before the interview begins
3. **Know the code**: Be prepared to explain any part of the implementation
4. **Tell a story**: Connect monitoring to business outcomes
5. **Be honest**: If you don't know something, explain how you'd find out
6. **Show enthusiasm**: Demonstrate genuine interest in SRE practices

## Time Savers

If short on time, focus on:
1. Architecture overview (show diagram)
2. Live Grafana dashboards with simulated traffic
3. One alert rule explanation
4. Discussion of SRE principles

This hits all the key points in 5-7 minutes.
