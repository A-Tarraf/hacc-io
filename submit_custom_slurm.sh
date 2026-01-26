#!/bin/bash
#SBATCH --time=00:30:00
#SBATCH --exclusive

# Number of nodes
#SBATCH -N4

echo $DMR_PATH
echo $SLURM_ROOT

export PATH=$SLURM_ROOT/bin:$PATH
export LD_LIBRARY_PATH=$DMR_PATH/build/lib:$LD_LIBRARY_PATH

# Processes per node (PPN) to use at launch. DMR will also read this environment variable and use it for expands.
export DMR_PROCS_PER_NODE=1

# Formatted hostlist to give to PRRTE, e.g. my_host1:10,myhost2:10
NODELIST_WITH_COUNTS=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | awk -v n="$DMR_PROCS_PER_NODE" '{print $1 ":" n}' | paste -sd,)

set -x

$DMR_PATH/scripts/dmr_wrapper mpirun --host $NODELIST_WITH_COUNTS ./HACC_ASYNC_IO 1000000 test_run/mpi 


rm -f test_run/mpi* && echo "Deleted MPI files of HACC-IO" 
cat *_MPI.jsonl > all.jsonl || echo true
