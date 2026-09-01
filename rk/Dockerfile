FROM ros:humble-ros-base

ENV DEBIAN_FRONTEND=noninteractive

# --- 更换为国内镜像源 (以清华源为例) ---
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/ports.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list

# 安装项目所需的依赖包
RUN apt-get update && apt-get install -y \
    pybind11-dev \
    python3-pip \
    libopencv-dev \
    libyaml-cpp-dev \
    libeigen3-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖（empy 降级 + lark）
RUN pip3 install empy==3.3.4 lark -i https://pypi.tuna.tsinghua.edu.cn/simple

# 安装 ONNX Runtime（ARM64 预编译包）
ADD common/onnxruntime-linux-aarch64-1.18.0.tgz /usr/local/onnxruntime/
RUN mv /usr/local/onnxruntime/onnxruntime-linux-aarch64-1.18.0/* /usr/local/onnxruntime/ && \
    rmdir /usr/local/onnxruntime/onnxruntime-linux-aarch64-1.18.0

# 配置动态链接库路径并更新缓存
RUN echo '/usr/local/onnxruntime/lib' > /etc/ld.so.conf.d/onnxruntime.conf && \
    ldconfig
