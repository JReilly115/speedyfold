#!/usr/bin/env python
"""
Create JSON file for the initial binder to generate templates
"""
import sys
import json
import os

sys.path.append('/cluster/tufts/cowenlab/wwhite06/packages/VHH-binding-predictions/utils/')
from utils import dict_from_fasta

fasta_file = os.environ.get('FASTA_FILE')
json_output_dir = os.environ.get('INITIAL_JSON_DIR')
binder_name = os.environ.get('INITIAL_BINDER')

inputs = dict_from_fasta(fasta_file)

target = {
    "protein": {
        "id": "TARGET",
        "sequence": inputs['target'],
    }
}

binder_seq = inputs[binder_name]

nanobody = {
    "protein": {
        "id": "BINDER",
        "sequence": binder_seq
    }
}

collection = {
    "name": binder_name,
    "modelSeeds": [1, 2],
    "sequences": [target, nanobody],
    "dialect": "alphafold3",
    "version": 4
}

os.makedirs(json_output_dir, exist_ok=True)
output_file = f"{json_output_dir}/{binder_name}.json"
with open(output_file, "w") as f:
    json.dump(collection, f, indent=4)