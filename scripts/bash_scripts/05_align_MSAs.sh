#!/bin/bash

# Generate the newly aligned MSAs, templates, and all Json files for every binder sequence

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the config file
source "${SCRIPT_DIR}/config.sh"

# configurations file variable exports
export FASTA_FILE
export PAIRED_MSA_BINDER
export UNPAIRED_MSA_BINDER
export COLLECTION_MSA_DIR
export TEMPLATE_TARGET_FILE
export TEMPLATE_BINDER_FILE
export UNPAIRED_MSA_TARGET
export PAIRED_MSA_TARGET
export COLLECTION_JSON_DIR
export CONDA_DIR
export SEED_VALUE

# Run Python script from python_scripts subdirectory
${CONDAPYTHON} "${SCRIPT_DIR}/bash_scripts/python_scripts/05_align_MSAs.py"