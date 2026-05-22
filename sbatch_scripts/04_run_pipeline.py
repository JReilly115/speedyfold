#!/usr/bin/env python
"""
ANARCI Pipeline for SpeedyFold - Generates collection JSON files
Silent mode - no console output
"""
import os
import sys
import json
import time
from collections import defaultdict

# ============================================================================
# Get configuration from environment variables (set by config.sh)
# ============================================================================

FASTA_FILE = os.environ.get('FASTA_FILE')
PAIRED_MSA_BINDER = os.environ.get('PAIRED_MSA_BINDER')
UNPAIRED_MSA_BINDER = os.environ.get('UNPAIRED_MSA_BINDER')
MSA_COLLECTION_PATH = os.environ.get('COLLECTION_MSA_DIR')
TEMPLATE_TARGET_FILE = os.environ.get('TEMPLATE_TARGET_FILE')
TEMPLATE_BINDER_FILE = os.environ.get('TEMPLATE_BINDER_FILE')
UNPAIRED_MSA_TARGET_FILE = os.environ.get('UNPAIRED_MSA_TARGET')
PAIRED_MSA_TARGET_FILE = os.environ.get('PAIRED_MSA_TARGET')
JSON_COLLECTION_PATH = os.environ.get('COLLECTION_JSON_DIR')

# Add utils path
sys.path.append('/cluster/tufts/cowenlab/wwhite06/packages/VHH-binding-predictions/utils/')
from utils import dict_from_fasta

# ----------------------------------------------------------------------------
# Set PATH to find HMMER in AlphaFold3 environment
# ----------------------------------------------------------------------------
hmmer_path = "/cluster/tufts/cowenlab/jreill05/Database_Conda_Environment/condaenv/AlphaFold3/bin"
os.environ["PATH"] = hmmer_path + ":" + os.environ.get("PATH", "")
from anarci import anarci

# ----------------------------------------------------------------------------
# Load inputs
# ----------------------------------------------------------------------------
inputs = dict_from_fasta(FASTA_FILE)

# ----------------------------------------------------------------------------
# PART 1: Get sequence lengths and find longest query
# ----------------------------------------------------------------------------
target_seq = list(inputs.values())[0]
binder_items = []
for name, seq in inputs.items():
    if name != 'target':
        binder_items.append((name, seq))

# Find the longest binder sequence to use as reference
longest_binder = max(binder_items, key=lambda x: len(x[1]))
ref_name, ref_seq = longest_binder

# ----------------------------------------------------------------------------
# PART 2: Load target templates
# ----------------------------------------------------------------------------
with open(TEMPLATE_TARGET_FILE, 'r') as f:
    target_templates = json.load(f)

# ----------------------------------------------------------------------------
# Helper functions for paths
# ----------------------------------------------------------------------------
def get_safe_name(name):
    safe = ''
    for c in name:
        if c == '/' or c == '\\' or c == '.':
            safe += '_'
        else:
            safe += c
    return safe

def get_paired_path(safe_name):
    return f"{MSA_COLLECTION_PATH}/pairedMsa/binder/{safe_name}.a3m"

def get_unpaired_path(safe_name):
    return f"{MSA_COLLECTION_PATH}/unpairedMsa/binder/{safe_name}.a3m"

# ----------------------------------------------------------------------------
# PART 3: ANARCI alignment functions
# ----------------------------------------------------------------------------
def collect_all_sequences(binder_items, paired_MSA_collection_path, unpaired_MSA_collection_path):
    all_sequences = []
    
    for name, seq in binder_items:
        all_sequences.append(seq)
    
    with open(paired_MSA_collection_path, 'r') as f:
        lines = f.readlines()
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            homo_seq = lines[i + 1].strip()
            if homo_seq:
                all_sequences.append(homo_seq)
    
    with open(unpaired_MSA_collection_path, 'r') as f:
        lines = f.readlines()
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            homo_seq = lines[i + 1].strip()
            if homo_seq:
                all_sequences.append(homo_seq)
    
    return all_sequences

anarci_cache = {}

