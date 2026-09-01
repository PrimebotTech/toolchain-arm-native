# Orin 平台开发指南

本文档说明在 NVIDIA Jetson Orin 平台上开发时需要注意的事项。

---

## 平台特征

| 项目 | 说明 |
|------|------|
| 基础镜像 | `nvcr.io/nvidia/l4t-base:r36.2.0`（JetPack 6） |
| 编译镜像名 | `native-aarch64-orin` |
| 硬件加速 | CUDA 12.6 + cuDNN 9 + TensorRT |
| 适用场景 | 需要 GPU 推理的 NVIDIA Jetson 平台 |

## 已预装依赖

编译容器（`native-aarch64-orin`）中包含以下库：

- **ROS 2 Humble** — 手动安装 `ros-humble-ros-base`
- **CUDA 12.6** — `cuda-12-6`
- **cuDNN 9** — `libcudnn9-dev-cuda-12`
- **TensorRT** — `tensorrt`
- **OpenCV** — `libopencv-dev`、`python3-opencv`（系统版本，含 CUDA 支持）
- **ONNX Runtime 1.18.0** — 安装在 `/usr/local/onnxruntime`
- **FFmpeg** — `ffmpeg`
- **Eigen3** — `libeigen3-dev`
- **yaml-cpp** — `libyaml-cpp-dev`
- **Python 绑定** — `pybind11-dev`、`empy==3.3.4`、`lark`

## 开发注意事项

### 1. CUDA / TensorRT 加速

Orin 平台拥有 NVIDIA GPU，可充分利用硬件加速能力：

```cpp
#include <onnxruntime_cxx_api.h>

Ort::SessionOptions session_options;

// 使用 CUDA EP（GPU 推理）
OrtCUDAProviderOptions cuda_options;
cuda_options.device_id = 0;
session_options.AppendExecutionProvider_CUDA(cuda_options);

Ort::Session session(env, model_path, session_options);
```

### 2. TensorRT 执行提供程序

对于推理性能要求极高的场景，可以使用 TensorRT EP：

```cpp
OrtTensorRTProviderOptions trt_options;
trt_options.device_id = 0;
trt_options.trt_fp16_enable = 1;       // 启用 FP16 加速
trt_options.trt_engine_cache_enable = 1; // 缓存引擎避免重复构建
trt_options.trt_engine_cache_path = "/tmp/trt_cache";

session_options.AppendExecutionProvider_TensorRT(trt_options);
```

> **建议**：优先使用 TensorRT EP → CUDA EP → CPU EP，按需选择。首次使用 TensorRT EP 构建引擎需要较长时间，建议开启引擎缓存。

### 3. FP16 推理

Orin 的 GPU 对 FP16 有良好支持，推荐使用 FP16 模型以获得更好的推理性能：

- 在模型导出时转为 FP16 精度
- 或使用 TensorRT EP 的自动 FP16 转换

### 4. 跨平台兼容

如果代码需要同时支持 RK 和 Orin，建议通过 cmake 选项控制 GPU 功能开关：

```cmake
option(USE_CUDA "Enable CUDA support" OFF)

if(USE_CUDA)
    find_package(CUDAToolkit REQUIRED)
    add_definitions(-DUSE_CUDA)
endif()
```

编译时分别指定：

```bash
# Orin：启用 CUDA
colcon build --cmake-args -DUSE_CUDA=ON

# RK：不启用
colcon build --cmake-args -DUSE_CUDA=OFF
```

### 5. OpenCV CUDA 支持

Orin 平台的系统 OpenCV 已包含 CUDA 模块，可直接使用 GPU 图像处理：

```cpp
#include <opencv2/opencv.hpp>

cv::Mat d_img;
cv::cuda::GpuMat gpu_img;

// 上传到 GPU
gpu_img.upload(h_img);

// GPU 上执行 resize
cv::cuda::resize(gpu_img, gpu_resized, cv::Size(640, 640));

// 下载回 CPU
gpu_resized.download(d_img);
```

### 6. 编译路径

CUDA 相关库的搜索路径已包含在容器中。在 `CMakeLists.txt` 中：

```cmake
if(USE_CUDA)
    find_package(CUDAToolkit REQUIRED)
    find_package(TensorRT)
endif()
```

### 7. 部署注意

Orin 目标板通常已预装 JetPack（含 CUDA/cuDNN/TensorRT），部署时需确保：

- 目标板的 JetPack 版本与编译时使用的 L4T 版本（r36.2.0）匹配
- `/usr/local/onnxruntime/lib` 在 `LD_LIBRARY_PATH` 中
- CUDA 库路径（`/usr/local/cuda/lib64`）在 `LD_LIBRARY_PATH` 中
