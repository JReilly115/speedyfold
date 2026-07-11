#!/bin/bash
export SLURM_CPUS=8
export SLURM_MEM=256GB
export SLURM_TIME="3-0:00:00"
export SLURM_PARTITION="gpu,preempt"

# ================================================================================
# Edit below 3 variables BETWEEN RUNS
# Select the gpu model directly in files run_individual_AF3.sh and run_collection_AF3.sh for sbatch jobs depending on memory requirements)
# Note: if running the master script, make sure you are not using the sbatch array command on line 13 of run_collection_AF3.sh
# ================================================================================

# Current SpeedyFold run name
export CURRENT_RUN_DIR="test1"

# Input sequences file name
export FASTA_FILENAME="test1.fasta"

# Number of seeds to use per AlphaFold prediction (higher values result in higher confidence scores, but longer runtime. 5 is a good default)
export SEED_VALUE=5

# ================================================================================
# Adjust below 5 variables ONE TIME (when first installing SpeedyFold)
# ================================================================================

# User directory
export USER_DIR="/cluster/tufts/cowenlab/jreill05"

# Working directory
export SPEEDYFOLD_DIR="${USER_DIR}/AlphaFold/speedyfold"

# Official AF3 code directory
export ALPHAFOLD3DIR="${USER_DIR}/AlphaFold/alphafold3"

# Conda environment location
export CONDA_DIR="${USER_DIR}/Database_Conda_Environment/condaenv/Alphafold3_test_GPU"

# AF3 database directory
export DB_DIR="/cluster/tufts/biocontainers/datasets/alphafold3/20241219/public_databases"

# CUDA module name
export CUDA="cuda/12.9.0"

# ================================================================================

# AlphaFold parameters
export MODEL_DIR="${ALPHAFOLD3DIR}/models"

# Python path
export CONDAPYTHON="${CONDA_DIR}/bin/python"

# Input sequences paths
export FASTA_FILE="${SPEEDYFOLD_DIR}/sequences/${FASTA_FILENAME}"

# Calculate the number of binder proteins in the fasta file by finding number of lines, dividing by 2 (there are 2 lines per sequence), and subtracting by 1 (accounting for target protein)
if [ -f "$FASTA_FILE" ]; then
    TOTAL_LINES=$(wc -l < "$FASTA_FILE")
    TOTAL_BINDERS=$(( (TOTAL_LINES / 2) - 1 ))
fi

# Number of jobs submitted to AlphaFold during the collection run
export ARRAY_SIZE="1-${TOTAL_BINDERS}"

# Gather name of first binder sequence in the FASTA file (on line 3) to be used in the individual run of AlphaFold
if [ -f "$FASTA_FILE" ]; then
    INDIVIDUAL_BINDER=$(awk '/^>/ {count++; if (count==2) {print substr($0, 2); exit}}' "$FASTA_FILE")
    if [ -z "$INDIVIDUAL_BINDER" ]; then
        INDIVIDUAL_BINDER=$(sed -n '3p' "$FASTA_FILE" | sed 's/^>//')
    fi
    export INDIVIDUAL_BINDER
fi

# Output AlphaFold paths
export INDIVIDUAL_OUTPUT_DIR="${SPEEDYFOLD_DIR}/outputs/individual_outputs"
export COLLECTION_OUTPUT_DIR="${SPEEDYFOLD_DIR}/outputs/collection_outputs"

# Output subdirectory names
export INDIVIDUAL_JSON_SUBDIR="individual_json/${CURRENT_RUN_DIR}"
export COLLECTION_JSON_SUBDIR="collection_json/${CURRENT_RUN_DIR}"
export MSA_SUBDIR="MSAs/${CURRENT_RUN_DIR}"

# JSON paths
export INITIAL_JSON_DIR="${SPEEDYFOLD_DIR}/json_files/${INDIVIDUAL_JSON_SUBDIR}"
export COLLECTION_JSON_DIR="${SPEEDYFOLD_DIR}/json_files/${COLLECTION_JSON_SUBDIR}"
export INITIAL_JSON_FILE="${INITIAL_JSON_DIR}/${INDIVIDUAL_BINDER}.json"

# MSA paths
export INITIAL_MSA_DIR="${SPEEDYFOLD_DIR}/${MSA_SUBDIR}"
export COLLECTION_MSA_DIR="${SPEEDYFOLD_DIR}/${MSA_SUBDIR}"

# Initial run data file (created by AlphaFold3)
export INITIAL_DATA_JSON="${INDIVIDUAL_OUTPUT_DIR}/${CURRENT_RUN_DIR}/${INDIVIDUAL_BINDER}/${INDIVIDUAL_BINDER}_data.json"

# Template paths (within collection MSA directory)
export TEMPLATE_TARGET_DIR="${COLLECTION_MSA_DIR}/templates/target"
export TEMPLATE_BINDER_DIR="${COLLECTION_MSA_DIR}/templates/binder"
export TEMPLATE_TARGET_FILE="${COLLECTION_MSA_DIR}/templates/target/target_templates.json"
export TEMPLATE_BINDER_FILE="${COLLECTION_MSA_DIR}/templates/binder/binder_templates.json"

# MSA file paths (with placeholders)
export UNPAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/unpairedMSAs/target/TARGET.a3m"
export UNPAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/unpairedMSAs/binder/BINDER.a3m"
export PAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/pairedMSAs/target/TARGET.a3m"
export PAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/pairedMSAs/binder/BINDER.a3m"

# Pipeline script exports (for ANARCI pipeline)
export PAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/pairedMSAs/binder/BINDER.a3m"
export UNPAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/unpairedMSAs/binder/BINDER.a3m"
export TEMPLATE_TARGET_FILE="${COLLECTION_MSA_DIR}/templates/target/target_templates.json"
export TEMPLATE_BINDER_FILE="${COLLECTION_MSA_DIR}/templates/binder/binder_templates.json"
export UNPAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/unpairedMSAs/target/TARGET.a3m"
export PAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/pairedMSAs/target/TARGET.a3m"
export COLLECTION_MSA_DIR="${SPEEDYFOLD_DIR}/${MSA_SUBDIR}"
export COLLECTION_JSON_DIR="${SPEEDYFOLD_DIR}/json_files/${COLLECTION_JSON_SUBDIR}"

# Scripts directory
export SCRIPTS_DIR="${SPEEDYFOLD_DIR}/sbatch_scripts"