def get_anarci_numbering_dict(sequence, scheme='imgt', bit_score_threshold=5, fix_missing=True):
    
    seq_clean = ''.join([c for c in sequence if c.isalpha()])
    
    if len(seq_clean) < 50:
        return None
    
    if seq_clean in anarci_cache:
        return anarci_cache[seq_clean]
    
    result = anarci([('seq', seq_clean)], scheme=scheme, output=False, allowed_species=[], bit_score_threshold=bit_score_threshold)

    if result is None:
        return None

    if isinstance(result, tuple) and len(result) >= 1:
        numbered_seqs = result[0]
    else:
        numbered_seqs = result

    if not numbered_seqs or not numbered_seqs[0]:
        return None

    numbered = numbered_seqs[0][0][0]

    N = defaultdict(int)
    order = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    corrected_numbered = []

    for (pos, ins), aa in numbered:
        if aa is not None:
            count = N[pos]
            correct_ins = order[count]
            corrected_numbered.append(((pos, correct_ins), aa))
            N[pos] += 1
    
    pos_dict = {}
    for (pos, ins), aa in corrected_numbered:
        if aa is not None:
            pos_dict[(pos, ins)] = aa
  
    if fix_missing:
        sorted_entries = sorted(pos_dict.items(), key=lambda x: (x[0][0], 0 if x[0][1] == '' or x[0][1] == ' ' else ord(x[0][1])))
        reconstructed = ''.join([aa for (pos, ins), aa in sorted_entries if aa.isalpha()])
        
        if reconstructed != seq_clean:
            
            match_start = None
            check_len = min(20, len(reconstructed), len(seq_clean))
            
            for i in range(len(seq_clean) - check_len + 1):
                if seq_clean[i:i+check_len] == reconstructed[:check_len]:
                    match_start = i
                    break
            
            if match_start is not None and match_start > 0:
                missing_start = seq_clean[:match_start]
                
                first_aa_pos = None
                for (pos, ins), aa in sorted_entries:
                    if aa.isalpha():
                        first_aa_pos = pos
                        break
                
                if first_aa_pos is not None:
                    for i, residue in enumerate(missing_start):
                        insert_pos = first_aa_pos - len(missing_start) + i
                        if (insert_pos, '') not in pos_dict or pos_dict[(insert_pos, '')] == '-':
                            pos_dict[(insert_pos, '')] = residue
                        else:
                            existing = [ins for (p, ins) in pos_dict.keys() if p == insert_pos]
                            letters = [''] + [chr(ord('A') + j) for j in range(26)]
                            for letter in letters:
                                if letter not in existing:
                                    pos_dict[(insert_pos, letter)] = residue
                                    break
            
            sorted_entries = sorted(pos_dict.items(), key=lambda x: (x[0][0], 0 if x[0][1] == '' or x[0][1] == ' ' else ord(x[0][1])))
            reconstructed = ''.join([aa for (pos, ins), aa in sorted_entries if aa.isalpha()])
            
            if len(reconstructed) < len(seq_clean):
                match_end = None
                check_len = min(20, len(reconstructed), len(seq_clean))
                
                for i in range(len(seq_clean) - check_len, -1, -1):
                    if seq_clean[i:i+check_len] == reconstructed[-check_len:]:
                        match_end = i + check_len
                        break
                
                if match_end is not None and match_end < len(seq_clean):
                    missing_end = seq_clean[match_end:]
                    
                    last_aa_pos = None
                    for (pos, ins), aa in reversed(sorted_entries):
                        if aa.isalpha():
                            last_aa_pos = pos
                            break
                    
                    if last_aa_pos is not None:
                        for i, residue in enumerate(missing_end):
                            insert_pos = last_aa_pos + i + 1
                            if (insert_pos, '') not in pos_dict or pos_dict[(insert_pos, '')] == '-':
                                pos_dict[(insert_pos, '')] = residue
                            else:
                                existing = [ins for (p, ins) in pos_dict.keys() if p == insert_pos]
                                letters = [''] + [chr(ord('A') + j) for j in range(26)]
                                for letter in letters:
                                    if letter not in existing:
                                        pos_dict[(insert_pos, letter)] = residue
                                        break

    anarci_cache[seq_clean] = pos_dict
    return pos_dict

