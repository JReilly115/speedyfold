#!/usr/bin/env python
"""
Extract MSAs and templates from the individual AlphaFold3 run
"""
import sys
import json
import os

data_json = os.environ.get('INITIAL_DATA_JSON')
msa_dir = os.environ.get('COLLECTION_MSA_DIR')
template_target_dir = os.environ.get('TEMPLATE_TARGET_DIR')
template_binder_dir = os.environ.get('TEMPLATE_BINDER_DIR')
unpaired_target = os.environ.get('UNPAIRED_MSA_TARGET')
unpaired_binder = os.environ.get('UNPAIRED_MSA_BINDER')
paired_target = os.environ.get('PAIRED_MSA_TARGET')
paired_binder = os.environ.get('PAIRED_MSA_BINDER')
template_target_file = os.environ.get('TEMPLATE_TARGET_FILE')
template_binder_file = os.environ.get('TEMPLATE_BINDER_FILE')

with open(data_json, 'r') as f:
    data = json.load(f)

# Extract Unpaired MSAs
unpaired_target_data = data["sequences"][0]["protein"]["unpairedMsa"]
unpaired_binder_data = data["sequences"][1]["protein"]["unpairedMsa"]

os.makedirs(os.path.dirname(unpaired_target), exist_ok=True)
os.makedirs(os.path.dirname(unpaired_binder), exist_ok=True)

with open(unpaired_target, 'w') as f:
    f.write(unpaired_target_data)
with open(unpaired_binder, 'w') as f:
    f.write(unpaired_binder_data)

# Extract Paired MSAs
paired_target_data = data["sequences"][0]["protein"]["pairedMsa"]
paired_binder_data = data["sequences"][1]["protein"]["pairedMsa"]

with open(paired_target, 'w') as f:
    f.write(paired_target_data)
with open(paired_binder, 'w') as f:
    f.write(paired_binder_data)

# Extract target templates
template_target_data = data["sequences"][0]["protein"]["templates"]
template_binder_data = data["sequences"][1]["protein"]["templates"]

os.makedirs(template_target_dir, exist_ok=True)
target_templates_list = []

for i, item in enumerate(template_target_data, 1):
    filepath = f"{template_target_dir}/target_template_{i}.cif"
    with open(filepath, 'w') as f:
        f.write(item["mmcif"].replace('\\n', '\n'))
    target_templates_list.append({
        "mmcifPath": filepath,
        "queryIndices": item.get("queryIndices", []),
        "templateIndices": item.get("templateIndices", [])
    })

with open(template_target_file, 'w') as f:
    f.write('[\n')
    for i, template in enumerate(target_templates_list):
        if i > 0:
            f.write(',\n')
        f.write('  {\n')
        f.write(f'    "mmcifPath": "{template["mmcifPath"]}",\n')
        f.write(f'    "queryIndices": {json.dumps(template["queryIndices"])},\n')
        f.write(f'    "templateIndices": {json.dumps(template["templateIndices"])}\n')
        f.write('  }')
    f.write('\n]')

# Extract binder templates
os.makedirs(template_binder_dir, exist_ok=True)
binder_templates_list = []

for i, item in enumerate(template_binder_data, 1):
    filepath = f"{template_binder_dir}/binder_template_{i}.cif"
    with open(filepath, 'w') as f:
        f.write(item["mmcif"].replace('\\n', '\n'))
    binder_templates_list.append({
        "mmcifPath": filepath,
        "queryIndices": item.get("queryIndices", []),
        "templateIndices": item.get("templateIndices", [])
    })

with open(template_binder_file, 'w') as f:
    f.write('[\n')
    for i, template in enumerate(binder_templates_list):
        if i > 0:
            f.write(',\n')
        f.write('  {\n')
        f.write(f'    "mmcifPath": "{template["mmcifPath"]}",\n')
        f.write(f'    "queryIndices": {json.dumps(template["queryIndices"])},\n')
        f.write(f'    "templateIndices": {json.dumps(template["templateIndices"])}\n')
        f.write('  }')
    f.write('\n]')

print(f"Extracted MSAs: {unpaired_target}")
print(f"                {unpaired_binder}")
print(f"                {paired_target}")
print(f"                {paired_binder}")
print(f"Extracted templates: {template_target_file}")
print(f"                     {template_binder_file}")