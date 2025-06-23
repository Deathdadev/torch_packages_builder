#! /bin/bash

set -eu -o pipefail

SCRIPT_DIR=${BASH_SOURCE%/*}

if [[ $REPO == "facebookresearch/Mask2Former" ]] \
  && [[ $COMPUTE_PLATFORM == "cpu" ]]; then
  patch -p0 < "$SCRIPT_DIR"/package_specific/Mask2Former_cpu.patch
fi

if { [[ $REPO == "rusty1s/pytorch_cluster" ]] || [[ $REPO == "facebookresearch/fairseq" ]]; } \
  && [[ $OS == "Windows" ]] \
  && [[ ${TORCH_VERSION:0:4} == "1.12" ]] \
  && [[ $COMPUTE_PLATFORM == "cu116" ]]; then
  # Fixes https://github.com/facebookresearch/pytorch3d/issues/1024
  # shellcheck disable=SC2154
  TORCH_PYBIND_DIR="$Python_ROOT_DIR/lib/site-packages/torch/include/pybind11"
  patch -d "$TORCH_PYBIND_DIR" < "$SCRIPT_DIR"/package_specific/torch_pybind_cast_h.patch
fi

if [[ $REPO == "facebookresearch/pytorch3d" ]] || [[ $REPO == "facebookresearch/fairseq" ]]; then
  CUB_VERSION=""
  if [[ $OS == "Windows" ]] \
    && [[ $REPO == "facebookresearch/pytorch3d" ]] \
    && { [[ $COMPUTE_PLATFORM == "cu117" ]] || [[ $COMPUTE_PLATFORM == "cu118" ]] || [[ $COMPUTE_PLATFORM == "cu121" ]]; }; then
    CUB_VERSION="1.17.2"
  fi
  if [[ $OS == "Linux" ]] \
    && { [[ $COMPUTE_PLATFORM == "cu102" ]] || [[ $COMPUTE_PLATFORM == "cu113" ]]; }; then
    CUB_VERSION="1.10.0"
  fi

  if [ -n "${CUB_VERSION}" ]; then
    mkdir cub
    curl -L https://github.com/NVIDIA/cub/archive/${CUB_VERSION}.tar.gz | tar -xzf - --strip-components=1 --directory cub
    echo "CUB_HOME=$PWD/cub" >> "$GITHUB_ENV"
  fi
fi

if [[ $REPO == "facebookresearch/pytorch3d" ]] \
  && [[ $OS == "Linux" ]] \
  && [[ $COMPUTE_PLATFORM == "cu102" ]]; then
  patch -p0 < "$SCRIPT_DIR"/package_specific/pytorch3d_cpp14.patch
fi

if [[ $REPO == "facebookresearch/fairseq" ]]; then
  pip install cython
  patch -p0 < "$SCRIPT_DIR"/package_specific/fairseq_cub.patch
fi

if [[ $REPO == "open-mmlab/mmcv" ]] \
  && [[ $TORCH_VERSION == "1.12.1" ]] \
  && [[ $COMPUTE_PLATFORM == "cu102" ]]; then
  patch -p0 < "$SCRIPT_DIR"/package_specific/mmcv_cpp14.patch
fi

if [[ $REPO == "NVlabs/tiny-cuda-nn" ]]; then
  source "$SCRIPT_DIR"/.github/workflows/cuda/${OS}_env.sh
  echo "LIBRARY_PATH=/usr/local/cuda/lib64/stubs" >> "$GITHUB_ENV"
  echo "TCNN_CUDA_ARCHITECTURES=${TORCH_CUDA_ARCH_LIST}" | sed "s/\(\.\|\+PTX\)//g" >> "$GITHUB_ENV"
fi

if [[ $REPO == "Deathdadev/torchsparse" ]]; then
  if [[ $OS == "Linux" ]]; then
    sudo apt-get update
    sudo apt-get install -y libsparsehash-dev
  elif [[ $OS == "Windows" ]]; then
    # 1. Clone the vcpkg repository. Using --depth 1 makes the clone much faster.
    echo "Cloning vcpkg..."
    git clone --depth 1 https://github.com/Microsoft/vcpkg.git
    
    # 2. Bootstrap vcpkg. This builds the vcpkg executable.
    # The .sh script works correctly in the Git Bash shell provided by GitHub Actions.
    echo "Bootstrapping vcpkg..."
    ./vcpkg/bootstrap-vcpkg.sh -disableMetrics
    
    # 3. Integrate vcpkg with the build environment.
    # This is a crucial step. It tells MSBuild/MSVC how to automatically find
    # libraries installed by vcpkg, so you don't have to manually set INCLUDE/LIB paths.
    echo "Integrating vcpkg..."
    ./vcpkg/vcpkg integrate install
    
    # 4. Install the required library.
    echo "Installing sparsehash..."
    ./vcpkg/vcpkg install sparsehash:x64-windows
  fi
fi
