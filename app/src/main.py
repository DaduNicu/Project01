import os
import logging
import json
from flask import Flask, jsonify
from prometheus_flask_exporter import PrometheusMetrics

logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s"}'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
metrics = PrometheusMetrics(app)

SYS_ENV = os.getenv('SYS_ENV', 'default')


@app.route('/healthz', methods=['GET'])
def healthz():
    response = {
        'status': 'healthy',
        'sys_env': SYS_ENV,
        'service': 'gcp-devops-challenge'
    }
    logger.info(f'Health check called: {json.dumps(response)}')
    return jsonify(response), 200


@app.route('/', methods=['GET'])
def index():
    return jsonify({
        'service': 'gcp-devops-challenge',
        'endpoints': {
            '/healthz': 'Health check endpoint',
            '/metrics': 'Prometheus metrics endpoint'
        }
    }), 200


if __name__ == '__main__':
    logger.info(f'Starting Flask application with SYS_ENV={SYS_ENV}')
    app.run(host='0.0.0.0', port=8080, debug=False)

