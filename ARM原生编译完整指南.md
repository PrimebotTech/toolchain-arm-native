# ARM 原生编译完整指南

本文档介绍如何在 ARM 目标板上使用 Docker 容器进行 ARM (aarch64) 原生编译，适用于 RK 平台和 Orin 平台。

## 目录

- [前置要求](#前置要求)
  - [硬件架构](#硬件架构)
  - [软件要求](#软件要求)
  - [存储与网络](#存储与网络)
- [1. 准备编译环境](#1-准备编译环境)
  - [方式一：导入现成镜像（推荐）](#方式一导入现成镜像推荐)
  - [方式二：从零自行构建](#方式二从零自行构建)
  - [镜像导出与分发](#镜像导出与分发)
- [2. 进入容器并编译代码](#2-进入容器并编译代码)
  - [2.1 工作目录准备](#21-工作目录准备)
  - [2.2 启动容器](#22-启动容器)
  - [2.3 编译项目](#23-编译项目)
  - [2.4 集成自己的代码](#24-集成自己的代码)
    - [C++ 项目（ROS 2 / colcon）](#c-项目ros-2--colcon)
    - [Python 项目](#python-项目)
    - [混合项目（C++ + Python 绑定）](#混合项目c--python-绑定)
  - [2.5 常见编译选项](#25-常见编译选项)
- [3. 产物导出与部署](#3-产物导出与部署)
  - [3.1 编译产物结构](#31-编译产物结构)
  - [3.2 导出产物](#32-导出产物)
  - [3.3 运行编译产物](#33-运行编译产物)
  - [3.4 运行前检查清单](#34-运行前检查清单)
  - [3.5 Windows 换行符问题](#35-windows-换行符问题)
- [附录：与交叉编译的对比](#附录与交叉编译的对比)

---

## 前置要求

在开始之前，请确认目标板满足以下条件：

### 硬件架构

目标板 CPU 必须是 **aarch64 架构**（ARM 64位）。

> **x86 平台用户注意：** 如果你的开发主机是 x86 架构，请使用 `docker_x86_cross_arm` 项目进行交叉编译。

### 软件要求

- **Docker**：安装较新版本的 Docker Engine。确保 Docker 配置了足够的共享挂载权限，尤其是需要将 `~/workspace` 所在目录加入 Docker 的文件共享列表。

### 存储与网络

- **磁盘空间**：镜像构建完成后大约占用 **2-5 GB** 磁盘空间（RK 较小，Orin 含 CUDA 较大），建议预留 **15 GB** 以上用于编译和存储产物。

- **网络**：需能访问公网 Docker Hub、清华镜像源（Tuna）以及 GitHub（用于下载 ONNX Runtime）。

---

## 1. 准备编译环境

编译环境是一个运行在 ARM 目标板上的 Docker 容器，内含 ROS 2 Humble、OpenCV、ONNX Runtime 等所有必要的依赖。

你有两种方式获取该环境：**导入现成镜像**（推荐，快速）或 **从零自行构建**。

### 方式一：导入现成镜像（推荐）

如果已经有人构建好了镜像并导出为 `.tar.gz` 文件，直接导入即可：

```bash
# RK 平台
gunzip -c native-aarch64-rk.tar.gz | sudo docker load

# Orin 平台
gunzip -c native-aarch64-orin.tar.gz | sudo docker load
```

导入完成后，可用 `docker images` 确认镜像已就绪：

```bash
sudo docker images | grep native-aarch64
# 应看到 native-aarch64-rk 或 native-aarch64-orin
```

### 方式二：从零自行构建

如果需要修改依赖或重建环境，在本项目根目录下执行对应平台的构建脚本：

```bash
# RK 平台（基于 ros:humble-ros-base，不含 CUDA）
chmod +x rk/build_native_aarch64.sh && ./rk/build_native_aarch64.sh

# Orin 平台（基于 l4t-base:r36.2.0，含 CUDA / cuDNN / TensorRT）
chmod +x orin/build_native_aarch64.sh && ./orin/build_native_aarch64.sh
```

> 构建脚本内部调用了 `docker build`、`docker run` 等命令，需要 sudo 权限。如果当前用户未加入 docker 组，请先执行 `sudo usermod -aG docker $USER` 后重新登录。

构建过程会安装以下依赖：
- ROS 2 Humble 基础环境（RK 来自基础镜像，Orin 手动安装）
- OpenCV、FFmpeg 及图像/视频编解码库
- Python 3 及 pybind11、empy、lark 等
- ONNX Runtime 1.18.0（ARM64 预编译版）
- yaml-cpp、Eigen3 等开发库
- **仅 Orin**：CUDA 12.6、cuDNN 9、TensorRT

> **构建耗时：** 首次构建需要下载依赖，根据网络速度，RK 镜像大约需要 **30-60 分钟**，Orin 镜像（含 CUDA）可能需要 **1-2 小时**。构建完成后会自动进入容器 bash，输入 `exit` 退出即可。

### 镜像导出与分发

构建好的镜像可导出为压缩文件，方便分发给团队其他成员：

```bash
# 导出 RK 镜像
sudo docker save native-aarch64-rk | gzip > native-aarch64-rk.tar.gz

# 导出 Orin 镜像
sudo docker save native-aarch64-orin | gzip > native-aarch64-orin.tar.gz
```

---

## 2. 进入容器并编译代码

### 2.1 工作目录准备

在目标板上准备一个工作目录，将需要编译的代码放入其中：

```bash
# 在目标板 home 目录下创建 workspace
mkdir -p ~/workspace

# 将项目代码放入 workspace
cp -r /path/to/sdk_q1 ~/workspace/
cp -r /path/to/sdk_t1 ~/workspace/
```

> `~/workspace` 会挂载到容器内的 `/workspace`，编译结果直接保留在目标板上，容器退出后不会丢失。

### 2.2 启动容器

```bash
# RK 平台
sudo docker run -it --rm --net=host -v ~/workspace:/workspace -w /workspace native-aarch64-rk bash

# Orin 平台
sudo docker run -it --rm --net=host -v ~/workspace:/workspace -w /workspace native-aarch64-orin bash
```

参数说明：
| 参数 | 作用 |
|------|------|
| `-it` | 交互式终端 |
| `--rm` | 退出后自动删除容器（数据在 workspace 中已持久化） |
| `--net=host` | 共享目标板网络（编译过程中可能需要下载依赖） |
| `-v ~/workspace:/workspace` | 挂载目标板工作目录 |
| `-w /workspace` | 设置容器内默认工作目录 |

### 2.3 编译项目

容器内已预配置好编译环境，直接编译即可：

```bash
cd sdk_q1
colcon build

cd ../sdk_t1
colcon build
```

### 2.4 集成自己的代码

将你自己的项目代码放入 `~/workspace` 目录下，容器内即可访问和编译。以下是 C++ 和 Python 项目的集成方式。

#### C++ 项目（ROS 2 / colcon）

将你的 ROS 2 包放入 workspace：

```
~/workspace/
├── sdk_q1/
├── sdk_t1/
└── my_cpp_pkg/          # 你的 C++ 包
    ├── CMakeLists.txt
    ├── package.xml
    ├── include/
    │   └── my_cpp_pkg/
    │       └── my_node.hpp
    └── src/
        └── my_node.cpp
```

在容器内编译：

```bash
cd /workspace/my_cpp_pkg
colcon build
# 或回到 workspace 根目录一次性编译所有包：
cd /workspace
colcon build --packages-select my_cpp_pkg
```

#### Python 项目

Python 代码无需编译，但需要确保依赖在容器中可用。将 Python 包同样放入 workspace：

```
~/workspace/
├── sdk_q1/
└── my_python_pkg/       # 你的 Python 包
    ├── package.xml
    ├── setup.py
    ├── setup.cfg
    ├── resource/
    │   └── my_python_pkg
    └── my_python_pkg/
        ├── __init__.py
        └── my_node.py
```

在容器内安装/打包：

```bash
cd /workspace/my_python_pkg
pip3 install -e .
# 或用 colcon 构建：
cd /workspace
colcon build --packages-select my_python_pkg
```

> Python 包本身不需要编译，但如果依赖了 pybind11 等 C++ 扩展模块，则这些扩展会在 colcon build 时自动编译。

#### 混合项目（C++ + Python 绑定）

如果项目同时包含 C++ 核心和 Python 绑定（如使用 pybind11），按标准 ROS 2 包结构组织即可：

```
~/workspace/
└── my_hybrid_pkg/
    ├── CMakeLists.txt
    ├── package.xml
    ├── include/
    ├── src/              # C++ 源码
    └── my_hybrid_pkg/    # Python 包
        ├── __init__.py
        └── wrapper.py
```

`colcon build` 会自动处理 C++ 编译和 Python 绑定生成。

### 2.5 常见编译选项

```bash
# 编译指定包
colcon build --packages-select pkg_a pkg_b

# 编译指定包及其依赖
colcon build --packages-up-to pkg_a

# 清理后重新编译
rm -rf build/ install/ log/
colcon build

# 使用 cmake 参数
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release
```

---

## 3. 产物导出与部署

### 3.1 编译产物结构

`colcon build` 成功后，产物位于 workspace 内：

```
~/workspace/
├── sdk_q1/
│   ├── build/        # 编译中间文件（可删除）
│   ├── install/      # ★ 最终产物 — 部署的就是这个目录
│   └── log/          # 编译日志（可删除）
├── sdk_t1/
│   ├── build/
│   ├── install/
│   └── log/
```

`install/` 目录是部署所需的全部内容，包含：
- `lib/` — 编译生成的 `.so` 库文件和可执行文件
- `share/` — ROS 2 包的配置、launch 文件、参数文件等
- `local/lib/python3.10/` — Python 包和 C++ 扩展模块
- `setup.bash` / `local_setup.bash` — 环境变量加载脚本

### 3.2 导出产物

将 `install/` 目录整体拷贝到其他目标板（通过 SCP、U 盘、NFS 等）：

```bash
# 在目标板上，将产物打包
cd ~/workspace/sdk_q1
tar -czf sdk_q1_install.tar.gz install/

# 通过 SCP 传输到其他目标板
scp sdk_q1_install.tar.gz user@target-board:/opt/ros_ws/

# 在其他目标板上解压
ssh user@target-board
cd /opt/ros_ws
tar -xzf sdk_q1_install.tar.gz
```

### 3.3 运行编译产物

登录目标板后，按以下步骤运行：

```bash
# 1. 加载 ROS 2 基础环境
source /opt/ros/humble/setup.bash

# 2. 加载项目产物环境（设置 LD_LIBRARY_PATH 等）
source ~/ros_ws/sdk_q1/install/setup.bash

# 3. 直接执行二进制文件
~/ros_ws/sdk_q1/install/my_package/lib/my_package/my_node
# 或使用 ros2 run
ros2 run my_package my_node
```

> `source setup.bash` 仍然需要执行，它会设置 `LD_LIBRARY_PATH` 让运行时能找到编译产物中的 `.so` 库。

> 建议将上述 `source` 命令写入 `~/.bashrc` 或 `/opt/ros_ws/setup_env.sh`，避免每次手动加载。

### 3.4 运行前检查清单

- [ ] 目标板已安装 ROS 2 Humble 基础环境
- [ ] ONNX Runtime 已部署到 `/usr/local/onnxruntime`（与编译时路径一致）
- [ ] `LD_LIBRARY_PATH` 包含 `/usr/local/onnxruntime/lib`
- [ ] 模型文件已放置到指定目录（根据项目配置）
- [ ] 网络/设备权限已正确配置

### 3.5 Windows 换行符问题

如果代码从 Windows 下载后再传到 Linux 目标板，Shell 脚本可能带有 Windows 换行符（CRLF `\r\n`），导致执行报错：

```
/bin/bash^M: bad interpreter: No such file or directory
```

或

```
: command not found
```

#### 检测方法

```bash
# 检查文件是否包含 \r（Windows 换行符）
file setup.bash
# 如果输出包含 "CRLF line terminators"，说明有问题

# 或用 grep 检测
grep -q $'\r' setup.bash && echo "有 Windows 换行符" || echo "正常"
```

#### 解决方法

**方法一：使用 dos2unix（推荐）**
```bash
# 安装 dos2unix
sudo apt install dos2unix

# 转换单个文件
dos2unix setup.bash

# 批量转换 install 目录下所有文件
find install/ -type f -exec dos2unix {} +
```

**方法二：使用 sed**
```bash
# 转换单个文件
sed -i 's/\r$//' setup.bash

# 批量转换
find install/ -type f -exec sed -i 's/\r$//' {} +
```

**方法三：Git 自动转换（预防）**

在 Git 仓库根目录创建 `.gitattributes` 文件：
```
# 强制所有 .sh 文件使用 LF 换行
*.sh text eol=lf
*.bash text eol=lf

# 二进制文件保持原样
*.so binary
*.tgz binary
*.tar.gz binary
```

然后在 Windows 上配置 Git：
```bash
git config --global core.autocrlf false
```

> **建议：** 如果团队中有 Windows 用户，务必在仓库中添加 `.gitattributes` 文件，从源头避免换行符问题。

---

## 附录：与交叉编译的对比

| 对比项 | ARM 原生编译 | x86 交叉编译 |
|--------|-------------|-------------|
| **目标架构** | aarch64 (arm64) | aarch64 (arm64) |
| **编译位置** | ARM 目标板上直接编译 | x86 主机上交叉编译 |
| **镜像名称** | `native-aarch64-rk` / `native-aarch64-orin` | `cross-aarch64-rk` / `cross-aarch64-orin` |
| **镜像大小** | ~2-5 GB | RK ~5.4 GB / Orin ~44.6 GB |
| **运行方式** | 直接在 ARM 目标板运行 | 部署到 ARM 目标板运行 |
| **路径修复** | 不需要 | 需要 patch sysroot 路径 |
| **QEMU 模拟** | 不需要 | 需要（构建 rootfs 时） |
| **适用场景** | ARM 目标板直接开发调试 | x86 主机批量编译 ARM 代码 |

> 如果你的开发主机是 x86，请使用 `docker_x86_cross_arm` 项目进行交叉编译。
