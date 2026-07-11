#!/bin/bash
#SBATCH --job-name=06_run_collection_AF3
#SBATCH --time=1-0:00:00  # requested time (DD-HH:MM:SS)
#SBATCH -p gpu,preempt
#SBATCH --gres=gpu:a100:1  # use a100 gpu for small-medium sized job and h200 gpu for large job
#SBATCH -N 1  # 1 node
#SBATCH -n 1  # 1 tasks total (default 1 CPU core per task) = # of cores
#SBATCH --mem=128GB
#SBATCH --output=/dev/null  # use --output=slurm-%j.out to troubleshoot directory path errors, and --output=/dev/null otherwise
#SBATCH --error=/dev/null  # use --error=slurm-%j.err to troubleshoot directory path errors, and --error=/dev/null otherwise
#SBATCH --mail-type=ALL  # email options
#SBATCH --mail-user=jackson.reilly@tufts.edu
# Manually setting #SBATCH --array=1-(total number of binder sequences) will allow you to run this file standalone. Do not include the array command if running the master script
# Note: the number of binder sequences in your fasta file is equal to the number of lines in the file divided by 2 (there are 2 lines per binder) then subtracted by 1 (accounting for the target protein)

# Run a collection of AlphaFold jobs simultaneously using the realigned MSAs generated during the individual run of Alphafold

# ================================================================================
# Adjust line 13 in order to run this file standalone without the master script
# Note: in the case of errors running this file, adjust lines 9 and 10 for feedback
# ================================================================================

# Disable core dumps
ulimit -c 0

# Memory management
export XLA_PYTHON_CLIENT_PREALLOCATE=false
export XLA_PYTHON_CLIENT_ALLOCATOR=platform
export TF_FORCE_UNIFIED_MEMORY=1
export XLA_CLIENT_MEM_FRACTION=4.0

# Get the directory where this script is located
if [ -n "$SLURM_JOB_ID" ]; then
    FILE_PATH=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}' | cut -d' ' -f1)
    [ -z "$FILE_PATH" ] && FILE_PATH=$(realpath "$0")
fi

SUB_DIR="$(dirname "${FILE_PATH}")"
SCRIPT_DIR="$(dirname "${SUB_DIR}")"

# Source the config file
source "${SCRIPT_DIR}/config.sh"

# configurations file variable exports
export CONDAPYTHON
export ALPHAFOLD3DIR
export CONDA_DIR
export DB_DIR
export MODEL_DIR

# Load CUDA module
module load "$CUDA"

# Get list of all JSON files
shopt -s nullglob
JSON_FILES=(${COLLECTION_JSON_DIR}/*.json)
shopt -u nullglob
TOTAL_FILES=${#JSON_FILES[@]}

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
OUTPUT_DIR="${COLLECTION_OUTPUT_DIR}/${CURRENT_RUN_DIR}/${BASE_NAME}"

# Log files
LOG_FILE="${OUTPUT_DIR}/AF3_run.log"
JOB_INFO_FILE="${OUTPUT_DIR}/job_id.log"
mkdir -p "${OUTPUT_DIR}"
export TMPDIR="${OUTPUT_DIR}/tmp"
mkdir -p "${TMPDIR}"

# Write job information to separate file
cat > "${JOB_INFO_FILE}" << EOF
=== AlphaFold3 Job Information ===
SLURM Job ID: ${SLURM_JOB_ID}
SLURM Array Task ID: ${SLURM_ARRAY_TASK_ID}
SLURM Job Name: ${SLURM_JOB_NAME}
Submit time: $(date)
EOF

# Run AlphaFold3
${CONDAPYTHON} ${ALPHAFOLD3DIR}/run_alphafold.py \
    --jackhmmer_binary_path="${CONDA_DIR}/bin/jackhmmer" \
    --nhmmer_binary_path="${CONDA_DIR}/bin/nhmmer" \
    --hmmalign_binary_path="${CONDA_DIR}/bin/hmmalign" \
    --hmmsearch_binary_path="${CONDA_DIR}/bin/hmmsearch" \
    --hmmbuild_binary_path="${CONDA_DIR}/bin/hmmbuild" \
    --db_dir="${DB_DIR}" \
    --model_dir="${MODEL_DIR}" \
    --json_path="${JSON_FILE}" \
    --output_dir="${OUTPUT_DIR}" \
    --buckets="256,512,768,1024,1280,1536,2048,2560,3072,3584,4096,4608,5120" \
    2>&1 | tee -a "${LOG_FILE}"

# Update job info file with completion status
{
    echo "End time:    $(date)"
    echo "==================================="
} >> "${JOB_INFO_FILE}"

# Fix nested directory structure
NESTED_DIR="${OUTPUT_DIR}/${BASE_NAME}"
if [ -d "${NESTED_DIR}" ]; then
    mv "${NESTED_DIR}"/* "${OUTPUT_DIR}/" 2>/dev/null
    mv "${NESTED_DIR}"/.[!.]* "${OUTPUT_DIR}/" 2>/dev/null
    rmdir "${NESTED_DIR}" 2>/dev/null
fi

# Clean up tmp directory
if [ -d "${TMPDIR}" ]; then
    rm -rf "${TMPDIR}"
fi