#!/bin/bash
#SBATCH --job-name=04_extract_MSAs
#SBATCH --output=/dev/null  # use --output=slurm-%j.out to troubleshoot directory path errors, and --output=/dev/null otherwise
#SBATCH --error=/dev/null  # use --error=slurm-%j.err to troubleshoot directory path errors, and --error=/dev/null otherwise

# Parse through AlphaFold output file and collect MSAs and template information

# ================================================================================
# Note: in the case of errors running this file, adjust lines 3 and 4 for feedback
# ================================================================================

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
export INITIAL_DATA_JSON
export COLLECTION_MSA_DIR
export TEMPLATE_TARGET_DIR
export TEMPLATE_BINDER_DIR
export UNPAIRED_MSA_TARGET
export UNPAIRED_MSA_BINDER
export PAIRED_MSA_TARGET
export PAIRED_MSA_BINDER
export TEMPLATE_TARGET_FILE
export TEMPLATE_BINDER_FILE

# Run Python script from python_scripts subdirectory
${CONDAPYTHON} "${SCRIPT_DIR}/sbatch_scripts/python_scripts/04_extract_MSAs.py"