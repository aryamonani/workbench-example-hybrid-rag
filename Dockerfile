# Use the huggingface text-generation-inference base image for AMD64
FROM --platform=linux/amd64 ghcr.io/huggingface/text-generation-inference:2.3.0

# Set the working directory
WORKDIR /app

# Set default environment variables (these can be overridden by AI Workbench)
ENV NVWB_UID=1000
ENV NVWB_GID=1000
ENV NVWB_USERNAME=workbench

# Create the target directory for build scripts
RUN mkdir -p /opt/project/build

# Copy the postBuild.bash script into the image with proper ownership
COPY --chown=$NVWB_UID:$NVWB_GID postBuild.bash /opt/project/build/

# Make sure the script is executable
RUN chmod +x /opt/project/build/postBuild.bash

# Run the post-build script
RUN ["/bin/bash", "/opt/project/build/postBuild.bash"]

# Set the default runtime user
USER $NVWB_USERNAME

# Add NVIDIA AI Workbench container labels
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

# Expose the necessary ports
EXPOSE 8080 8888