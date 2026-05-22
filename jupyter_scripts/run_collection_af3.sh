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
#SBATCH --array=1-120  # 1-(total number of query sequences)

# Absolute directories
APPDIR="/cluster/tufts/cowenlab/jreill05/AlphaFold"
ALPHAFOLD3DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3"

# HMMER binaries from conda environment
HMMER3_BINDIR="/cluster/tufts/cowenlab/jreill05/Database_Conda_Environment/condaenv/AlphaFold3/bin"

# AF3 databases from the cluster
DB_DIR="/cluster/tufts/biocontainers/datasets/alphafold3/20241219/public_databases"

# Model parameters
MODEL_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3/models"

# Base output directory (changeable)
BASE_OUTPUT_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/speedyfold/outputs/collection_outputs/eureka"

# JSON files directory (changeable)
JSON_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/speedyfold/json_files/collection_json/test1"

# Get list of all JSON files
shopt -s nullglob
JSON_FILES=(${JSON_DIR}/*.json)
shopt -u nullglob
TOTAL_FILES=${#JSON_FILES[@]}

# Exit if no files
if [ $TOTAL_FILES -eq 0 ]; then
    echo "Error: No JSON files found in ${JSON_DIR}"
    exit 1
fi

# If this array task exceeds number of files, exit cleanly
if [ -n "$SLURM_ARRAY_TASK_ID" ] && [ $SLURM_ARRAY_TASK_ID -gt $TOTAL_FILES ]; then
    exit 0
fi

# Get the specific file for this array task
if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
    ARRAY_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
    JSON_FILE="${JSON_FILES[$ARRAY_INDEX]}"
else
    echo "Error: This script should be run as a job array"
    exit 1
fi

# Derive a name from the JSON file for the output folder
BASE_NAME=$(basename "${JSON_FILE}" .json)

# Output directory for this specific run
OUTPUT_DIR="${BASE_OUTPUT_DIR}/${BASE_NAME}"

# Log files
LOG_FILE="${OUTPUT_DIR}/af3_run.log"
mkdir -p "${OUTPUT_DIR}"

# Tmp directory for this job
export TMPDIR="${BASE_OUTPUT_DIR}/tmp/${BASE_NAME}"
mkdir -p "${TMPDIR}"

/cluster/tufts/cowenlab/jreill05/Database_Conda_Environment/condaenv/AlphaFold3/bin/python \
    /cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3/run_alphafold.py \
    --jackhmmer_binary_path="${HMMER3_BINDIR}/jackhmmer" \
    --nhmmer_binary_path="${HMMER3_BINDIR}/nhmmer" \
    --hmmalign_binary_path="${HMMER3_BINDIR}/hmmalign" \
    --hmmsearch_binary_path="${HMMER3_BINDIR}/hmmsearch" \
    --hmmbuild_binary_path="${HMMER3_BINDIR}/hmmbuild" \
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
fi