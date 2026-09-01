# RK 平台开发指南

本文档说明在 RK（通用 ARM64）平台上开发时需要注意的事项。

---

## 平台特征

| 项目 | 说明 |
|------|------|
| 基础镜像 | `ros:humble-ros-base`（Ubuntu 22.04 + ROS 2 Humble） |
| 编译镜像名 | `native-aarch64-rk` |
| 硬件加速 | 无 CUDA / GPU 推理能力 |
| 适用场景 | 通用 ARM64 设备部署，纯 CPU 推理 |

## 已预装依赖

编译容器（`native-aarch64-rk`）中包含以下库：

- **ROS 2 Humble** — `ros-humble-ros-base`
- **OpenCV** — `libopencv-dev`（CPU 版本）
- **ONNX Runtime 1.18.0** — 安装在 `/usr/local/onnxruntime`
- **Eigen3** — `libeigen3-dev`
- **yaml-cpp** — `libyaml-cpp-dev`
- **FFmpeg** — `libavcodec-dev`、`libavformat-dev`、`libswscale-dev`
- **图像处理** — `libjpeg-dev`、`libpng-dev`、`libtiff-dev`
- **Python 绑定** — `pybind11-dev`、`empy==3.3.4`、`lark`

## 开发注意事项

### 1. 不要使用 CUDA API

RK 平台没有 NVIDIA GPU，代码中不要依赖任何 CUDA / cuDNN / TensorRT 接口。如果你的代码需要兼容两个平台，建议使用宏定义或运行时检测：

```cpp
#ifdef USE_CUDA
    // CUDA 相关代码（仅在 Orin 上启用）
#else
    // CPU fallback
#endif
```

编译时通过 cmake 参数控制：

```bash
colcon build --cmake-args -DUSE_CUDA=OFF
```

### 2. ONNX Runtime 使用

ONNX Runtime 的 CPU 执行提供程序（CPU EP）在 RK 平台上是主要推理后端：

```cpp
#include <onnxruntime_cxx_api.h>

Ort::SessionOptions session_options;
// RK 平台只使用 CPU EP，无需额外配置
Ort::Session session(env, model_path, session_options);
```

> 部署时确保 `/usr/local/onnxruntime/lib` 在 `LD_LIBRARY_PATH` 中。

### 3. 性能优化建议

由于没有 GPU 加速，在 RK 平台上需要特别关注 CPU 推理性能：

- **模型量化**：优先使用 INT8 量化模型，可显著降低 CPU 推理延迟
- **线程配置**：合理设置 `intra_op_num_threads` 和 `inter_op_num_threads`
- **内存对齐**：确保输入 Tensor 的内存对齐，避免不必要的拷贝

### 4. 编译路径

所有依赖库的搜索路径已配置在容器中，`CMakeLists.txt` 中正常使用 `find_package` 即可，无需手动指定路径：

```cmake
find_package(OpenCV REQUIRED)
find_package(Eigen3 REQUIRED)
find_package(rclcpp REQUIRED)
```