def build_master_framework(all_sequences, scheme='imgt'):
    all_positions = set()
    
    for seq in all_sequences:
        pos_dict = get_anarci_numbering_dict(seq, scheme)
        if pos_dict:
            for pos in pos_dict.keys():
                all_positions.add(pos)
                pos_num, pos_ins = pos
                if pos_ins != '' and pos_ins is not None:
                    all_positions.add((pos_num, ''))                     
    
    def sort_key(item):
        pos, ins = item
        ins_key = '' if ins is None or ins == '' else ins
        return (pos, ins_key)
    
    sorted_positions = sorted(all_positions, key=sort_key)
    
    numbers_with_letters = set()
    for pos, ins in sorted_positions:
        if ins != '' and ins is not None:
            numbers_with_letters.add(pos)
    
    master_positions = []
    for pos, ins in sorted_positions:
        if ins == '' or ins is None:
            if pos not in numbers_with_letters:
                master_positions.append((pos, ins))
        else:
            master_positions.append((pos, ins))
    
    return master_positions

def align_to_master_framework(master_positions, pos_dict):
    if not pos_dict:
        return None, 0
    
    aligned_chars = []
    for position in master_positions:
        if position in pos_dict:
            aligned_chars.append(pos_dict[position])
        else:
            aligned_chars.append('-')
    
    aligned = ''.join(aligned_chars)
    residue_count = sum(1 for c in aligned if c.isalpha())
    
    return aligned, residue_count

def precompute_aligned_sequences(master_positions, binder_items, paired_MSA_collection_path, unpaired_MSA_collection_path, scheme='imgt'):
    aligned_queries = {}
    precomputed_paired = []
    precomputed_unpaired = []
    paired_headers = []
    unpaired_headers = []
    paired_query_header = None
    unpaired_query_header = None
    
    seen_paired = set()
    seen_unpaired = set()
    numbered_queries = {}
    
    for name, seq in binder_items:
        pos_dict = get_anarci_numbering_dict(seq, scheme)
        if pos_dict:
            numbered_queries[seq] = pos_dict
    
    for seq, pos_dict in numbered_queries.items():
        aligned, _ = align_to_master_framework(master_positions, pos_dict)
        if aligned:
            aligned_queries[seq] = aligned
    
    with open(paired_MSA_collection_path, 'r') as f:
        lines = f.readlines()
    
    paired_query_header = lines[0]
    
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            header = lines[i]
            homo_seq = lines[i + 1].strip()
            
            paired_headers.append(header)
            
            raw_seq = ''.join([c for c in homo_seq if c.isalpha()])
            
            if raw_seq and raw_seq not in seen_paired:
                pos_dict = get_anarci_numbering_dict(raw_seq, scheme)
                if pos_dict:
                    aligned, _ = align_to_master_framework(master_positions, pos_dict)
                    if aligned:
                        precomputed_paired.append(aligned)
                        seen_paired.add(raw_seq)
    
    with open(unpaired_MSA_collection_path, 'r') as f:
        lines = f.readlines()
    
    unpaired_query_header = lines[0]
    
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            header = lines[i]
            homo_seq = lines[i + 1].strip()
            
            unpaired_headers.append(header)
            
            raw_seq = ''.join([c for c in homo_seq if c.isalpha()])
            
            if raw_seq and raw_seq not in seen_unpaired:
                pos_dict = get_anarci_numbering_dict(raw_seq, scheme)
                if pos_dict:
                    aligned, _ = align_to_master_framework(master_positions, pos_dict)
                    if aligned:
                        precomputed_unpaired.append(aligned)
                        seen_unpaired.add(raw_seq)
    
    return (aligned_queries, precomputed_paired, precomputed_unpaired, 
            paired_headers, unpaired_headers, paired_query_header, unpaired_query_header)

def lowercase_substitute(aligned_query, aligned_homologs):
    processed = []
    aligned_query = aligned_query.upper()
    
    for homo in aligned_homologs:
        temp_homo = []
        homo = homo.upper()
        
        for i in range(len(aligned_query)):
            q_char = aligned_query[i]
            h_char = homo[i]
            
            if q_char == '-' and h_char == '-':
                pass
            elif q_char == '-' and h_char.isalpha():
                temp_homo.append(h_char.lower())
            else:
                temp_homo.append(h_char)
        
        processed.append(''.join(temp_homo))
    
    return processed

