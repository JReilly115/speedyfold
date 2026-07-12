Welcome to SpeedyFold!

Purpose:
1. This software is designed to dramatically speed up the AlphaFold 3 process across large datasets by realigning multiple sequence alignments (MSAs) to new nanobodies
2. Therefore, from now on I will refer to this tool as SpeedyFold :)

Background:
1. AlphaFold generates MSAs by making alignments between the query sequence and many homologous sequences within various databases
2. Gathering homologs from the databases makes up the vast majority of AlphaFold's runtime
3. SpeedyFold works by collecting the imgt numbering of every possible position in the dataset, and developing a framework used to align every MSA to a new query
4. The alignment filters out structural positions that the query does not have in order to match each MSA in length with each new query in A3M format according to AlphaFold's specifications

Limitations:
1. SpeedyFold should only be used to align MSAs for nanobodies that are closely related to the original nanobody used in generating the MSAs. Doing otherwise would likley result in low confidence scores from the AlphaFold prediction
2. SpeedyFold currently only allows for predictions of single-binding interactions between one target nanobody, and any number of binding nanobodies. Multimer nanobodies are not currently supported either
3. Note: Updates are currently being made to the software so that it will function for antibodies, and also with multimer proteins

Time Estimates (100 nanobodies) (873 amino acid target and ~110 amino acid binders) (jobs run sequentially):
1. With SpeedyFold: 27.25hr (~2.5hr for the initial AlphaFold prediction, and ~0.25hr for the next 99 iterations)
2. Without Speedyfold: 250hr (~2.5hr for 100 iterations)

Preliminary Setup:
- Within your user directory, create a parent directory (which I will refer to as "AlphaFold", but you can name freely), and clone "speedyfold" to it
- Request the AlphaFold3 model parameters through completing a form linked in their GitHub repository - https://github.com/google-deepmind/alphafold3
- Begin setting up a conda environment by requesting a GPU if you're using a HPC cluster, and follow steps 0-3 in these GitHub instructions (in step 1 install python 3.11) - https://github.com/Model3DBio/AlphaFold3-Conda-Install
- In step 4.1 of the instructions, clone the "alphafold3" directory to your "AlphaFold" directory 
- Perform steps 4.2 to 4.7 to gather the Alphafold database, incorperate the model parameters, and continue setting up your conda environment
- If step 4.5 and 4.6 doesn't work, refer to the pip section within the "environment.yml" file, and pip install one of the missing packages through a command like `pip install tqdm`. This should give a warning message in return showing all other packages and versions you have yet to pip install. After pip installing all these packages, perform steps 4.5 and 4.6 again
- Add ANARCI to your conda environment by activating your environment and using the command: `conda install -c bioconda anarci`
- In case of persisting environment issues, refer again to the environment.yml file which contains all environment dependencies, and compare your packages to it
- Perform a one time edit of the variable directory paths within the "config.sh" file inside the "scripts" directory
- You may need to use the command `sed -i 's/\r$//' path/to/file_name` with scripts you make edits to, and with fasta files you import. This will convert files to Unix line endings, which prevents errors caused by unexpected line breaks

Directory Path Map:
- (User directory)  
--- (Conda environment)  
--- (Alphafold database)  
--- AlphaFold (parent directory - NAME IS CHANGEABLE)  
----- speedyfold (working directory - DO NOT CHANGE NAME - SpeedyFold GitHub) 
----- alphafold3 (suplementary code - DO NOT CHANGE NAME - AlphaFold3 GitHub)  

SpeedyFold can be used by following ONE of the processes below...

Sbatch Job Process (if running SpeedyFold on a HPC cluster):
1. Prepare an input FASTA file with the target nanobody on lines 1-2, and all binder nanobodies on subsequent lines (see example in sequences directory)
2. Open the "scripts" directory and edit the variable paths indicated within the "config.sh" file 
3. To run the entiriety of SpeedyFold, activate your Conda environment and submit the "master\_script.sh" file contained within the "sbatch\_scripts" directory through the command `sbatch_path/to/master_script.sh`
4. Alternatively, you can activate your Conda environment and submit any of the scripts 01-06 contained in the "sbatch\_scripts" directory to isolate a specific step of SpeedyFold
5. Note: you may need to adjust some the #SBATCH commands within scripts 01-06 depending on your purposes, and your HPC cluster's resources

Bash Process (if running SpeedyFold on a personal computer):
1. Prepare an input FASTA file with the target nanobody on lines 1-2, and all binder nanobodies on subsequent lines (see example in sequences directory)
2. Open the "scripts" directory and edit the variable paths indicated within the "config.sh" file
3. Make any bash script contained within the "bash\_scripts" directory executable through the command `chmod +x path/to/file.sh`
4. To run the entiriety of SpeedyFold, activate your Conda environment and submit the "master\_script.sh" file contained within the "bash\_scripts" directory through the command `bash_path/to/master_script.sh`
5. Alternatively, you can activate your Conda environment and submit any of the scripts 01-06 contained in the "bash\_scripts" directory to isolate a specific step of SpeedyFold

Jupyter Notebook Process (if you wish to experiment and make additions to the code):
1. Prepare an input FASTA file with the target nanobody on lines 1-2, and all binder nanobodies on subsequent lines (see test1.fasta in sequences directory)
2. Open the "scripts" directory and edit the variable paths indicated within the "config.sh" file
3. If you are working on HPC cluster, navigate to "jupyter\_scripts/jupyter\_sbatch_scripts/run\_collection_AF3.sh" and edit line 14 to change the number of sequences to run through AlphaFold
3. Activate your Conda environment and run the command `conda install ipykernel` followed by `python -m ipykernel install --user --name=your_environment`
4. Open "prepare\_AF3.ipynb" in a jupyter notebook, and select your environment to use as a kernal
5. Adjust the changeable variables in block 1 and run it, then run blocks 2 and 3 to generate the empty directories and the submission json file for a single representative binder
6. If working on a HPC cluster, navigate to "jupyter\_sbatch\_scripts" and submit the script "run\_individual\_AF3.sh" through `sbatch path/to/run_individual_AF3.sh`
7. If working on a personal computer, navigate to "jupyter\_bash\_scripts" and submit the script "run\_individual\_AF3.sh" through `sbatch path/to/run_individual_AF3.sh`
8. Returning to the jupyter notebook, run blocks 4, 5, and 6 to parse through the AlphaFold output and generate the MSA and template files used in all subsequent processing
9. Run block 7 to perform the core part of SpeedyFold, aligning all MSAs seperately to every binder in the dataset, and producing all json files required for the collection run of AlphaFold
10. If working on a HPC cluster, navigate to "jupyter\_sbatch\_scripts" and submit the script "run\_collection\_AF3.sh" through `sbatch path/to/run_collection_AF3.sh`
11. If working on a personal computer, navigate to "jupyter\_bash\_scripts" and submit the script "run\_collection\_AF3.sh" through `sbatch path/to/run_collection_AF3.sh`

CUDA Setup (if applicable):
- This section only applies if you run into an error stating "RuntimeError: Unable to initialize backend 'cuda': FAILED_PRECONDITION: No visible GPU devices. (you may need to uninstall the failing plugin package, or set JAX_PLATFORMS=cpu to skip this backend.)"
- To solve this issue you may need to install CUDA on your computer or conda environment (version 12.9.0 is known to work with SpeedyFold)
- Alternatively, if you are using a HPC cluster, you may already have a module available with CUDA. If so, instead of installing CUDA you can import this module within all "run\_individual\_AF3.sh" and "run\_collection\_AF3.sh" scripts

Enjoy your speedy results!
