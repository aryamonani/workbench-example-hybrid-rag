#!/bin/bash
set -e

echo "=== Removing any existing apt lock files (if possible) ==="
rm -f /var/lib/apt/lists/lock || true
rm -f /var/cache/apt/archives/lock || true

echo "=== Starting postBuild.bash ==="

# Source conda so that 'conda' commands are available.
if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
  source /opt/conda/etc/profile.d/conda.sh
else
  echo "Conda initialization script not found. Exiting."
  exit 1
fi

echo "=== Creating API environment ==="
if ! conda env list | grep -q "api-env"; then
  conda create --name api-env python=3.10 pip -y
fi

# Activate the API environment
conda activate api-env

echo "=== Installing API Python packages ==="
pip install fastapi==0.109.2 'uvicorn[standard]==0.27.0.post1' python-multipart==0.0.7 \
  langchain==0.0.335 langchain-community==0.0.19 openai==1.55.3 httpx==0.27.2 \
  'unstructured[all-docs]==0.12.4' sentence-transformers==2.7.0 llama-index==0.9.44 \
  dataclass-wizard==0.22.3 pymilvus==2.3.1 opencv-python==4.8.0.76 hf_transfer==0.1.5 \
  text_generation==0.6.1 transformers==4.40.0 nltk==3.8.1

echo "=== Creating UI environment ==="
if ! conda env list | grep -q "ui-env"; then
  conda create --name ui-env python=3.10 pip -y
fi

conda activate ui-env

echo "=== Installing UI Python packages ==="
pip install dataclass_wizard==0.22.2 gradio==4.15.0 jinja2==3.1.2 numpy==1.25.2 \
  protobuf==3.20.3 PyYAML==6.0 uvicorn==0.22.0 torch==2.1.1 tiktoken==0.7.0 \
  regex==2024.5.15 fastapi==0.112.2

echo "=== Configuring docker-in-docker ==="
if [ -w /var/lib/apt/lists ]; then
  cat <<EOF | sudo tee /etc/profile.d/docker-in-docker.sh
# Docker in Docker configuration
export DOCKER_HOST=unix:///var/run/docker.sock
EOF
else
  echo "APT cache not writable; skipping docker-in-docker configuration."
fi

echo "=== postBuild.bash complete ==="