#! /usr/bin/env bash


declare PRECISION=${PRECISION:-""}
if [ "x${1}" = "xint8" -o "x${1}" = "xfp16" -o "x${1}" = "xfp32" ]; then true \
 && if [ "${1}" != "fp32" ]; then PRECISION="${1}"; fi \
 && shift \
 && true; \
fi

declare MODEL_IDX=${MODEL_IDX:-"0"}
if echo "${1}" | grep -sq "^[0-9]*$"; then true \
 && MODEL_IDX="${1}" \
 && shift \
 && true; \
fi

#
# Build TensorRT engine from ONNX models and run inference benchmark
#
declare -a MODELS_MATRIX=(
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
    # ------------------------------------------------------------
    # 9
    "resnet50_1080p_wo_gap_3d7a4c7e-dbs.onnx"
        "input.1"
        "3x1088x1920"
        "1 4 8 16 32 64"
    # ------------------------------------------------------------
    # 10
    "bevdet_bev_encoder_ca1b1548-dbs.onnx"
        "1114"
        "64x128x128"
        "1 4 8 16 32 64"
    # ------------------------------------------------------------
    # 11
    "bevdet_img_encoder_e06140a2-dbs.onnx"
        "743"
        "3x256x704"
        "1 4 8 16 32 64"
    # ------------------------------------------------------------
    # 12
    "resnet50_opset11_wo_gap_14ad8421-dbs.onnx"
        "input.1"
        "3x224x224"
        "1 4 8 16 32 64"
)
if echo "${1}" | grep -sq "^declare "; then true \
 && declare -a MODELS_MATRIX=`echo "${1}" | cut -d= -f2-` \
 && shift \
 && true; \
fi
#declare -p MODELS_MATRIX MODEL_IDX PRECISION
#exit 1
N_COLS=${MODELS_MATRIX[0]}
ONNX_FILE=${MODELS_MATRIX[$((MODEL_IDX*N_COLS+1))]}
INPUT_NAME=${MODELS_MATRIX[$((MODEL_IDX*N_COLS+2))]}
INPUT_SHAPE=${MODELS_MATRIX[$((MODEL_IDX*N_COLS+3))]}
declare -a BSS=(${MODELS_MATRIX[$((MODEL_IDX*N_COLS+4))]})
N_BSS=${#BSS[@]}
if [ "${N_BSS}" -gt 0 ]; then
    MIN_BS=${BSS[0]}
    OPT_BS=${BSS[$((N_BSS>>1))]}
    MAX_BS=${BSS[$((N_BSS-1))]}
    _minShapes="${INPUT_NAME}:${MIN_BS}x${INPUT_SHAPE}"
    _optShapes="${INPUT_NAME}:${OPT_BS}x${INPUT_SHAPE}"
    _maxShapes="${INPUT_NAME}:${MAX_BS}x${INPUT_SHAPE}"
fi
ENGINE_FILE=`basename ${ONNX_FILE} .onnx`-${PRECISION:+${PRECISION}-}${INPUT_SHAPE}.engine


#
# build engine
#
if [ ! -f ${ENGINE_FILE} ]; then true \
 && true "Build tensorrt engine..." \
 && declare LAYER_FILE=`basename ${ENGINE_FILE} .engine`-layer.json \
 && declare LOG_FILE=`basename ${ENGINE_FILE} .engine`-build.log \
 && trtexec \
      --onnx=${ONNX_FILE} \
      --saveEngine=${ENGINE_FILE} \
      --buildOnly \
      --memPoolSize=workspace:$((8<<10)) \
      ${_minShapes:+"--minShapes=${_minShapes}"} \
      ${_optShapes:+"--optShapes=${_optShapes}"} \
      ${_maxShapes:+"--maxShapes=${_maxShapes}"} \
      ${PRECISION:+"--${PRECISION}"} \
      --dumpLayerInfo \
      --exportLayerInfo=${LAYER_FILE} \
      --verbose 2>&1 | tee ${LOG_FILE} \
 && true; \
fi


#
# run inference
#
[ -f ${ENGINE_FILE} ] && for BS in ${_optShapes:-""} ${BSS[@]}; do true \
 && true "Run throughput benchmark..." \
 && declare LOG_FILE=`basename ${ONNX_FILE} .onnx`-${PRECISION:+${PRECISION}-}${BS}x${INPUT_SHAPE}-infer.log \
 && trtexec \
      --loadEngine=${ENGINE_FILE} \
      ${PRECISION:+"--${PRECISION}"} \
      ${_optShapes:+"--shapes=${INPUT_NAME}:${BS}x${INPUT_SHAPE}"} \
      --iterations=20 \
      --verbose 2>&1 | tee -a ${LOG_FILE} \
 && true "Run profiling..." \
 && declare LOG_FILE=`basename ${ONNX_FILE} .onnx`-${PRECISION:+${PRECISION}-}${BS}x${INPUT_SHAPE}-profile.log \
 && declare PROFILE=`basename ${ONNX_FILE} .onnx`-${PRECISION:+${PRECISION}-}${BS}x${INPUT_SHAPE}-profile.json \
 && trtexec \
      --loadEngine=${ENGINE_FILE} \
      ${PRECISION:+"--${PRECISION}"} \
      ${_optShapes:+"--shapes=${INPUT_NAME}:${BS}x${INPUT_SHAPE}"} \
      --profilingVerbosity=detailed \
      --dumpProfile \
      --exportProfile=${PROFILE} \
      --iterations=20 \
      --verbose 2>&1 | tee -a ${LOG_FILE} \
 && true; \
done
