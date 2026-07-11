#!/usr/bin/env python

# SpeedyFold! Uses ANARCI to align MSAs to binder sequences and generates collection JSON files

import os
import sys
import json
import time
from collections import defaultdict
from tqdm import tqdm

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
CONDA_PATH = os.environ.get('CONDA_DIR')
SEED_NUM = int(os.environ.get('SEED_VALUE'))

# convert seed_number to proper format for json file
model_seeds = list(range(1, SEED_NUM + 1))

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

# ----------------------------------------------------------------------------
# Set PATH to find HMMER in AlphaFold3 environment
# ----------------------------------------------------------------------------

os.environ["PATH"] = f"{CONDA_PATH}/bin" + ":" + os.environ.get("PATH", "")
from anarci import anarci

inputs = dict_from_fasta(FASTA_FILE)

# ----------------------------------------------------------------------------
# Part 1: Print sequence information
# ----------------------------------------------------------------------------

target_seq = list(inputs.values())[0]
target_length = len(target_seq)

binder_items = []
for name, seq in inputs.items():
    if name != 'target':
        binder_items.append((name, seq))

print(f"Target length: {target_length}")
print(f"Total binders: {len(binder_items)}")

# ----------------------------------------------------------------------------
# Part 2: Define ANARCI alignment functions
# ----------------------------------------------------------------------------

def collect_all_sequences(binder_items, paired_MSA_path, unpaired_MSA_path):
    
    all_sequences = []
    
    # Add all binder sequences
    for name, seq in binder_items:
        all_sequences.append(seq)
    
    # Read PAIRED MSA file
    with open(paired_MSA_path, 'r') as f:
        lines = f.readlines()
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            homo_seq = lines[i + 1].strip()
            if homo_seq:
                all_sequences.append(homo_seq)
    
    # Read UNPAIRED MSA file
    with open(unpaired_MSA_path, 'r') as f:
        lines = f.readlines()
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            homo_seq = lines[i + 1].strip()
            if homo_seq:
                all_sequences.append(homo_seq)
    
    return all_sequences


anarci_cache = {}

