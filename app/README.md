# GCP DevOps Challenge - Application

A simple Python Flask HTTP service with health check endpoint and Prometheus metrics.

## Features

- `/healthz` endpoint returning 200 OK with system environment information
- `/metrics` endpoint exposing Prometheus metrics
- Structured JSON logging
- Non-root container execution
- Health checks for Kubernetes

## Requirements

- Python 3.11+
- Docker (for containerized deployment)

## Local Development

### Setup

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set environment variable (optional):
```bash
export SYS_ENV=helloworld
```

### Run Locally

Start the Flask development server:
```bash
python src/main.py
```

The service will be available at `http://localhost:8080`

### Run with Gunicorn (Production-like)

```bash
gunicorn -w 4 -b 0.0.0.0:8080 src.main:app
```

## Testing

Run unit tests:
```bash
pytest tests/ -v
```

Run with coverage:
```bash
pytest tests/ --cov=src --cov-report=html
```

Run linting:
```bash
flake8 src/ tests/
```

## API Endpoints

### GET /healthz
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "sys_env": "helloworld",
  "service": "gcp-devops-challenge"
}
```

### GET /metrics
Prometheus metrics endpoint for monitoring.

### GET /
Root endpoint with service information.

## Docker

Build the Docker image:
```bash
docker build -t gcp-devops-challenge:latest .
```

Run the container:
```bash
docker run -p 8080:8080 -e SYS_ENV=helloworld gcp-devops-challenge:latest
```

Test the health endpoint:
```bash
curl http://localhost:8080/healthz
```

## Environment Variables

- `SYS_ENV`: System environment identifier (default: "default")

