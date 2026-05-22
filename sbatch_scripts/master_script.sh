#!/bin/bash
#SBATCH --job-name=AF3_Master
#SBATCH --output=logs/master_%j.out
#SBATCH --error=logs/master_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=4G
#SBATCH --ntasks=1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jackson.reilly@tufts.edu

source $(dirname $0)/config.sh

mkdir -p logs

${CONDAPYTHON} ${SCRIPTS_DIR}/01_create_initial_json.py
if [ $? -ne 0 ]; then
    exit 1
fi

JOB1=$(sbatch --parsable ${SCRIPTS_DIR}/02_run_individual_af3.sh)

while [[ $(squeue -j $JOB1 2>/dev/null | wc -l) -gt 1 ]]; do
    sleep 60
done

${CONDAPYTHON} ${SCRIPTS_DIR}/03_extract_templates.py
if [ $? -ne 0 ]; then
    exit 1
fi

${CONDAPYTHON} ${SCRIPTS_DIR}/04_run_pipeline.py
if [ $? -ne 0 ]; then
    exit 1
fi

JSON_COUNT=$(ls -1 ${COLLECTION_JSON_DIR}/*.json 2>/dev/null | wc -l)
if [ $JSON_COUNT -eq 0 ]; then
    exit 1
fi

sbatch --array=1-${JSON_COUNT} ${SCRIPTS_DIR}/05_run_collection_af3.sh