def process_binder(binder_seq, master_positions, aligned_queries, precomputed_homologs, headers, query_header, scheme='imgt'):
    raw_query = binder_seq.upper()
    query_aligned = aligned_queries[binder_seq]
    processed_homologs = lowercase_substitute(query_aligned, precomputed_homologs)
    
    msa_headers = [query_header]
    msa_sequences = [raw_query]
    
    for i in range(min(len(headers), len(processed_homologs))):
        msa_headers.append(headers[i])
        msa_sequences.append(processed_homologs[i])
    
    return raw_query, processed_homologs, msa_headers, msa_sequences

def filter_msa_by_query_length(header_list, sequence_list, query_sequence):
    query_length = len(query_sequence)
    
    filtered_headers = [header_list[0]]
    filtered_sequences = [sequence_list[0]]
    removed = 0
    total = len(header_list) - 1
    
    for i in range(1, len(header_list)):
        header = header_list[i]
        sequence = sequence_list[i]
        
        clean_sequence_chars = []
        for c in sequence:
            if not c.islower() or c == '-':
                clean_sequence_chars.append(c)
        clean_sequence = ''.join(clean_sequence_chars)
        
        if len(clean_sequence) == query_length:
            filtered_headers.append(header)
            filtered_sequences.append(sequence)
        else:
            removed += 1
    
    return filtered_headers, filtered_sequences, removed, total

def remove_gaps(sequence):
    result = []
    for c in sequence:
        if c.isalpha():
            result.append(c)
    return ''.join(result)

def check_indices(templates, seq_length):
    all_valid = True
    for template in templates:
        if 'queryIndices' in template and template['queryIndices']:
            for i in template['queryIndices']:
                if i >= seq_length:
                    all_valid = False
                    break
        if not all_valid:
            break
    return all_valid

# ----------------------------------------------------------------------------
# PART 4: BUILD MASTER FRAMEWORK
# ----------------------------------------------------------------------------
all_sequences = collect_all_sequences(binder_items, PAIRED_MSA_BINDER, UNPAIRED_MSA_BINDER)
master_positions = build_master_framework(all_sequences)

# ----------------------------------------------------------------------------
# PART 5: PRECOMPUTE ALIGNED SEQUENCES
# ----------------------------------------------------------------------------
(aligned_queries, precomputed_paired, precomputed_unpaired, 
 paired_headers, unpaired_headers, paired_query_header, unpaired_query_header) = precompute_aligned_sequences(
    master_positions, binder_items, PAIRED_MSA_BINDER, UNPAIRED_MSA_BINDER)

