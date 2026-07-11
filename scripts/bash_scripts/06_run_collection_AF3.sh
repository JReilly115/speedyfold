#!/bin/bash

# Run a collection of AlphaFold jobs simultaneously using the realigned MSAs generated during the individual run of Alphafold

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

# Load CUDA module
module load "$CUDA"

# Get list of all JSON files
shopt -s nullglob
JSON_FILES=(${COLLECTION_JSON_DIR}/*.json)
shopt -u nullglob
TOTAL_FILES=${#JSON_FILES[@]}

# Print startup information
echo "================================================================"
echo "Starting AlphaFold3 Collection Run"
echo "================================================================"
echo "Run name:     ${CURRENT_RUN_DIR}"
echo "Total files:  ${TOTAL_FILES}"
echo "Output dir:   ${COLLECTION_OUTPUT_DIR}/${CURRENT_RUN_DIR}"
echo "================================================================"
echo ""

# Progress indicator function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' ' '
    printf "] %3d%% (%d/%d)" "$percent" "$current" "$total"
}

# Process each JSON file sequentially
for ((i=0; i<TOTAL_FILES; i++)); do
    JSON_FILE="${JSON_FILES[$i]}"
    BASE_NAME=$(basename "${JSON_FILE}" .json)
    OUTPUT_DIR="${COLLECTION_OUTPUT_DIR}/${CURRENT_RUN_DIR}/${BASE_NAME}"
    
    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Processing ${BASE_NAME} ($((i+1))/${TOTAL_FILES})"
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    export TMPDIR="${OUTPUT_DIR}/tmp"
    mkdir -p "${TMPDIR}"
    
    LOG_FILE="${OUTPUT_DIR}/AF3_run.log"
    JOB_INFO_FILE="${OUTPUT_DIR}/job_id.log"
    
    # Write job information to separate file
    cat > "${JOB_INFO_FILE}" << EOF
=== AlphaFold3 Job Information ===
Run: ${RUN_NAME}
File: ${BASE_NAME}
Submit time: $(date)
EOF
    
    # Show progress
    show_progress $((i+1)) ${TOTAL_FILES}
    
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
    
    # Show progress completion
    show_progress $((i+1)) ${TOTAL_FILES}
    echo -e "\nProgress: $((i+1))/${TOTAL_FILES} files completed ($(( ($i+1) * 100 / TOTAL_FILES ))%)"
    
    # Update job info file with end time only
    {
        echo "End time:    $(date)"
        echo "==================================="
    } >> "${JOB_INFO_FILE}"
    
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished ${BASE_NAME}"
    
    # Fix nested directory structure
    NESTED_DIR="${OUTPUT_DIR}/${BASE_NAME}"
    if [ -d "${NESTED_DIR}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up nested directory structure..."
        mv "${NESTED_DIR}"/* "${OUTPUT_DIR}/" 2>/dev/null
        mv "${NESTED_DIR}"/.[!.]* "${OUTPUT_DIR}/" 2>/dev/null
        rmdir "${NESTED_DIR}" 2>/dev/null
    fi
    
    # Clean up tmp directory
    if [ -d "${TMPDIR}" ]; then
        rm -rf "${TMPDIR}"
    fi
    
    echo ""
done

echo ""
echo "================================================================"
echo "Finished processing all ${TOTAL_FILES} files"
echo "End time: $(date)"
echo "Output location: ${COLLECTION_OUTPUT_DIR}/${CURRENT_RUN_DIR}"
echo "================================================================"