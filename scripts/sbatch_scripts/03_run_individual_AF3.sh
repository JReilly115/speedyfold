#!/bin/bash
#SBATCH --job-name=03_run_individual_AF3
#SBATCH --time=1-0:00:00  # requested time (DD-HH:MM:SS)
#SBATCH -p gpu,preempt
#SBATCH --gres=gpu:a100:1  # use a100 gpu for small-medium sized job and h200 gpu for large job
#SBATCH -N 1  # 1 node
#SBATCH -n 1  # 1 tasks total (default 1 CPU core per task) = # of cores
#SBATCH --cpus-per-task=8  # increase value for faster run time
#SBATCH --mem=128GB
#SBATCH --output=/dev/null  # use --output=slurm-%j.out to troubleshoot directory path errors, and --output=/dev/null otherwise
#SBATCH --error=/dev/null  # use --error=slurm-%j.err to troubleshoot directory path errors, and --error=/dev/null otherwise
#SBATCH --mail-type=ALL  # email options
#SBATCH --mail-user=jackson.reilly@tufts.edu

# Run Alphafold one time to generate MSA and template information that can be reused

# ================================================================================
# Note: in the case of errors running this file, adjust lines 10 and 11 for feedback (and alter line 8 based on HPC resources)
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

# Build paths from config variables
BASE_OUTPUT_DIR="${SPEEDYFOLD_DIR}/outputs/individual_outputs/${CURRENT_RUN_DIR}"
JSON_FILE="${INITIAL_JSON_DIR}/${INDIVIDUAL_BINDER}.json"

# Derive a name from the JSON file for the output folder
BASE_NAME=$(basename "${JSON_FILE}" .json)

# Create output directory structure
OUTPUT_DIR="${BASE_OUTPUT_DIR}/${BASE_NAME}"
mkdir -p "${OUTPUT_DIR}"

# Log files
LOG_FILE="${OUTPUT_DIR}/AF3_run.log"

# Tmp directory (inside output for organization)
export TMPDIR="${OUTPUT_DIR}/tmp"
mkdir -p "${TMPDIR}"

# Create job info file
JOB_INFO_FILE="${OUTPUT_DIR}/job_id.log"

# Write job information to separate file
cat > "${JOB_INFO_FILE}" << EOF
=== AlphaFold3 Job Information ===
SLURM Job ID: ${SLURM_JOB_ID}
SLURM Job Name: ${SLURM_JOB_NAME}
Submit time: $(date)
EOF

# Run AlphaFold3 using conda environment's python
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
    # Move all contents from nested directory up one level
    mv "${NESTED_DIR}"/* "${OUTPUT_DIR}/" 2>/dev/null
    # Move hidden files if any
    mv "${NESTED_DIR}"/.[!.]* "${OUTPUT_DIR}/" 2>/dev/null
    # Remove the now-empty nested directory
    rmdir "${NESTED_DIR}" 2>/dev/null
fi

# Clean up tmp directory
if [ -d "${TMPDIR}" ]; then
    rm -rf "${TMPDIR}"
fi

# Clean up any stray tmp directories
rm -rf "${BASE_OUTPUT_DIR}/tmp" 2>/dev/null