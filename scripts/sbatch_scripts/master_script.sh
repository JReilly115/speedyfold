#!/bin/bash
#SBATCH --job-name=master_script
#SBATCH --output=/dev/null  # use --output=slurm-%j.out to troubleshoot directory path errors, and --output=/dev/null otherwise
#SBATCH --error=/dev/null  # use --error=slurm-%j.err to troubleshoot directory path errors, and --error=/dev/null otherwise
#SBATCH --time=1-0:00:00  # requested time (DD-HH:MM:SS)
#SBATCH --mem=128GB
#SBATCH --ntasks=1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jackson.reilly@tufts.edu

# This master script will run scripts 01 through 06 sequentially

# Get the directory where this script is located
if [ -n "$SLURM_JOB_ID" ]; then
    FILE_PATH=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}' | cut -d' ' -f1)
    [ -z "$FILE_PATH" ] && FILE_PATH=$(realpath "$0")
fi

SUB_DIR="$(dirname "${FILE_PATH}")"
SCRIPT_DIR="$(dirname "${SUB_DIR}")"

# Source the config file
source "${SCRIPT_DIR}/config.sh"

# Run each script and wait for it to complete before continuing
JOB1=$(sbatch --parsable ${SCRIPT_DIR}/sbatch_scripts/01_create_empty_directories.sh)
sleep 5
while [[ $(squeue -j ${JOB1} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB2=$(sbatch --parsable ${SCRIPT_DIR}/sbatch_scripts/02_create_individual_json.sh)
sleep 5
while [[ $(squeue -j ${JOB2} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB3=$(sbatch --parsable ${SCRIPT_DIR}/sbatch_scripts/03_run_individual_AF3.sh)
sleep 5
while [[ $(squeue -j ${JOB3} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB4=$(sbatch --parsable ${SCRIPT_DIR}/sbatch_scripts/04_extract_MSAs.sh)
sleep 5
while [[ $(squeue -j ${JOB4} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JOB5=$(sbatch --parsable ${SCRIPT_DIR}/sbatch_scripts/05_align_MSAs.sh)
sleep 5
while [[ $(squeue -j ${JOB5} 2>/dev/null | wc -l) -gt 1 ]]; do sleep 30; done

JSON_COUNT=$(ls -1 ${COLLECTION_JSON_DIR}/*.json 2>/dev/null | wc -l)
if [ ${JSON_COUNT} -gt 0 ]; then
    sbatch --array=1-${JSON_COUNT} ${SCRIPT_DIR}/sbatch_scripts/06_run_collection_AF3.sh
fi