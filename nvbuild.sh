#!/bin/bash
#
# Configure, build, and install Tensorflow
#

# Exit at error
set -e

Usage() {
  echo "Configure, build, and install Tensorflow."
  echo ""
  echo "  Usage: $0 [OPTIONS]"
  echo ""
  echo "    OPTIONS                        DESCRIPTION"
  echo "    --configonly                   Run configure step only"
  echo "    --noconfig                     Skip configure step"
  echo "    --noclean                      Retain intermediate build files"
  echo "    --testlist                     Build list of python kernel_tests"
  echo "    --v1                           Build TensorFlow v1 API"
  echo "    --v2                           Build TensorFlow v2 API"
  echo "    --bazel-cache                  Use Bazel build cache"
  echo "    --bazel-cache-download-only    Use Bazel build cache in download mode only. No cache upload"
}

CONFIGONLY=0
NOCONFIG=0
NOCLEAN=0
TESTLIST=0
TRITON=0
TF_API=1
BAZEL_CACHE=0
BAZEL_CACHE_NOUPLOAD=0

while [[ $# -gt 0 ]]; do
  case $1 in
    "--help"|"-h")   Usage; exit 1 ;;
    "--configonly")  CONFIGONLY=1 ;;
    "--noconfig")    NOCONFIG=1 ;;
    "--noclean")     NOCLEAN=1 ;;
    "--testlist")    TESTLIST=1 ;;
    "--triton")       TRITON=1 ;;
    "--v1")          TF_API=1 ;;
    "--v2")          TF_API=2 ;;
    "--bazel-cache") BAZEL_CACHE=1 ;;
    "--bazel-cache-download-only") BAZEL_CACHE_NOUPLOAD=1 ;;
    *)
      echo UNKNOWN OPTION $1
      echo Run $0 -h for help
      exit 1
  esac
  shift 1
done

export TF_NEED_CUDA=1
export TF_NEED_TENSORRT=1
export TF_CUDA_PATHS=/usr,/usr/local/cuda
export TF_CUDA_VERSION=$(echo "${CUDA_VERSION}" | cut -d . -f 1-2)
export TF_CUBLAS_VERSION=$(echo "${CUBLAS_VERSION}" | cut -d . -f 1)
export TF_CUDNN_VERSION=$(echo "${CUDNN_VERSION}" | cut -d . -f 1)
export TF_NCCL_VERSION=$(echo "${NCCL_VERSION}" | cut -d . -f 1)
export TF_TENSORRT_VERSION=$(echo "${TRT_VERSION}" | cut -d . -f 1)
if [[ "$TF_CUDA_VERSION" < "11.0" ]];then 
    export TF_CUDA_COMPUTE_CAPABILITIES="5.2,6.0,6.1,7.0,7.5"
else
    export TF_CUDA_COMPUTE_CAPABILITIES="5.2,6.0,6.1,7.0,7.5,8.0,8.6"
fi
export TF_ENABLE_XLA=1
export TF_NEED_HDFS=0
export TF_NEED_MKL=1
export TF_NEED_NUMA=1
# export CC_OPT_FLAGS="-march=sandybridge -mtune=broadwell -Wno-sign-compare"
export CC_OPT_FLAGS="-march=skylake -mtune=skylake -Wno-sign-compare"
# export CC_OPT_FLAGS="-march=x86-64-v4 -Wno-sign-compare"

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
export PYTHON_BIN_PATH=$(which python)
LIBCUDA_FOUND=$(ldconfig -p | awk '{print $1}' | grep libcuda.so | wc -l)
if [[ $NOCONFIG -eq 0 ]]; then
  if [[ "$LIBCUDA_FOUND" -eq 0 ]]; then
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64/stubs
      ln -fs /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
  fi
  yes "" | ./configure
fi

if [[ $CONFIGONLY -eq 1 ]]; then
  exit 0
fi

unset BAZEL_CACHE_FLAG
if [[ $BAZEL_CACHE -eq 1 || $BAZEL_CACHE_NOUPLOAD -eq 1 ]]; then
  export BAZEL_CACHE_FLAG="$(${THIS_DIR}/nvbazelcache)"
fi
if [[ $BAZEL_CACHE_NOUPLOAD -eq 1 && ! -z "$BAZEL_CACHE_FLAG" ]]; then
  export BAZEL_CACHE_FLAG="$BAZEL_CACHE_FLAG --remote_upload_local_results=false"
fi
echo "Bazel Cache Flag: $BAZEL_CACHE_FLAG"

export OUTPUT_DIRS="tensorflow/python/kernel_tests tensorflow/compiler/tests /tmp/pip /usr/local/lib/tensorflow"
export BUILD_OPTS="${THIS_DIR}/nvbuildopts"
export IN_CONTAINER="0"
export TESTLIST
export TRITON
export NOCLEAN
export LIBCUDA_FOUND
export TF_API
bash ${THIS_DIR}/bazel_build.sh

