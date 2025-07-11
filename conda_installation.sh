source /opt/miniconda/etc/profile.d/conda.sh
conda deactivate
conda remove -n gpu-env --all -y || true


ENV_NAME=gpu-env

conda create -n "$ENV_NAME" \
  python=3.11 \
  numpy=1.26.4 \
  tensorflow=2.15.0 \
  scipy \
  pandas \
  scikit-learn \
  matplotlib \
  seaborn \
  nbdime \
  ipykernel \
  -c conda-forge -y


conda activate gpu-env

pip install torch==2.2.2+cu121 torchvision==0.17.2+cu121 torchaudio==2.2.2 --index-url https://download.pytorch.org/whl/cu121

pip install \
  spacy==3.7.4 \
  protobuf~=4.23.4 \
  diskcache \
  huggingface_hub \
  ipywidgets \
  tiktoken \
  pymupdf \
  langchain==0.1.1 \
  langchain-community==0.0.13 \
  chromadb==0.4.22 \
  sentence-transformers==2.3.1


export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

nvcc --version

CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=75" \
  FORCE_CMAKE=1 \
  pip install llama-cpp-python --force-reinstall --no-deps --no-cache-dir -v

python -m ipykernel install --user --name gpu-env
