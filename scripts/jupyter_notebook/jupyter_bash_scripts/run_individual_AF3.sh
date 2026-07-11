#!/bin/bash

# Disable core dumps
ulimit -c 0

# Memory management
export XLA_PYTHON_CLIENT_PREALLOCATE=false
export XLA_PYTHON_CLIENT_ALLOCATOR=platform
export TF_FORCE_UNIFIED_MEMORY=1
export XLA_CLIENT_MEM_FRACTION=4.0

# Get the directory containing the config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the config file
source "${SCRIPT_DIR}/config.sh"

# Base output directory
BASE_OUTPUT_DIR="${SPEEDYFOLD_DIR}/outputs/individual_outputs/${CURRENT_RUN_DIR}"

# Submission json directory
JSON_DIR="${INITIAL_JSON_DIR}"

# Submission json file (takes the json file within JSON_DIR)
JSON_FILE=$(ls "${JSON_DIR}"/*.json 2>/dev/null | head -n 1)

# Check if JSON file exists
if [ -z "$JSON_FILE" ]; then
    echo "ERROR: No .json file found in ${JSON_DIR}"
    exit 1
fi

echo "================================================================"
echo "Starting AlphaFold3 Individual Run"
echo "================================================================"
echo "Run name:     ${CURRENT_RUN_DIR}"
echo "JSON file:    ${JSON_FILE}"
echo "Output dir:   ${BASE_OUTPUT_DIR}"
echo "================================================================"
echo ""

# Derive a name from the JSON file for the output folder
BASE_NAME=$(basename "${JSON_FILE}" .json)

# Create output directory structure
OUTPUT_DIR="${BASE_OUTPUT_DIR}/${BASE_NAME}"
mkdir -p "${OUTPUT_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing ${BASE_NAME}"

# Log files
LOG_FILE="${OUTPUT_DIR}/af3_run.log"

# Tmp directory (can be inside output for organization)
export TMPDIR="${OUTPUT_DIR}/tmp"
mkdir -p "${TMPDIR}"

# Create job info file
JOB_INFO_FILE="${OUTPUT_DIR}/job_id.log"

# Write job information to separate file
cat > "${JOB_INFO_FILE}" << EOF
=== AlphaFold3 Job Information ===
Run: ${CURRENT_RUN_DIR}
File: ${BASE_NAME}
Submit time: $(date)
===================================
EOF

# Print status and start progress indicator
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running AlphaFold3..."
echo "  Log file: ${LOG_FILE}"
echo "  This may take a while... (do not interrupt)"
echo ""

# Run AlphaFold3
${CONDA_DIR}/bin/python \
    ${ALPHAFOLD3DIR}/run_alphafold.py \
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

# Capture exit code
EXIT_CODE=$?

# Update job info file with completion status
{
    echo "End time:    $(date)"
    echo "==================================="
} >> "${JOB_INFO_FILE}"

if [ ${EXIT_CODE} -eq 0 ]; then
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ AlphaFold3 completed successfully"
else
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ AlphaFold3 failed (exit code: ${EXIT_CODE})"
    echo "    Check log: ${LOG_FILE}"
fi

# Fix nested directory structure
NESTED_DIR="${OUTPUT_DIR}/${BASE_NAME}"
if [ -d "${NESTED_DIR}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up nested directory structure..."
    # Move all contents from nested directory up one level
    mv "${NESTED_DIR}"/* "${OUTPUT_DIR}/" 2>/dev/null
    # Move hidden files if any
    mv "${NESTED_DIR}"/.[!.]* "${OUTPUT_DIR}/" 2>/dev/null
    # Remove the now-empty nested directory
    rmdir "${NESTED_DIR}" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Cleanup complete"
fi

# Clean up tmp directory (now inside OUTPUT_DIR)
if [ -d "${TMPDIR}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removing temporary files..."
    rm -rf "${TMPDIR}"
fi

rm -rf "${BASE_OUTPUT_DIR}/tmp" 2>/dev/null

echo ""
echo "================================================================"
echo "Finished processing: ${BASE_NAME}"
echo "Output location: ${OUTPUT_DIR}"
echo "================================================================"

# Exit with AlphaFold's exit code
exit ${EXIT_CODE}