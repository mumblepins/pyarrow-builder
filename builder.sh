#!/bin/bash
set -ex
ARROW_VERSION="$1"
PYTHON_VERSION="$2"
FILENAME="pyarrow-$ARROW_VERSION-py${PYTHON_VERSION}-$(uname -m).zip"
NINJA=ninja-build
VERSION=$ARROW_VERSION
base_dir="$PWD"
export CCACHE_DIR="${base_dir}/.ccache"
mkdir -p "$CCACHE_DIR"
mkdir -p lambda
mkdir -p .cached_build
cd lambda

export ARROW_HOME=$(pwd)/dist
export LD_LIBRARY_PATH=$(pwd)/dist/lib:$LD_LIBRARY_PATH

git clone \
  --depth 1 \
  --branch apache-arrow-${VERSION} \
  --single-branch \
  https://github.com/apache/arrow.git

mkdir -p $ARROW_HOME
mkdir -p arrow/cpp
mv "$base_dir/.cached_build" arrow/cpp/build

pushd arrow/cpp/build

cmake \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_INSTALL_PREFIX=$ARROW_HOME \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DARROW_PYTHON=ON \
  -DARROW_PARQUET=ON \
  -DARROW_DATASET=ON \
  -DARROW_WITH_SNAPPY=ON \
  -DARROW_WITH_ZLIB=ON \
  -DARROW_FLIGHT=OFF \
  -DARROW_GANDIVA=OFF \
  -DARROW_ORC=OFF \
  -DARROW_CSV=ON \
  -DARROW_JSON=ON \
  -DARROW_COMPUTE=ON \
  -DARROW_FILESYSTEM=ON \
  -DARROW_PLASMA=OFF \
  -DARROW_WITH_BZ2=OFF \
  -DARROW_WITH_ZSTD=OFF \
  -DARROW_WITH_LZ4=OFF \
  -DARROW_WITH_BROTLI=OFF \
  -DARROW_BUILD_TESTS=OFF \
  -GNinja \
  ..

eval $NINJA
eval "${NINJA} install"

popd

pushd arrow/python

export CMAKE_PREFIX_PATH=${ARROW_HOME}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}
export ARROW_PRE_0_15_IPC_FORMAT=0
export PYARROW_WITH_HDFS=0
export PYARROW_WITH_FLIGHT=0
export PYARROW_WITH_GANDIVA=0
export PYARROW_WITH_ORC=0
export PYARROW_WITH_CUDA=0
export PYARROW_WITH_PLASMA=0
export PYARROW_WITH_PARQUET=1
export PYARROW_WITH_DATASET=1
export PYARROW_WITH_FILESYSTEM=1
export PYARROW_WITH_CSV=1
export PYARROW_WITH_JSON=1
export PYARROW_WITH_COMPUTE=1

python3 setup.py build_ext \
  --build-type=release \
  --bundle-arrow-cpp \
  bdist_wheel

pip3 install dist/pyarrow-*.whl -t "$base_dir"/dist/pyarrow_files

popd

pushd "$base_dir"

rm -rf python/pyarrow*
rm -rf python/boto*

rm -f "$base_dir"/dist/pyarrow_files/pyarrow/libarrow.so
rm -f "$base_dir"/dist/pyarrow_files/pyarrow/libparquet.so
rm -f "$base_dir"/dist/pyarrow_files/pyarrow/libarrow_python.so

mkdir -p python
cp -r "$base_dir"/dist/pyarrow_files/pyarrow* python/

# Removing nonessential files
find python -name '*.so' -type f -exec strip "{}" \;
find python -name '*.so.*' -type f -exec strip "{}" \;
find python -name '*.a' -type f -delete
find python -wholename "*/tests/*" -type f -delete
find python -regex '^.*\(__pycache__\|\.py[co]\)$' -delete

zip -r9 "${FILENAME}" ./python
mv "${FILENAME}" dist/

#rm -rf python dist/pyarrow_files "${FILENAME}"

popd

mv "$base_dir/lambda/arrow/cpp/build" "$base_dir/.cached_build" || true
