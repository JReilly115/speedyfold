# ========================================
# BASE DIRECTORY
# ========================================
export SPEEDYFOLD_DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/speedyfold"

# ========================================
# Edit below variables between runs
# ========================================
# Paths for input sequences, json submission files, and MSAs
export FASTA_FILENAME="test1.fasta"
export INITIAL_JSON_SUBDIR="individual_json/test1"
export COLLECTION_JSON_SUBDIR="collection_json/test1"
export MSA_SUBDIR="MSAs/test1"

# Binder information
export INITIAL_BINDER="GS-237615"
export TOTAL_BINDERS=120

# ========================================
# Do not edit all varaibles below
# ========================================
# AlphaFold paramaters
export ALPHAFOLD3DIR="/cluster/tufts/cowenlab/jreill05/AlphaFold/alphafold3"
export HMMER_BINDIR="/cluster/tufts/cowenlab/jreill05/Database_Conda_Environment/condaenv/AlphaFold3/bin"
export DB_DIR="/cluster/tufts/biocontainers/datasets/alphafold3/20241219/public_databases"
export MODEL_DIR="${ALPHAFOLD3DIR}/models"
export CONDAPYTHON="${HMMER_BINDIR}/python"

# Input paths
export FASTA_FILE="${SPEEDYFOLD_DIR}/sequences/${FASTA_FILENAME}"

# Output paths
export INITIAL_OUTPUT_DIR="${SPEEDYFOLD_DIR}/outputs/initial"
export COLLECTION_OUTPUT_DIR="${SPEEDYFOLD_DIR}/outputs/collection"

# JSON paths
export INITIAL_JSON_DIR="${SPEEDYFOLD_DIR}/json_files/${INITIAL_JSON_SUBDIR}"
export COLLECTION_JSON_DIR="${SPEEDYFOLD_DIR}/json_files/${COLLECTION_JSON_SUBDIR}"
export INITIAL_JSON_FILE="${INITIAL_JSON_DIR}/${INITIAL_BINDER}.json"

# MSA paths (both initial and collection use the same MSA_SUBDIR)
export INITIAL_MSA_DIR="${SPEEDYFOLD_DIR}/${MSA_SUBDIR}"
export COLLECTION_MSA_DIR="${SPEEDYFOLD_DIR}/${MSA_SUBDIR}"

# Initial run data file (created by AlphaFold3)
export INITIAL_DATA_JSON="${INITIAL_OUTPUT_DIR}/${INITIAL_BINDER}/${INITIAL_BINDER}/${INITIAL_BINDER}_data.json"

# Template paths (within collection MSA directory)
export TEMPLATE_TARGET_DIR="${COLLECTION_MSA_DIR}/templates/target"
export TEMPLATE_BINDER_DIR="${COLLECTION_MSA_DIR}/templates/binder"
export UNPAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/unpairedMsa/target/TARGET.a3m"
export UNPAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/unpairedMsa/binder/BINDER.a3m"
export PAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/pairedMsa/target/TARGET.a3m"
export PAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/pairedMsa/binder/BINDER.a3m"
export TEMPLATE_TARGET_FILE="${COLLECTION_MSA_DIR}/templates/target/target_templates.json"
export TEMPLATE_BINDER_FILE="${COLLECTION_MSA_DIR}/templates/binder/binder_templates.json"

# Pipeline script exports
export FASTA_FILE="${SPEEDYFOLD_DIR}/sequences/${FASTA_FILENAME}"
export PAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/pairedMsa/binder/BINDER.a3m"
export UNPAIRED_MSA_BINDER="${COLLECTION_MSA_DIR}/unpairedMsa/binder/BINDER.a3m"
export TEMPLATE_TARGET_FILE="${COLLECTION_MSA_DIR}/templates/target/target_templates.json"
export TEMPLATE_BINDER_FILE="${COLLECTION_MSA_DIR}/templates/binder/binder_templates.json"
export UNPAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/unpairedMsa/target/TARGET.a3m"
export PAIRED_MSA_TARGET="${COLLECTION_MSA_DIR}/pairedMsa/target/TARGET.a3m"
export COLLECTION_MSA_DIR="${SPEEDYFOLD_DIR}/${MSA_SUBDIR}"
export COLLECTION_JSON_DIR="${SPEEDYFOLD_DIR}/json_files/${COLLECTION_JSON_SUBDIR}"

# Scripts directory
export SCRIPTS_DIR="${SPEEDYFOLD_DIR}/sbatch_scripts"

# SLURM settings
export SLURM_CPUS=8
export SLURM_MEM=256GB
export SLURM_TIME="3-0:00:00"
export SLURM_PARTITION="gpu,preempt"
export SLURM_GPU="gpu:a100:1"
export ARRAY_SIZE="1-${TOTAL_BINDERS}"