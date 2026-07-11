# Create JSON file for the initial binder to generate templates

import sys
import json
import re
import os

# Get configuration from environment variables
fasta_file = os.environ.get('FASTA_FILE')
json_output_dir = os.environ.get('INITIAL_JSON_DIR')
binder_name = os.environ.get('INDIVIDUAL_BINDER')
seed_number = int(os.environ.get('SEED_VALUE'))

# convert seed_number to proper format for json file
model_seeds = list(range(1, seed_number + 1))

def dict_from_fasta(fasta):
    '''
    Read in a fasta file and convert it to a dictionary with names as keys and sequences as values
    Can be used on fasta files with single or multi- line sequences
    
    Parameters
    ----------
    fasta : str
        the name fo the FASTA file to be read
        
    Returns
    -------
    seqs : dict
        a dictionary with names as keys and sequences as values
    '''
    seqs = {}
    with open(fasta,'r') as f:
        lines = f.readlines()
    
    name = lines[0][1:].strip()
    seq = ''
    for line in lines[1:]:
        if line.startswith('>'):
            seqs[name] = seq
            name = line[1:].strip()
            seq = ''
        else:
            seq += line.strip().upper()
    seqs[name] = seq
    
    return seqs

# Load sequences
inputs = dict_from_fasta(fasta_file)

# Define target
target = {
    "protein": {
        "id": "TARGET",
        "sequence": inputs['target'],
    }
}

# Get the specific binder
binder_seq = inputs[binder_name]

# Create nanobody
nanobody = {
    "protein": {
        "id": "BINDER",
        "sequence": binder_seq
    }
}

# Create collection
collection = {
    "name": binder_name,
    "modelSeeds": model_seeds,
    "sequences": [target, nanobody],
    "dialect": "alphafold3",
    "version": 4
}

# Write to file
os.makedirs(json_output_dir, exist_ok=True)
output_file = f"{json_output_dir}/{binder_name}.json"
with open(output_file, "w") as f:
    json_str = json.dumps(collection, indent=4)

    seed_str = f"[{', '.join(str(s) for s in model_seeds)}]"
    json_str = re.sub(
        r'"modelSeeds": \[\s*\d+(?:,\s*\d+)*\s*\]',
        f'"modelSeeds": {seed_str}',
        json_str
    )
    
    f.write(json_str)