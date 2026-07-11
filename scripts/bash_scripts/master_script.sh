#!/bin/bash

# This master script will run scripts 01 through 06 sequentially

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the config file
source "${SCRIPT_DIR}/config.sh"

# Get the file path to this script
if [ -n "$SLURM_JOB_ID" ]; then
    ORIGINAL_SCRIPT=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}' | cut -d' ' -f1)
    [ -z "$ORIGINAL_SCRIPT" ] && ORIGINAL_SCRIPT=$(realpath "$0")
else
    ORIGINAL_SCRIPT=$(realpath "$0")
fi

# Get the directory containing the configurations script
SCRIPT_DIR=$(dirname "$ORIGINAL_SCRIPT")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

# Source configurations file
source "${PARENT_DIR}/configurations.sh"

# Create directories...
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}"

# Run each script and wait for it to complete before continuing
JOB1=$(sbatch --parsable ${SCRIPT_DIR}/bash_scripts/01_create_empty_directories.sh)
sleep 5
while [[ $(squeue -j ${JOB1} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB2=$(sbatch --parsable ${SCRIPT_DIR}/bash_scripts/02_create_individual_json.sh)
sleep 5
while [[ $(squeue -j ${JOB2} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB3=$(sbatch --parsable ${SCRIPT_DIR}/bash_scripts/03_run_individual_AF3.sh)
sleep 5
while [[ $(squeue -j ${JOB3} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB4=$(sbatch --parsable ${SCRIPT_DIR}/bash_scripts/04_extract_MSAs.sh)
sleep 5
while [[ $(squeue -j ${JOB4} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB5=$(sbatch --parsable ${SCRIPT_DIR}/bash_scripts/05_align_MSAs.sh)
sleep 5
while [[ $(squeue -j ${JOB5} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JSON_COUNT=$(ls -1 ${COLLECTION_JSON_DIR}/*.json 2>/dev/null | wc -l)
if [ ${JSON_COUNT} -gt 0 ]; then
    sbatch --array=1-${JSON_COUNT} ${SCRIPT_DIR}/bash_scripts/06_run_collection_AF3.sh
fi