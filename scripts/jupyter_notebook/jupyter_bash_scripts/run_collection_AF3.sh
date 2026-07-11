#!/bin/bash

# Allow AlphaFold GPU access
module load cuda/12.9.0

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
BASE_OUTPUT_DIR="${SPEEDYFOLD_DIR}/outputs/collection_outputs/${CURRENT_RUN_DIR}"

# Submission json directory
JSON_DIR="${COLLECTION_JSON_DIR}"

# Get list of JSON files
shopt -s nullglob
JSON_FILES=(${JSON_DIR}/*.json)
shopt -u nullglob
TOTAL_FILES=${#JSON_FILES[@]}

if [ ${TOTAL_FILES} -eq 0 ]; then
    echo "ERROR: No JSON files found in ${JSON_DIR}"
    exit 1
fi

echo "================================================================"
echo "Starting AlphaFold3 Collection Run (Sequential)"
echo "================================================================"
echo "Run name:     ${CURRENT_RUN_DIR}"
echo "Total files:  ${TOTAL_FILES}"
echo "Output dir:   ${BASE_OUTPUT_DIR}"
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
    OUTPUT_DIR="${BASE_OUTPUT_DIR}/${BASE_NAME}"
    
    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Processing ${BASE_NAME} ($((i+1))/${TOTAL_FILES})"
    
    # Create output directory structure
    mkdir -p "${OUTPUT_DIR}"
    
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
    
    # Start progress indicator
    show_progress $((i+1)) ${TOTAL_FILES}
    
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
    
    # Update progress indicator to show completion
    show_progress $((i+1)) ${TOTAL_FILES}
    
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
        # Move all contents from nested directory up one level
        mv "${NESTED_DIR}"/* "${OUTPUT_DIR}/" 2>/dev/null
        # Move hidden files if any
        mv "${NESTED_DIR}"/.[!.]* "${OUTPUT_DIR}/" 2>/dev/null
        # Remove the now-empty nested directory
        rmdir "${NESTED_DIR}" 2>/dev/null
    fi
    
    # Clean up tmp directory (now inside OUTPUT_DIR)
    if [ -d "${TMPDIR}" ]; then
        rm -rf "${TMPDIR}"
    fi
    
    rm -rf "${BASE_OUTPUT_DIR}/tmp" 2>/dev/null
    
    echo ""
done

echo ""
echo "================================================================"
echo "Finished processing all ${TOTAL_FILES} files"
echo "End time: $(date)"
echo "Output location: ${BASE_OUTPUT_DIR}"
echo "================================================================"