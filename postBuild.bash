#!/bin/bash
set -e
set -x

export DEBIAN_FRONTEND=noninteractive

echo "=== Removing any existing apt lock files (if possible) ==="
rm -f /var/lib/apt/lists/lock || true
rm -f /var/cache/apt/archives/lock || true

echo "=== Starting postBuild.bash ==="

# Install Miniconda only if conda is not already available.
if ! command -v conda >/dev/null 2>&1; then
    echo "Conda not found. Installing Miniconda..."
    if [ -w /var/lib/apt/lists ]; then
        apt-get -o Dir::State::lock=/tmp/apt.lock update
        apt-get -o Dir::State::lock=/tmp/apt.lock -y install wget bzip2
    else
        echo "APT cache not writable; skipping apt-get update/install for Miniconda prerequisites."
    fi
    wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    /bin/bash /tmp/miniconda.sh -b -p /opt/conda
    rm /tmp/miniconda.sh
    /opt/conda/bin/conda clean -tipsy
    if [ -w /var/lib/apt/lists ]; then
        apt-get clean && rm -rf /var/lib/apt/lists/*
    fi
fi

# Ensure conda is in PATH.
export PATH=/opt/conda/bin:$PATH

echo "=== Creating API environment ==="
conda create --name api-env -y python=3.10 pip
$HOME/.conda/envs/api-env/bin/pip install fastapi==0.109.2 uvicorn[standard]==0.27.0.post1 python-multipart==0.0.7 langchain==0.0.335 langchain-community==0.0.19 openai==1.55.3 httpx==0.27.2 unstructured[all-docs]==0.12.4 sentence-transformers==2.7.0 llama-index==0.9.44 dataclass-wizard==0.22.3 pymilvus==2.3.1 opencv-python==4.8.0.76 hf_transfer==0.1.5 text_generation==0.6.1 transformers==4.40.0 nltk==3.8.1

echo "=== Creating UI environment ==="
conda create --name ui-env -y python=3.10 pip
$HOME/.conda/envs/ui-env/bin/pip install dataclass_wizard==0.22.2 gradio==4.15.0 jinja2==3.1.2 numpy==1.25.2 protobuf==3.20.3 PyYAML==6.0 uvicorn==0.22.0 torch==2.1.1 tiktoken==0.7.0 regex==2024.5.15 fastapi==0.112.2

echo "=== Updating apt and installing tools (if possible) ==="
if [ -w /var/lib/apt/lists ]; then
    apt-get -o Dir::State::lock=/tmp/apt.lock update
    apt-get -o Dir::State::lock=/tmp/apt.lock -y install ca-certificates curl wget bzip2
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "=== Adding Docker apt source ==="
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get -o Dir::State::lock=/tmp/apt.lock update
    apt-get -o Dir::State::lock=/tmp/apt.lock -y install docker-ce-cli
else
    echo "APT cache not writable; skipping apt-get update/install for tools."
fi

echo "=== Installing additional Python packages ==="
/opt/conda/bin/pip install anyio==4.3.0 pymilvus==2.3.1 transformers==4.40.0

echo "=== Creating necessary directories ==="
mkdir -p /mnt/milvus
mkdir -p /data

echo "=== Setting up user environment ==="
# Set defaults if not provided externally.
NVWB_UID=${NVWB_UID:-1000}
NVWB_GID=${NVWB_GID:-1000}
NVWB_USERNAME=${NVWB_USERNAME:-workbench}

# Check if a group with the target GID already exists.
if getent group "$NVWB_GID" >/dev/null 2>&1; then
    echo "A group with GID $NVWB_GID already exists; skipping groupadd."
else
    groupadd -g "$NVWB_GID" "$NVWB_USERNAME"
fi

# Check if the user exists.
if ! id -u "$NVWB_USERNAME" >/dev/null 2>&1; then
    useradd -m -u "$NVWB_UID" -g "$NVWB_GID" "$NVWB_USERNAME"
else
    echo "User '$NVWB_USERNAME' already exists; skipping useradd."
fi

echo "=== Changing ownership of directories ==="
chown "$NVWB_USERNAME":"$NVWB_USERNAME" /mnt/milvus
chown "$NVWB_USERNAME":"$NVWB_USERNAME" /data

echo "=== Installing git-lfs ==="
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
if [ -w /var/lib/apt/lists ]; then
    apt-get -o Dir::State::lock=/tmp/apt.lock -y install git-lfs
else
    echo "APT cache not writable; skipping git-lfs installation via apt."
fi

echo "=== Configuring docker-in-docker ==="
cat <<EOM | tee /etc/profile.d/docker-in-docker.sh > /dev/null
if ! groups $NVWB_USERNAME | grep docker > /dev/null; then
    docker_gid=\$(stat -c %g /var/host-run/docker.sock)
    groupadd -g \$docker_gid docker
    usermod -aG docker $NVWB_USERNAME
fi
EOM

echo "=== Granting sudo access to user ==="
echo "$NVWB_USERNAME ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/00-workbench > /dev/null

echo "=== postBuild.bash completed successfully ==="