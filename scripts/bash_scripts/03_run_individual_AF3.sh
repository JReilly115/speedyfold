#!/bin/bash

# Run Alphafold one time to generate MSA and template information that can be reused

# Disable core dumps
ulimit -c 0

# Memory management
export XLA_PYTHON_CLIENT_PREALLOCATE=false
export XLA_PYTHON_CLIENT_ALLOCATOR=platform
export TF_FORCE_UNIFIED_MEMORY=1
export XLA_CLIENT_MEM_FRACTION=4.0

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
Run: ${RUN_NAME}
File: ${BASE_NAME}
Submit time: $(date)
EOF

# Print status
echo "================================================================"
echo "Starting AlphaFold3 Individual Run"
echo "================================================================"
echo "Run name:     ${CURRENT_RUN_DIR}"
echo "Binder:       ${INDIVIDUAL_BINDER}"
echo "Output dir:   ${OUTPUT_DIR}"
echo "================================================================"
echo ""

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing ${BASE_NAME}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file: ${LOG_FILE}"
echo ""

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

# Update job info file with end time only
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

echo ""
echo "================================================================"
echo "Finished processing: ${BASE_NAME}"
echo "End time: $(date)"
echo "Output location: ${OUTPUT_DIR}"
echo "================================================================"