#!/bin/bash
#SBATCH --job-name=AlphaFold3_Collection
#SBATCH --time=3-0:00:00 #requested time (DD-HH:MM:SS)
#SBATCH -p gpu,preempt
#SBATCH --gres=gpu:a100:1
#SBATCH -N 1 #1 nodes
#SBATCH -n 1 #1 tasks total (default 1 CPU core per task) = # of cores
#SBATCH --mem=256GB
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null
#SBATCH --mail-type=ALL #email options
#SBATCH --mail-user=jackson.reilly@tufts.edu
#SBATCH --array=1-3  # 1-(total number of query sequences)

source $(dirname $0)/config.sh

shopt -s nullglob
JSON_FILES=(${COLLECTION_JSON_DIR}/*.json)
shopt -u nullglob
TOTAL_FILES=${#JSON_FILES[@]}

if [ $SLURM_ARRAY_TASK_ID -gt $TOTAL_FILES ]; then
    exit 0
fi

ARRAY_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
JSON_FILE="${JSON_FILES[$ARRAY_INDEX]}"
BASE_NAME=$(basename "${JSON_FILE}" .json)

OUTPUT_DIR="${COLLECTION_OUTPUT_DIR}/${BASE_NAME}"
mkdir -p "${OUTPUT_DIR}"

# Log file (with timestamp to prevent overwriting)
LOG_FILE="${OUTPUT_DIR}/af3_run_$(date +%Y%m%d_%H%M%S).log"

export TMPDIR="${COLLECTION_OUTPUT_DIR}/tmp/${BASE_NAME}"
mkdir -p "${TMPDIR}"

${CONDAPYTHON} ${ALPHAFOLD3DIR}/run_alphafold.py \
    --jackhmmer_binary_path="${HMMER_BINDIR}/jackhmmer" \
    --nhmmer_binary_path="${HMMER_BINDIR}/nhmmer" \
    --hmmalign_binary_path="${HMMER_BINDIR}/hmmalign" \
    --hmmsearch_binary_path="${HMMER_BINDIR}/hmmsearch" \
    --hmmbuild_binary_path="${HMMER_BINDIR}/hmmbuild" \
    --db_dir="${DB_DIR}" \
    --model_dir="${MODEL_DIR}" \
    --json_path="${JSON_FILE}" \
    --output_dir="${OUTPUT_DIR}" \
    --buckets="256,512,768,1024,1280,1536,2048,2560,3072,3584,4096,4608,5120" \
    2>&1 | tee -a "${LOG_FILE}"

NESTED_DIR="${OUTPUT_DIR}/${BASE_NAME}"

if [ -d "${NESTED_DIR}" ]; then
    # Move all contents from nested directory up one level
    mv "${NESTED_DIR}"/* "${OUTPUT_DIR}/" 2>/dev/null
    # Move hidden files if any
    mv "${NESTED_DIR}"/.[!.]* "${OUTPUT_DIR}/" 2>/dev/null
    # Remove the now-empty nested directory
    rmdir "${NESTED_DIR}" 2>/dev/null
fi

if [ -d "${TMPDIR}" ]; then
    rm -rf "${TMPDIR}"
    echo "Removed temporary directory: ${TMPDIR}" >> "${LOG_FILE}"
fi