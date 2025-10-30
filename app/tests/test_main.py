"""
Unit tests for the Flask application.
"""
import pytest
import os
import sys

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from main import app


@pytest.fixture
def client():
    """Create a test client for the Flask app."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_healthz_endpoint(client):
    """Test the /healthz endpoint returns 200 and correct structure."""
    response = client.get('/healthz')
    assert response.status_code == 200
    
    data = response.get_json()
    assert 'status' in data
    assert data['status'] == 'healthy'
    assert 'sys_env' in data
    assert 'service' in data


def test_healthz_sys_env(client, monkeypatch):
    """Test that /healthz returns the correct SYS_ENV value."""
    # Set SYS_ENV for this test
    test_env_value = 'test_environment'
    monkeypatch.setenv('SYS_ENV', test_env_value)
    
    # Re-import to pick up new environment variable
    import importlib
    import main as main_module
    importlib.reload(main_module)
    
    response = main_module.app.test_client().get('/healthz')
    assert response.status_code == 200
    
    data = response.get_json()
    assert data['sys_env'] == test_env_value


def test_root_endpoint(client):
    """Test the root endpoint returns service information."""
    response = client.get('/')
    assert response.status_code == 200
    
    data = response.get_json()
    assert 'service' in data
    assert 'endpoints' in data


def test_metrics_endpoint(client):
    """Test that Prometheus metrics endpoint is accessible."""
    response = client.get('/metrics')
    assert response.status_code == 200
    assert b'flask_http_request' in response.data or b'# HELP' in response.data


def test_healthz_json_format(client):
    """Test that /healthz returns proper JSON format."""
    response = client.get('/healthz')
    assert response.content_type == 'application/json'

