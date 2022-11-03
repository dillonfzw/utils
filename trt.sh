#! /usr/bin/env bash

#
# Build TensorRT engine from ONNX models and run inference benchmark
#
MODEL_IDX=${MODEL_IDX:-0}
declare -a ONNX_MODELS_MATRIX=(
    # Number of matrix/table's columns
    4
    # ------------------------------------------------------------
    # 0: Model's index which starts from 0
    # -> [1] Model file name
    "clip_resnet50_16.onnx"
        # -> [2] Model input node's name in graph
        "input"
        # -> [3] Model input node's shape w/o batch dimension
        "3x384x384"
        # -> [4] batch(s) to be tested. Empty means to use fixed number in the model.
        "1 4 8 16 32 64"
    # ------------------------------------------------------------
    # 1
    "clip_resnet50_attentionpool.onnx"
        "input"
        "3x224x224"
        "1 4 8 16 32 64"
    # ------------------------------------------------------------
    # 2
    "clip_resnet50_64.onnx"
        "input"
        "3x448x448"
        "1 4 8 16 32 64"
    # ------------------------------------------------------------
    # 3
    "clip_resnet50_64_attentionpool.onnx"
        "input"
        "3x448x448"
        "1 4 8 16 32 64"
    # ------------------------------------------------------------
    # 4
    "BEVDet.onnx"
        "input"
        "6x3x512x1408"
        ""
    # ------------------------------------------------------------
    # 5
    "BEVDet-sim.onnx"
        "input"
        "6x3x256x704"
        ""
    # ------------------------------------------------------------
    # 6
    "PETR.onnx"
        "img"
        "6x3x256x704"
        ""
    # ------------------------------------------------------------
    # 7
    "fcos3d.onnx"
        "input"
        "3x928x1600"
        ""
    # ------------------------------------------------------------
    # 8
    "vovnet_backbone.onnx"
        "input"
        "3x9238x1600"
        "1"
)
N_COLS=${ONNX_MODELS_MATRIX[0]}
ONNX_FILE=${ONNX_MODELS_MATRIX[$((MODEL_IDX*N_COLS+1))]}
INPUT_NAME=${ONNX_MODELS_MATRIX[$((MODEL_IDX*N_COLS+2))]}
INPUT_SHAPE=${ONNX_MODELS_MATRIX[$((MODEL_IDX*N_COLS+3))]}
declare -a bss=(${ONNX_MODELS_MATRIX[$((MODEL_IDX*N_COLS+4))]})
DTYPE=${DTYPE:-""}
N_BSS=${#bss[@]}
if [ "${N_BSS}" -gt 0 ]; then
    MIN_BS=${bss[0]}
    OPT_BS=${bss[$((N_BSS>>1))]}
    MAX_BS=${bss[$((N_BSS-1))]}
    _minShapes="${INPUT_NAME}:${MIN_BS}x${INPUT_SHAPE}"
    _optShapes="${INPUT_NAME}:${OPT_BS}x${INPUT_SHAPE}"
    _maxShapes="${INPUT_NAME}:${MAX_BS}x${INPUT_SHAPE}"
fi
ENGINE_FILE=`basename ${ONNX_FILE} .onnx`-${DTYPE:+${DTYPE}-}${INPUT_SHAPE}.trt
PROFILE=profile-`basename ${ENGINE_FILE} .trt`.json
LAYER_FILE=layer-`basename ${ENGINE_FILE} .trt`.json
LOG_FILE=log.`basename ${ENGINE_FILE} .trt`


#  --minShapes=${INPUT_NAME}:${MIN_BS}x${INPUT_SHAPE} \
#  --optShapes=${INPUT_NAME}:${OPT_BS}x${INPUT_SHAPE} \
#  --maxShapes=${INPUT_NAME}:${MAX_BS}x${INPUT_SHAPE} \
#  --shapes=${INPUT_NAME}:${MIN_BS}x${INPUT_SHAPE} \

[ ! -f ${ENGINE_FILE} ] && trtexec \
  --onnx=${ONNX_FILE} \
  --saveEngine=${ENGINE_FILE} \
  --buildOnly \
  --workspace=8g \
  ${_minShapes:+"--minShapes=${_minShapes}"} \
  ${_optShapes:+"--optShapes=${_optShapes}"} \
  ${_maxShapes:+"--maxShapes=${_maxShapes}"} \
  --profilingVerbosity=detailed \
  ${DTYPE:+"--${DTYPE}"} \
  --dumpProfile \
  --exportProfile=${PROFILE} \
  --dumpLayerInfo \
  --exportLayerInfo=${LAYER_FILE} \
  --verbose 2>&1 | tee ${LOG_FILE}

[ -f ${ENGINE_FILE} ] && for bs in ${bss[@]}; do trtexec \
  --loadEngine=${ENGINE_FILE} \
  ${DTYPE:+"--${DTYPE}"} \
  ${_optShapes:+"--shapes=${INPUT_NAME}:${bs}x${INPUT_SHAPE}"} \
  --iterations=20 \
  --verbose 2>&1 | tee -a ${LOG_FILE}
done

