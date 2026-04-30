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
#SBATCH --array=1-3  # Can overestimate by setting it to 999 and it will stop at the last file. Or, can set it to an underestimate to do only the first few files

# Absolute directories
APPDIR="/cluster/tufts/cowenlab/jreill05/AlphaFold"
ALPHAFOLD3DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3"

# HMMER binaries from conda environment
HMMER3_BINDIR="/cluster/tufts/cowenlab/jreill05/Database_Conda_Environment/condaenv/AlphaFold3/bin"

# AF3 databases from the cluster
DB_DIR="/cluster/tufts/biocontainers/datasets/alphafold3/20241219/public_databases"

# Model parameters
MODEL_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3/models"

# Base output directory
BASE_OUTPUT_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/test_runs/outputs/ANARCI_test5"

# JSON files directory (where your Python script creates them)
JSON_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/test_runs/json_files/collection_test5"

# Get list of all JSON files
shopt -s nullglob
JSON_FILES=(${JSON_DIR}/*.json)
shopt -u nullglob
TOTAL_FILES=${#JSON_FILES[@]}

# Exit if no files
if [ $TOTAL_FILES -eq 0 ]; then
    echo "Error: No JSON files found in ${JSON_DIR}"
    echo "Make sure your Python script has run and created files in this directory"
    exit 1
fi

# If this array task exceeds number of files, exit cleanly
if [ -n "$SLURM_ARRAY_TASK_ID" ] && [ $SLURM_ARRAY_TASK_ID -gt $TOTAL_FILES ]; then
    echo "Array task $SLURM_ARRAY_TASK_ID exceeds number of files ($TOTAL_FILES). Exiting gracefully."
    exit 0
fi

# Get the specific file for this array task
if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
    # Adjust for zero-based indexing
    ARRAY_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
    
    # Safety check (redundant but good)
    if [ $ARRAY_INDEX -ge $TOTAL_FILES ] || [ $ARRAY_INDEX -lt 0 ]; then
        echo "Error: Array index $ARRAY_INDEX out of range (0-$((TOTAL_FILES-1)))"
        exit 1
    fi
    
    JSON_FILE="${JSON_FILES[$ARRAY_INDEX]}"
else
    # If not using array job (shouldn't happen with SBATCH --array)
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

# Run AlphaFold3
echo "Processing JSON file: ${JSON_FILE}" | tee -a "${LOG_FILE}"
echo "Output directory: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"
echo "Start time: $(date)" | tee -a "${LOG_FILE}"
echo "Array task: $SLURM_ARRAY_TASK_ID of up to $TOTAL_FILES total files" | tee -a "${LOG_FILE}"

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

echo "End time: $(date)" | tee -a "${LOG_FILE}"
echo "Job completed for ${BASE_NAME}" | tee -a "${LOG_FILE}"