# ----------------------------------------------------------------------------
# PART 6: Process each binder
# ----------------------------------------------------------------------------
for binder_idx, (original_name, binder_seq) in enumerate(binder_items, 1):
    safe_name = get_safe_name(original_name)
    binder_length = len(binder_seq)
    
    # Create binder-specific template file with trimmed indices
    with open(TEMPLATE_BINDER_FILE, 'r') as f:
        binder_templates = json.load(f)
    
    for template in binder_templates:
        if 'queryIndices' in template:
            trimmed_indices = []
            for i in template['queryIndices']:
                if i < binder_length:
                    trimmed_indices.append(i)
            template['queryIndices'] = trimmed_indices
    
    binder_template_copy = f"{MSA_COLLECTION_PATH}/templates/binder/{safe_name}_templates.json"
    os.makedirs(os.path.dirname(binder_template_copy), exist_ok=True)
    
    with open(binder_template_copy, 'w') as f:
        json.dump(binder_templates, f, indent=2)
    
    # Process PAIRED MSA
    raw_query, processed_homologs, msa_headers, msa_sequences = process_binder(
        binder_seq, master_positions, aligned_queries, precomputed_paired, 
        paired_headers, paired_query_header
    )
    
    filtered_headers, filtered_sequences, paired_removed, paired_total = filter_msa_by_query_length(
        msa_headers, msa_sequences, raw_query
    )
    
    paired_file = get_paired_path(safe_name)
    os.makedirs(os.path.dirname(paired_file), exist_ok=True)
    
    with open(paired_file, 'w') as f:
        for j in range(len(filtered_headers)):
            f.write(filtered_headers[j])
            f.write(filtered_sequences[j] + '\n')
    
    # Process UNPAIRED MSA
    raw_query, processed_homologs, msa_headers, msa_sequences = process_binder(
        binder_seq, master_positions, aligned_queries, precomputed_unpaired, 
        unpaired_headers, unpaired_query_header
    )
    
    filtered_headers, filtered_sequences, unpaired_removed, unpaired_total = filter_msa_by_query_length(
        msa_headers, msa_sequences, raw_query
    )
    
    unpaired_file = get_unpaired_path(safe_name)
    os.makedirs(os.path.dirname(unpaired_file), exist_ok=True)
    
    with open(unpaired_file, 'w') as f:
        for j in range(len(filtered_headers)):
            f.write(filtered_headers[j])
            f.write(filtered_sequences[j] + '\n')
    
    # Create JSON files
    with open(binder_template_copy, 'r') as f:
        trimmed_binder_templates = json.load(f)

    query_no_gaps = remove_gaps(aligned_queries.get(binder_seq, binder_seq))

    json_parts = []
    json_parts.append('{\n')
    json_parts.append(f'  "name": "{original_name}",\n')
    json_parts.append('  "modelSeeds": [1, 2],\n')
    json_parts.append('  "sequences": [\n')
    json_parts.append('    {\n')
    json_parts.append('      "protein": {\n')
    json_parts.append('        "id": "TARGET",\n')
    json_parts.append(f'        "sequence": {json.dumps(target_seq)},\n')
    json_parts.append(f'        "unpairedMsaPath": {json.dumps(UNPAIRED_MSA_TARGET_FILE)},\n')
    json_parts.append(f'        "pairedMsaPath": {json.dumps(PAIRED_MSA_TARGET_FILE)},\n')
    json_parts.append('        "templates": [\n')
    
    for i in range(len(target_templates)):
        template = target_templates[i]
        json_parts.append('  {\n')
        json_parts.append(f'    "mmcifPath": {json.dumps(template["mmcifPath"])},\n')
        
        query_indices_str = '['
        for j, idx in enumerate(template['queryIndices']):
            if j > 0:
                query_indices_str += ', '
            query_indices_str += str(idx)
        query_indices_str += ']'
        json_parts.append(f'    "queryIndices": {query_indices_str},\n')
        
        template_indices_str = '['
        for j, idx in enumerate(template['templateIndices']):
            if j > 0:
                template_indices_str += ', '
            template_indices_str += str(idx)
        template_indices_str += ']'
        json_parts.append(f'    "templateIndices": {template_indices_str}\n')
        
        if i < len(target_templates) - 1:
            json_parts.append('  },\n')
        else:
            json_parts.append('  }\n')
    
    json_parts.append(']\n')
    json_parts.append('      }\n')
    json_parts.append('    },\n')
    json_parts.append('    {\n')
    json_parts.append('      "protein": {\n')
    json_parts.append('        "id": "BINDER",\n')
    json_parts.append(f'        "sequence": {json.dumps(query_no_gaps)},\n')
    json_parts.append(f'        "unpairedMsaPath": {json.dumps(unpaired_file)},\n')
    json_parts.append(f'        "pairedMsaPath": {json.dumps(paired_file)},\n')
    json_parts.append('        "templates": [\n')
    
    for i, template in enumerate(trimmed_binder_templates):
        json_parts.append('  {\n')
        json_parts.append(f'    "mmcifPath": {json.dumps(template["mmcifPath"])},\n')
        
        query_indices_str = '['
        for j, idx in enumerate(template['queryIndices']):
            if j > 0:
                query_indices_str += ', '
            query_indices_str += str(idx)
        query_indices_str += ']'
        json_parts.append(f'    "queryIndices": {query_indices_str},\n')
        
        template_indices_str = '['
        for j, idx in enumerate(template['templateIndices']):
            if j > 0:
                template_indices_str += ', '
            template_indices_str += str(idx)
        template_indices_str += ']'
        json_parts.append(f'    "templateIndices": {template_indices_str}\n')
        
        if i < len(trimmed_binder_templates) - 1:
            json_parts.append('  },\n')
        else:
            json_parts.append('  }\n')
    
    json_parts.append(']\n')
    json_parts.append('      }\n')
    json_parts.append('    }\n')
    json_parts.append('  ],\n')
    json_parts.append('  "dialect": "alphafold3",\n')
    json_parts.append('  "version": 4\n')
    json_parts.append('}')
    
    json_file = os.path.join(JSON_COLLECTION_PATH, f"{safe_name}.json")
    os.makedirs(os.path.dirname(json_file), exist_ok=True)
    
    with open(json_file, 'w') as f:
        f.write(''.join(json_parts))