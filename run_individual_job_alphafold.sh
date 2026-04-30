#!/bin/bash
#SBATCH --job-name=AlphaFold3
#SBATCH --time=3-0:00:00 #requested time (DD-HH:MM:SS)
#SBATCH -p gpu,preempt
#SBATCH --gres=gpu:a100:1
#SBATCH -N 1 #1 nodes
#SBATCH -n 1 #1 tasks total (default 1 CPU core per task) = # of cores
#SBATCH --mem=256GB
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null
#SBATCH --mail-type=ALL #email options
#SBATCH --mail-user=jackson.reilly@tufts.edu

# Absolute directories
APPDIR="/cluster/tufts/cowenlab/jreill05/AlphaFold"
ALPHAFOLD3DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3"

# HMMER binaries from conda environment
HMMER3_BINDIR="/cluster/tufts/cowenlab/jreill05/Database_Conda_Environment/condaenv/AlphaFold3/bin"

# AF3 databases from the cluster
DB_DIR="/cluster/tufts/biocontainers/datasets/alphafold3/20241219/public_databases"

# Model parameters
MODEL_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3/models"

# Define clear output directory
OUTPUT_BASE_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/streamlined_template/outputs/individual_outputs/test1"

# The JSON file in the current working directory
JSON_FILE="/cluster/tufts/cowenlab/jreill05/AlphaFold/streamlined_template/json_files/individual_json/test1/GS-237615.json"

# Derive a name from the JSON file for the output folder
BASE_NAME=$(basename "${JSON_FILE}" .json)

# Create output directory structure
OUTPUT_DIR="${OUTPUT_BASE_DIR}/${BASE_NAME}"
LOG_DIR="${OUTPUT_DIR}/logs"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${LOG_DIR}"

# Log files
LOG_FILE="${LOG_DIR}/af3_run_$(date +%Y%m%d_%H%M%S).log"

# Tmp directory (can be inside output for organization)
export TMPDIR="${OUTPUT_DIR}/tmp"
mkdir -p "${TMPDIR}"

# Run AlphaFold3 using conda environment's python
/cluster/tufts/cowenlab/jreill05/Database_Conda_Environment/condaenv/AlphaFold3/bin/python \
    /cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3/run_alphafold.py \
    --jackhmmer_binary_path="${HMMER3_BINDIR}/jackhmmer" \
    --nhmmer_binary_path="${HMMER3_BINDIR}/nhmmer" \
    --hmmalign_binary_path="${HMMER3_BINDIR}/hmmalign" \
    --hmmsearch_binary_path="${HMMER3_BINDIR}/hmmsearch" \
    --hmmbuild_binary_path="${HMMER3_BINDIR}/hmmbuild" \
    --db_dir="${DB_DIR}" \
    --model_dir="${MODEL_DIR}" \
    --json_path="${JSON_FILE}" \
    --output_dir="${OUTPUT_DIR}" \
    --buckets="256,512,768,1024,1280,1536,2048,2560,3072,3584,4096,4608,5120" \
    2>&1 | tee -a "${LOG_FILE}"