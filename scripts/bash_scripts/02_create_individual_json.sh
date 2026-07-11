#!/bin/bash

# Create JSON file for individual run of AlphaFold

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the config file
source "${SCRIPT_DIR}/config.sh"

# configurations file variable exports
export FASTA_FILE
export INITIAL_JSON_DIR
export INDIVIDUAL_BINDER
export SEED_VALUE

# Run Python script from python_scripts subdirectory
${CONDAPYTHON} "${SCRIPT_DIR}/bash_scripts/python_scripts/02_create_individual_json.py"