def get_anarci_numbering_dict(sequence, scheme='imgt', bit_score_threshold=5, fix_missing=True):
    
    # Main time taking process: run ANARCI on all sequences to gather all possible IMGT positions present
    # Clean sequence: remove gaps, keep only amino acids
    
    seq_clean = ''.join([c for c in sequence if c.isalpha()])
    
    # Skip sequences that are too short (not full antibodies)
    if len(seq_clean) < 50:
        return None
    
    # Check cache first - if sequence has already been seen, return stored result
    if seq_clean in anarci_cache:
        return anarci_cache[seq_clean]
    
    # Run ANARCI (the slow part - happens only once per unique sequence)
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
    
    # Fix insertion order (space, then A, then B, then C...)
    N = defaultdict(int)
    order = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    corrected_numbered = []

    for (pos, ins), aa in numbered:
        if aa is not None:
            count = N[pos]
            correct_ins = order[count]
            corrected_numbered.append(((pos, correct_ins), aa))
            N[pos] += 1
    
    # Convert to dictionary for faster lookup
    pos_dict = {}
    for (pos, ins), aa in corrected_numbered:
        if aa is not None:
            pos_dict[(pos, ins)] = aa
            
    # ANARCI may cut amino acids from the beginning and/or the end of the query, but not the MSAs which already have correct IMGT numbering    
    if fix_missing:
        # Check if the sequence needs fixing
        sorted_entries = sorted(pos_dict.items(), key=lambda x: (x[0][0], 0 if x[0][1] == '' or x[0][1] == ' ' else ord(x[0][1])))
        reconstructed = ''.join([aa for (pos, ins), aa in sorted_entries if aa.isalpha()])
        
        # If they don't match, try to fix missing amino acids
        if reconstructed != seq_clean:
            
            # FIX THE BEGINNING
            
            # Find where the reconstructed sequence starts matching the original
            match_start = None
            check_len = min(20, len(reconstructed), len(seq_clean))
            
            for i in range(len(seq_clean) - check_len + 1):
                if seq_clean[i:i+check_len] == reconstructed[:check_len]:
                    match_start = i
                    break
            
            if match_start is not None and match_start > 0:
                # Missing amino acids at the beginning
                missing_start = seq_clean[:match_start]
                
                # Find the first actual amino acid in the dictionary
                first_aa_pos = None
                for (pos, ins), aa in sorted_entries:
                    if aa.isalpha():
                        first_aa_pos = pos
                        break
                
                if first_aa_pos is not None:
                    # Insert missing letters at positions before first amino acid position
                    for i, residue in enumerate(missing_start):
                        insert_pos = first_aa_pos - len(missing_start) + i
                        if (insert_pos, ' ') not in pos_dict or pos_dict[(insert_pos, ' ')] == '-':
                            pos_dict[(insert_pos, ' ')] = residue
                        else:
                            # Find next available insertion letter
                            existing = [ins for (p, ins) in pos_dict.keys() if p == insert_pos]
                            letters = [' '] + [chr(ord('A') + j) for j in range(26)]
                            for letter in letters:
                                if letter not in existing:
                                    pos_dict[(insert_pos, letter)] = residue
                                    break
            
            # FIX THE END
            
            # Re-sort and reconstruct with the new beginning fixes
            sorted_entries = sorted(pos_dict.items(), key=lambda x: (x[0][0], 0 if x[0][1] == '' or x[0][1] == ' ' else ord(x[0][1])))
            reconstructed = ''.join([aa for (pos, ins), aa in sorted_entries if aa.isalpha()])
            
            # Find where the reconstructed sequence ends match the original
            if len(reconstructed) < len(seq_clean):
                # Find the longest suffix match
                match_end = None
                check_len = min(20, len(reconstructed), len(seq_clean))
                
                for i in range(len(seq_clean) - check_len, -1, -1):
                    if seq_clean[i:i+check_len] == reconstructed[-check_len:]:
                        match_end = i + check_len
                        break
                
                if match_end is not None and match_end < len(seq_clean):
                    # Missing letters at the end
                    missing_end = seq_clean[match_end:]
                    
                    # Find the last actual amino acid in the dictionary
                    last_aa_pos = None
                    for (pos, ins), aa in reversed(sorted_entries):
                        if aa.isalpha():
                            last_aa_pos = pos
                            break
                    
                    if last_aa_pos is not None:
                        # Insert missing letters at positions after last amino acid position pos
                        for i, residue in enumerate(missing_end):
                            insert_pos = last_aa_pos + i + 1
                            if (insert_pos, ' ') not in pos_dict or pos_dict[(insert_pos, ' ')] == '-':
                                pos_dict[(insert_pos, ' ')] = residue
                            else:
                                # Find next available insertion letter
                                existing = [ins for (p, ins) in pos_dict.keys() if p == insert_pos]
                                letters = [' '] + [chr(ord('A') + j) for j in range(26)]
                                for letter in letters:
                                    if letter not in existing:
                                        pos_dict[(insert_pos, letter)] = residue
                                        break

    # Store in cache for future use
    anarci_cache[seq_clean] = pos_dict
    return pos_dict


