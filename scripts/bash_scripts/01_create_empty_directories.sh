#!/bin/bash

# Set up all directories that will be used by SpeedyFold

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

if [ -d "${SPEEDYFOLD_DIR}/MSAs/${CURRENT_RUN_DIR}" ]; then
    echo "Created directories for current run: ${CURRENT_RUN_DIR}"
else 
    echo "ERROR: Failed to create directories"
fi