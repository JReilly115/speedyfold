#!/bin/bash
#SBATCH --job-name=01_create_empty_directories
#SBATCH --output=/dev/null  # use --output=slurm-%j.out to troubleshoot directory path errors, and --output=/dev/null otherwise
#SBATCH --error=/dev/null  # use --error=slurm-%j.err to troubleshoot directory path errors, and --error=/dev/null otherwise

# Set up all directories that will be used by SpeedyFold

# ================================================================================
# Adjust below variable ONE TIME after installing SpeedyFold 
# Note: in the case of errors running this file, adjust lines 3 and 4 for feedback
# ================================================================================

# Get the directory where this script is located
if [ -n "$SLURM_JOB_ID" ]; then
    FILE_PATH=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}' | cut -d' ' -f1)
    [ -z "$FILE_PATH" ] && FILE_PATH=$(realpath "$0")
fi

SUB_DIR="$(dirname "${FILE_PATH}")"
SCRIPT_DIR="$(dirname "${SUB_DIR}")"

# ================================================================================

# Reference the configurations file
source "${SCRIPT_DIR}/config.sh"

# Create directories using paths from configuration file
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}"
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}/pairedMSAs/binder"
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}/pairedMSAs/target"
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}/templates/binder"
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}/templates/target"
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}/unpairedMSAs/binder"
mkdir -p "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}/unpairedMSAs/target"

mkdir -p "${SPEEDYFOLD_DIR}/json_files/individual_json/${CURRENT_RUN_DIR}"
mkdir -p "${SPEEDYFOLD_DIR}/json_files/collection_json/${CURRENT_RUN_DIR}"

mkdir -p "${SPEEDYFOLD_DIR}/outputs/individual_outputs/${CURRENT_RUN_DIR}"
mkdir -p "${SPEEDYFOLD_DIR}/outputs/collection_outputs/${CURRENT_RUN_DIR}"