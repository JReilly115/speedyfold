Welcome to SpeedyFold!

Purpose:
1. This tool is designed to dramatically speed up the AlphaFold 3 process across large datasets by reusing multiple sequence alignments (MSAs)
2. Therefore, from now on I will refer to this tool as SpeedyFold :)

Background:
1. AlphaFold generates MSAs by making alignments between the query sequence and many homologous sequences within various databases
2. Gathering homologs from the databases makes up the vast majority of AlphaFold's runtime
3. SpeedyFold works by gathering the imgt numbering of every possible position in the dataset, and developing a framework used to align every MSA to a new query
4. The alignment filters out structural positions that the query does not have in order to match each MSA in length with each new query in A3M format according to AlphaFold's specifications

Limitations:
1. SpeedyFold should only be used to generate MSAs for proteins that are closely related to the original protein used in generating the MSAs
2. Doing otherwise would likley result in low confidence scores from the AlphaFold prediction

Time Estimates (100 proteins) (jobs run sequentially):
1. With SpeedyFold: 27.25hr (~2.5hr for the initial AlphaFold prediction, and ~0.25hr for the next 99 iterations)
2. Without Speedyfold: 250hr (~2.5hr for 100 iterations)

SpeedyFold can be used by following EITHER of the two below processes...

Jupyter Notebook Process:
1. Prepare an input FASTA file with the target protein on lines 1-2, and all binder proteins on subsequent lines (see example in sequences directory)
2. Locate the materials in the "jupyter_scripts" directory
3. Open "prepare_af3.ipynb" in a jupyter notebook
3. Activate the imported functions and adjust the changeable variables (run blocks 1-2)
4. Generate the submission json file for a single representative binder (run block 3)
5. Adjust the variables within run_individual_job_alphafold.sh, activate your Conda environment, and use the sbatch command in the command line to run AlphaFold3
6. Parse through the AlphaFold output to generate the master MSA and template files used in all subsequent processing (run blocks 4-6)
7. Perform alignments between every binder and a generated framework sequence to generate all MSA files and all submission json files (run block 7)
8. Adjust the variables within run_collection_job_alphafold.sh, activate your Conda environment, and use the sbatch command in the command line to run AlphaFold3

Sbatch Job Process:
1. Prepare an input FASTA file with the target protein on lines 1-2, and all binder proteins on subsequent lines (see example in sequences directory)
2. Locate the materials in the "sbatch_scripts" directory
3. Adjust the variables in the config.sh file
3. Activate your Conda environment and run the scripts in the order of their numbering, using the "sbatch" command in the command line for .sh files, and the "python" command for .py scripts
4. Alternatively, activate your conda environment and just run "master_script.sh" in the command line to perform all of the above scripts in order automatically

Enjoy your speedy results!