def build_master_framework(all_sequences, scheme='imgt'):
    
    # Build master framework containing IMGT positions from all sequences, which is used to align MSAs to match query length
    
    all_positions = set()
    
    for seq in tqdm(all_sequences, desc="    Building master framework", unit="seq"):
        pos_dict = get_anarci_numbering_dict(seq, scheme)
        if pos_dict:
            for pos in pos_dict.keys():
                all_positions.add(pos)
                pos_num, pos_ins = pos
                if pos_ins != '' and pos_ins is not None:
                    all_positions.add((pos_num, ''))                     
    
    # Sort positions
    def sort_key(item):
        pos, ins = item
        ins_key = '' if ins is None or ins == '' else ins
        return (pos, ins_key)
    
    sorted_positions = sorted(all_positions, key=sort_key)
    
    # Clean: remove bare numbers that have lettered versions
    numbers_with_letters = set()
    for pos, ins in sorted_positions:
        if ins != '' and ins is not None:
            numbers_with_letters.add(pos)
    
    master_positions = []
    for pos, ins in sorted_positions:
        if ins == '' or ins is None:
            # Bare number - only keep if no lettered versions exist
            if pos not in numbers_with_letters:
                master_positions.append((pos, ins))
        else:
            # Lettered version - always keep
            master_positions.append((pos, ins))
    
    return master_positions

def align_to_master_framework(master_positions, pos_dict):
    
    if not pos_dict:
        return None, 0
    
    # Build aligned sequence
    aligned_chars = []
    for position in master_positions:
        if position in pos_dict:
            aligned_chars.append(pos_dict[position])
        else:
            aligned_chars.append('-')
    
    aligned = ''.join(aligned_chars)
    residue_count = sum(1 for c in aligned if c.isalpha())
    
    return aligned, residue_count


def precompute_aligned_sequences(master_positions, binder_items, paired_MSA_path, unpaired_MSA_path, scheme='imgt'):
    
    aligned_queries = {}
    precomputed_paired = []
    precomputed_unpaired = []
    paired_headers = []
    unpaired_headers = []
    paired_query_header = None
    unpaired_query_header = None
    
    # Track seen sequences to avoid duplicates
    seen_paired = set()
    seen_unpaired = set()
    
    # Store dictionaries for fast alignment later
    numbered_queries = {}
    
    for name, seq in binder_items:
        pos_dict = get_anarci_numbering_dict(seq, scheme)
        if pos_dict:
            numbered_queries[seq] = pos_dict
    
    for seq, pos_dict in numbered_queries.items():
        aligned, _ = align_to_master_framework(master_positions, pos_dict)
        if aligned:
            aligned_queries[seq] = aligned
    
    with open(paired_MSA_path, 'r') as f:
        lines = f.readlines()
    
    paired_query_header = lines[0]
    
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            header = lines[i]
            homo_seq = lines[i + 1].strip()
            
            paired_headers.append(header)
            
            raw_seq = ''.join([c for c in homo_seq if c.isalpha()])
            
            if raw_seq and raw_seq not in seen_paired:
                pos_dict = get_anarci_numbering_dict(raw_seq, scheme, fix_missing=False)
                if pos_dict:
                    aligned, _ = align_to_master_framework(master_positions, pos_dict)
                    if aligned:
                        precomputed_paired.append(aligned)
                        seen_paired.add(raw_seq)
    
    with open(unpaired_MSA_path, 'r') as f:
        lines = f.readlines()
    
    unpaired_query_header = lines[0]
    
    for i in range(2, len(lines), 2):
        if i + 1 < len(lines):
            header = lines[i]
            homo_seq = lines[i + 1].strip()
            
            unpaired_headers.append(header)
            
            raw_seq = ''.join([c for c in homo_seq if c.isalpha()])
            
            if raw_seq and raw_seq not in seen_unpaired:
                pos_dict = get_anarci_numbering_dict(raw_seq, scheme, fix_missing=False)
                if pos_dict:
                    aligned, _ = align_to_master_framework(master_positions, pos_dict)
                    if aligned:
                        precomputed_unpaired.append(aligned)
                        seen_unpaired.add(raw_seq)
    
    print(f"Precomputed {len(precomputed_paired)} unique PAIRED homologs")
    print(f"Precomputed {len(precomputed_unpaired)} unique UNPAIRED homologs")
    
    return (aligned_queries, precomputed_paired, precomputed_unpaired, 
            paired_headers, unpaired_headers, paired_query_header, unpaired_query_header)


