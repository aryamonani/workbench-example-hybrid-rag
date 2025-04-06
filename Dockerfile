# Use the huggingface text-generation-inference base image for AMD64
FROM --platform=linux/amd64 ghcr.io/huggingface/text-generation-inference:2.3.0

# Set the working directory
WORKDIR /app

# Environment variables for user/group setup
ENV NVWB_UID=1000 \
    NVWB_GID=1000 \
    NVWB_USERNAME=workbench

# Install needed system packages, create directories, and clean up caches
RUN apt-get update && \
    apt-get install -y sudo wget libgl1 libglib2.0-0 poppler-utils tesseract-ocr libtesseract-dev git jq && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt/project/build /data && \
    chown -R ${NVWB_UID}:${NVWB_GID} /opt/project/build /data

# Set up user and group (ignore error if they exist)
RUN groupadd -g ${NVWB_GID} workbench || true && \
    useradd -u ${NVWB_UID} -g ${NVWB_GID} -m -s /bin/bash ${NVWB_USERNAME} || true && \
    echo "${NVWB_USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${NVWB_USERNAME}

# Copy build scripts and requirements with proper ownership; ensure they are executable
COPY --chown=${NVWB_UID}:${NVWB_GID} preBuild.bash postBuild.bash requirements.txt /opt/project/build/
RUN chmod +x /opt/project/build/*.bash

# Run the build scripts (preBuild and postBuild) in one RUN layer
RUN /bin/bash /opt/project/build/preBuild.bash && \
    /bin/bash /opt/project/build/postBuild.bash

# Switch to the non-root user
USER ${NVWB_USERNAME}

# Expose required ports
EXPOSE 8080 8888

# Add NVIDIA AI Workbench labels (adjust as needed)
LABEL com.nvidia.workbench.build-timestamp="20231011102429" \
      com.nvidia.workbench.name="hybrid-rag-custom" \
      com.nvidia.workbench.cuda-version="11.8" \
      com.nvidia.workbench.description="A custom container for the Hybrid RAG application" \
      com.nvidia.workbench.programming-languages="python3" \
      com.nvidia.workbench.image-version="1.0.0" \
      com.nvidia.workbench.os="linux" \
      com.nvidia.workbench.os-distro="ubuntu" \
      com.nvidia.workbench.os-distro-release="20.04" \
      com.nvidia.workbench.schema-version="v2" \
      com.nvidia.workbench.platform="linux/amd64"