#!/bin/bash

# Parse through AlphaFold output file and collect MSAs and template information

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
${CONDAPYTHON} "${SCRIPT_DIR}/bash_scripts/python_scripts/04_extract_MSAs.py"