def process_binder(binder_seq, master_positions, aligned_queries, precomputed_homologs, headers, query_header, scheme='imgt'):
    
    # Process a single binder: apply transformations and return MSA components
    
    raw_query = binder_seq.upper()
    
    # Get aligned query from precomputed map
    query_aligned = aligned_queries[binder_seq]
    
    # Apply Uppercase --> lowercase substitutions in MSA sequence where there are dashes present in query sequence
    processed_homologs = lowercase_substitute(query_aligned, precomputed_homologs)
    
    # Build MSA components
    msa_headers = [query_header]
    msa_sequences = [raw_query]
    
    for i in range(min(len(headers), len(processed_homologs))):
        msa_headers.append(headers[i])
        msa_sequences.append(processed_homologs[i])
    
    return raw_query, processed_homologs, msa_headers, msa_sequences


def lowercase_substitute(aligned_query, aligned_homologs):
    
    # Convert uppercase to lowercase in MSA where query has a dash
    
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


def filter_msa_by_query_length(header_list, sequence_list, query_sequence):
    
    # Safegaurd to remove anomalogus MSAs that don't match the query in length after alignment 
    
    query_length = len(query_sequence)
    
    filtered_headers = [header_list[0]]
    filtered_sequences = [sequence_list[0]]
    removed = 0
    total = len(header_list) - 1  # Exclude query
    
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

def get_safe_name(name):
    
    # Convert a binder name to a safe file name
    
    safe = ''
    for c in name:
        if c == '/' or c == '\\' or c == '.':
            safe += '_'
        else:
            safe += c
    return safe

# ----------------------------------------------------------------------------
# Part 3: Build master framework
# ----------------------------------------------------------------------------

print("="*60)
print("Building master framework from all sequences")
print("="*60)

start_time = time.time()

all_sequences = collect_all_sequences(binder_items, PAIRED_MSA_BINDER, UNPAIRED_MSA_BINDER)

master_positions = build_master_framework(all_sequences)

# ----------------------------------------------------------------------------
# Part 4: Precompute aligned sequences
# ----------------------------------------------------------------------------

(aligned_queries, precomputed_paired, precomputed_unpaired, 
 paired_headers, unpaired_headers, paired_query_header, unpaired_query_header) = precompute_aligned_sequences(
    master_positions, binder_items, PAIRED_MSA_BINDER, UNPAIRED_MSA_BINDER)

# ----------------------------------------------------------------------------
# Part 5: Process each MSA and write json files
# ----------------------------------------------------------------------------

print("="*60)
print("Processing individual binders")
print("="*60)

total_start_time = time.time()

with open(TEMPLATE_TARGET_FILE, 'r') as f:
    target_templates = json.load(f)

