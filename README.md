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

Process (within the blocks of prepare_alphafold.ipynb):
1. Prepare an input FASTA file with the target protein on lines 1-2, and all binder proteins on subsequent lines (see example in sequences directory)
2. Activate the imported functions and adjust the changeable variables (run blocks 1-2)
3. Generate the submission json file for a single representative binder (run block 3)
4. Adjust the variables within run_individual_job_alphafold.sh, and use the sbatch command in the cluster command line to run AlphaFold3
5. Parse through the AlphaFold output to generate the master MSA and template files used in all subsequent processing (run blocks 4-6)
6. Develop the framework and perform the alignments with every binder to generate all MSA files and all submission json files (run block 7)
7. Adjust the variables within run_collection_job_alphafold.sh, and use the sbatch command in the cluster command line to run AlphaFold3
8. Enjoy your speedy results!