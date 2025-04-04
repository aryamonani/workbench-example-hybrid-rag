FROM --platform=linux/amd64 ghcr.io/huggingface/text-generation-inference:2.3.0

# Upgrade pip
RUN pip install --upgrade pip

# Install Cargo (and Rust toolchain)
RUN apt-get update && apt-get install -y cargo

# Uninstall conflicting packages and install the correct versions
RUN pip uninstall -y grpcio grpcio-status protobuf && \
    pip install "grpcio>=1.70.0" "protobuf>=5.26.1,<6.0dev" grpcio-status

# Copy your requirements file into the container
COPY requirements.txt /app/requirements.txt

# Install Python dependencies from requirements.txt
RUN pip install --upgrade --force-reinstall -r /app/requirements.txt

# Set the working directory
WORKDIR /app

# Copy your application code into the container
COPY . /app

# Command to run your application
CMD ["python", "your_script.py"]

LABEL com.nvidia.workbench.build-timestamp="20231011102429"
LABEL com.nvidia.workbench.name="hybrid-rag-custom"
LABEL com.nvidia.workbench.cuda-version="11.8"
LABEL com.nvidia.workbench.description="A custom container for the Hybrid RAG application"
LABEL com.nvidia.workbench.entrypoint-script=""
LABEL com.nvidia.workbench.labels="ubuntu,python3,jupyterlab"
LABEL com.nvidia.workbench.programming-languages="python3"
LABEL com.nvidia.workbench.image-version="1.0.0"
LABEL com.nvidia.workbench.os="linux"
LABEL com.nvidia.workbench.os-distro="ubuntu"
LABEL com.nvidia.workbench.os-distro-release="20.04"
LABEL com.nvidia.workbench.schema-version="v2"
LABEL com.nvidia.workbench.platform="linux/amd64"