for binder_idx, (original_name, binder_seq) in enumerate(tqdm(binder_items, desc="Processing binders", unit="binder"), 1):
    binder_start_time = time.time()
    
    # Get safe file name
    safe_name = get_safe_name(original_name)
    
    binder_length = len(binder_seq)
    raw_query = binder_seq.upper()
        
    # --- Create binder-specific template file with trimmed indices ---
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
    
    # --- Process PAIRED MSA ---
    paired_start_time = time.time()
    
    raw_query, processed_homologs, msa_headers, msa_sequences = process_binder(
        binder_seq, master_positions, aligned_queries, precomputed_paired, 
        paired_headers, paired_query_header
    )
    
    filtered_headers, filtered_sequences, paired_removed, paired_total = filter_msa_by_query_length(
        msa_headers, msa_sequences, raw_query
    )
    
    paired_file = f"{MSA_COLLECTION_PATH}/pairedMSAs/binder/{safe_name}.a3m"
    os.makedirs(os.path.dirname(paired_file), exist_ok=True)
    
    with open(paired_file, 'w') as f:
        for j in range(len(filtered_headers)):
            f.write(filtered_headers[j])
            f.write(filtered_sequences[j] + '\n')
    
    paired_passed = len(filtered_sequences) - 1
    paired_time = time.time() - paired_start_time
    
    # --- Process UNPAIRED MSA ---
    unpaired_start_time = time.time()
    
    raw_query, processed_homologs, msa_headers, msa_sequences = process_binder(
        binder_seq, master_positions, aligned_queries, precomputed_unpaired, 
        unpaired_headers, unpaired_query_header
    )
    
    filtered_headers, filtered_sequences, unpaired_removed, unpaired_total = filter_msa_by_query_length(
        msa_headers, msa_sequences, raw_query
    )
    
    unpaired_file = f"{MSA_COLLECTION_PATH}/unpairedMSAs/binder/{safe_name}.a3m"
    os.makedirs(os.path.dirname(unpaired_file), exist_ok=True)
    
    with open(unpaired_file, 'w') as f:
        for j in range(len(filtered_headers)):
            f.write(filtered_headers[j])
            f.write(filtered_sequences[j] + '\n')
    
    unpaired_passed = len(filtered_sequences) - 1
    unpaired_time = time.time() - unpaired_start_time

    # --- Create JSON files ---
    with open(binder_template_copy, 'r') as f:
        trimmed_binder_templates = json.load(f)

    json_parts = []
    json_parts.append('{\n')
    json_parts.append(f'  "name": "{original_name}",\n')
    json_parts.append(f'  "modelSeeds": {model_seeds},\n')
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
        for j in range(len(template['queryIndices'])):
            if j > 0:
                query_indices_str += ', '
            query_indices_str += str(template['queryIndices'][j])
        query_indices_str += ']'
        json_parts.append(f'    "queryIndices": {query_indices_str},\n')
        
        template_indices_str = '['
        for j in range(len(template['templateIndices'])):
            if j > 0:
                template_indices_str += ', '
            template_indices_str += str(template['templateIndices'][j])
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
    json_parts.append(f'        "sequence": {json.dumps(raw_query)},\n')
    json_parts.append(f'        "unpairedMsaPath": {json.dumps(unpaired_file)},\n')
    json_parts.append(f'        "pairedMsaPath": {json.dumps(paired_file)},\n')
    json_parts.append('        "templates": [\n')
    
    for i in range(len(trimmed_binder_templates)):
        template = trimmed_binder_templates[i]
        json_parts.append('  {\n')
        json_parts.append(f'    "mmcifPath": {json.dumps(template["mmcifPath"])},\n')
        
        query_indices_str = '['
        for j in range(len(template['queryIndices'])):
            if j > 0:
                query_indices_str += ', '
            query_indices_str += str(template['queryIndices'][j])
        query_indices_str += ']'
        json_parts.append(f'    "queryIndices": {query_indices_str},\n')
        
        template_indices_str = '['
        for j in range(len(template['templateIndices'])):
            if j > 0:
                template_indices_str += ', '
            template_indices_str += str(template['templateIndices'][j])
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
    dir_path = ''
    for part in json_file.split('/')[:-1]:
        dir_path += part + '/'
    if dir_path:
        os.makedirs(dir_path, exist_ok=True)
    
    with open(json_file, 'w') as f:
        f.write(''.join(json_parts))
    
    binder_time = time.time() - binder_start_time
    
# ----------------------------------------------------------------------------
# FINAL SUMMARY
# ----------------------------------------------------------------------------

total_time = time.time() - total_start_time
print("="*60)
print("PIPELINE COMPLETE")
print("="*60)
print(f"Paired MSAs: {MSA_COLLECTION_PATH}/pairedMSAs/binder/")
print(f"Unpaired MSAs: {MSA_COLLECTION_PATH}/unpairedMSAs/binder/")
print(f"JSON files: {JSON_COLLECTION_PATH}")
print("="*60)