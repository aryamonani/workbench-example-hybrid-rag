#!/bin/bash
set -e
set -x

# Install dependencies for the API in a separate venv to isolate different components
conda create --name api-env -y python=3.10 pip
$HOME/.conda/envs/api-env/bin/pip install fastapi==0.109.2 uvicorn[standard]==0.27.0.post1 python-multipart==0.0.7 langchain==0.0.335 langchain-community==0.0.19 openai==1.55.3 httpx==0.27.2 unstructured[all-docs]==0.12.4 sentence-transformers==2.7.0 llama-index==0.9.44 dataclass-wizard==0.22.3 pymilvus==2.3.1 opencv-python==4.8.0.76 hf_transfer==0.1.5 text_generation==0.6.1 transformers==4.40.0 nltk==3.8.1

# Install dependencies for the UI in a separate venv to isolate different components
conda create --name ui-env -y python=3.10 pip
$HOME/.conda/envs/ui-env/bin/pip install dataclass_wizard==0.22.2 gradio==4.15.0 jinja2==3.1.2 numpy==1.25.2 protobuf==3.20.3 PyYAML==6.0 uvicorn==0.22.0 torch==2.1.1 tiktoken==0.7.0 regex==2024.5.15 fastapi==0.112.2

# Update and install necessary tools via apt-get
apt-get update
apt-get -y install ca-certificates curl wget bzip2
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get -y install docker-ce-cli

/opt/conda/bin/pip install anyio==4.3.0 pymilvus==2.3.1 transformers==4.40.0

# Create necessary directories and set ownership
mkdir -p /mnt/milvus
mkdir -p /data
# (Initial chown may fail if the user doesn't exist yet; further chown is done later)
chown workbench:workbench /mnt/milvus || true
chown workbench:workbench /data || true

# Install git-lfs
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
apt-get -y install git-lfs

# Use environment variables or default values
NVWB_UID=${NVWB_UID:-1000}
NVWB_GID=${NVWB_GID:-1000}
NVWB_USERNAME=${NVWB_USERNAME:-workbench}

# Create the group if it doesn't exist
if ! getent group "$NVWB_USERNAME" >/dev/null 2>&1; then
    groupadd -g "$NVWB_GID" "$NVWB_USERNAME"
fi

# Create the user if it doesn't exist
if ! id -u "$NVWB_USERNAME" >/dev/null 2>&1; then
    useradd -m -u "$NVWB_UID" -g "$NVWB_GID" "$NVWB_USERNAME"
fi

# Change ownership of the directories using the dynamic values
chown "$NVWB_USERNAME":"$NVWB_USERNAME" /mnt/milvus
chown "$NVWB_USERNAME":"$NVWB_USERNAME" /data

# Configure docker-in-docker: ensure the workbench user is added to the docker group if needed
cat <<EOM | tee /etc/profile.d/docker-in-docker.sh > /dev/null
if ! groups $NVWB_USERNAME | grep docker > /dev/null; then
    docker_gid=\$(stat -c %g /var/host-run/docker.sock)
    groupadd -g \$docker_gid docker
    usermod -aG docker $NVWB_USERNAME
fi
EOM

# Grant the workbench user sudo access without a password
echo "$NVWB_USERNAME ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/00-workbench > /dev/null