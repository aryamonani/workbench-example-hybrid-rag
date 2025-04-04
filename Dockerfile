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