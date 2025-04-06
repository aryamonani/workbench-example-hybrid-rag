#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo '=== Removing any existing apt lock files (if possible) ==='
sudo rm -f /var/lib/apt/lists/lock || true
sudo rm -f /var/cache/apt/archives/lock || true

echo '=== Starting postBuild.bash ==='

# Load conda's environment script
source /opt/conda/etc/profile.d/conda.sh

echo '=== Creating API environment ==='
conda create --name api-env -y python=3.10 pip

echo '=== Installing API Python packages ==='
conda run -n api-env pip install fastapi==0.109.2 'uvicorn[standard]==0.27.0.post1' \
    python-multipart==0.0.7 langchain==0.0.335 langchain-community==0.0.19 \
    openai==1.55.3 httpx==0.27.2 'unstructured[all-docs]==0.12.4' \
    sentence-transformers==2.7.0 llama-index==0.9.44 dataclass-wizard==0.22.3 \
    pymilvus==2.3.1 opencv-python==4.8.0.76 hf_transfer==0.1.5 text_generation==0.6.1 \
    transformers==4.40.0 nltk==3.8.1

echo '=== Creating UI environment ==='
conda create --name ui-env -y python=3.10 pip

echo '=== Installing UI Python packages ==='
conda run -n ui-env pip install dataclass_wizard==0.22.2 gradio==4.15.0 jinja2==3.1.2 \
    numpy==1.25.2 protobuf==3.20.3 PyYAML==6.0 uvicorn==0.22.0 torch==2.1.1 \
    tiktoken==0.7.0 regex==2024.5.15 fastapi==0.112.2

echo '=== Creating necessary directories ==='
sudo mkdir -p /mnt/milvus
sudo mkdir -p /data

echo '=== Setting up user environment ==='
NVWB_UID=${NVWB_UID:-1000}
NVWB_GID=${NVWB_GID:-1000}
NVWB_USERNAME=${NVWB_USERNAME:-workbench}

if ! getent group $NVWB_GID >/dev/null; then
    sudo groupadd -g $NVWB_GID workbench
else
    echo "A group with GID $NVWB_GID already exists; skipping groupadd."
fi

if ! id -u $NVWB_USERNAME >/dev/null 2>&1; then
    sudo useradd -u $NVWB_UID -g $NVWB_GID -m -s /bin/bash $NVWB_USERNAME
else
    echo "User '$NVWB_USERNAME' already exists; skipping useradd."
fi

sudo chown $NVWB_USERNAME:$NVWB_GID /mnt/milvus
sudo chown $NVWB_USERNAME:$NVWB_GID /data

echo '=== Installing git-lfs ==='
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash

if [ -w /var/lib/apt/lists ]; then
    sudo apt-get update && sudo apt-get install -y git-lfs
else
    echo "APT cache not writable; skipping git-lfs installation via apt."
fi

echo '=== Configuring docker-in-docker ==='
echo 'export DOCKER_HOST=unix:///var/run/docker.sock' | sudo tee /etc/profile.d/docker-in-docker.sh

echo '=== postBuild.bash completed successfully ==='