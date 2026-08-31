FROM nvcr.io/nvidia/l4t-base:r36.2.0

ENV DEBIAN_FRONTEND=noninteractive

# 0. 更换为国内镜像源（加速 apt 下载）
RUN sed -i 's/ports.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list

# 1. 添加 NVIDIA 官方源（确保 CUDA/cuDNN/TensorRT 可用）
RUN apt-get update && apt-get install -y wget \
    && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/sbsa/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm cuda-keyring_1.1-1_all.deb

# 2. 安装系统依赖（使用系统 OpenCV，已包含 CUDA 支持）
RUN apt-get update && apt-get install -y -o Acquire::Queue-Mode=access -o Acquire::http::MaxParallel=10 \
    python3-pip \
    pybind11-dev \
    libopencv-dev \
    python3-opencv \
    libyaml-cpp-dev \
    libeigen3-dev \
    ffmpeg \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    cuda-12-6 \
    libcudnn9-dev-cuda-12 \
    tensorrt \
    && rm -rf /var/lib/apt/lists/*

# 3. 安装 ONNX Runtime（ARM64 预编译包）
ADD common/onnxruntime-linux-aarch64-1.18.0.tgz /usr/local/onnxruntime/
RUN mv /usr/local/onnxruntime/onnxruntime-linux-aarch64-1.18.0/* /usr/local/onnxruntime/ && \
    rmdir /usr/local/onnxruntime/onnxruntime-linux-aarch64-1.18.0

# 配置动态链接库路径并更新缓存
RUN echo '/usr/local/onnxruntime/lib' > /etc/ld.so.conf.d/onnxruntime.conf && \
    ldconfig

# 4. 安装 ROS2 Humble（最小安装）
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update && apt-get install -y \
    ros-humble-ros-base \
    python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*

# 5. 修复 empy 版本（解决 rosidl_adapter 的 AttributeError）
RUN pip3 install --upgrade --force-reinstall empy==3.3.4 -i https://pypi.tuna.tsinghua.edu.cn/simple
