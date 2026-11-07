
import os
import socket
from pathlib import Path

from flask import Flask, jsonify

app = Flask(__name__)

# ConfigMap volume mount used by Kubernetes
CONFIG_DIR = Path("/etc/app-config")


def get_config(name, default):
    """
    Read a mounted ConfigMap value when available.
    Otherwise, read the environment variable.
    """
    config_file = CONFIG_DIR / name

    try:
        return config_file.read_text().strip()
    except FileNotFoundError:
        return os.getenv(name, default)


@app.get("/")
def home():
    return jsonify({
        "app": get_config("APP_NAME", "enterprise-bot-demo"),
        "version": get_config("VERSION", "1.0.0"),
        "pod": socket.gethostname()
    })


@app.get("/healthz")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
