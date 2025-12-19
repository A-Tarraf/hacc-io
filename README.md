# Modified HACC-IO
This is a modified version of HACC-IO from [CORAL Benchmarks][coral benchmarks]. 
This project is forked from [Github](https://github.com/glennklockwood/hacc-io?tab=readme-ov-file) and extends the original code

It supports asynchronous MPI-IO and executes the code in loops.

The new file `testHACC_Async_IO.cxx` contains several options that can be set:
```c++
⋮
int runs = 8; // specify the number of iterations
⋮
//**********************************
//* Options                        *
//**********************************
//    rst->DisablePreAllocateFile();

//? set interface for I/O (read & write)
//? ******************************************
//rst->Set_POSIX_IO_Interface();
//rst->Set_Sync_MPI_IO_Interface();
rst->Set_Async_MPI_IO_Interface();

//! sync:  [compute_1][write_1][read_1][verify_1][compute_2][write_2][read_2][verify_2][compute_3][write_3][read_3][verify_3]
//!
//! asnyc: [compute_1][write_1][compute_2][write_2] [compute_3][write_3]
//!                           [read_1]    [verify_1][read_2]   [verify_2][read_3][verify_3]

//? set Header mode:
rst->Set_Sync_MPI_IO_Header();
//rst->Set_Async_MPI_IO_Header();

//? set File mode
//? ******************************************
rst->SetMPIIOSharedFilePointer();
//rst->SetMPIOIndepFilePointer();
rst->SetFileDistribution(GLEAN_SINGLE_FILE);
//rst->SetFileDistribution(GLEAN_FILE_PER_RANK);
⋮
```

The file `testHACC_Async_IO_bwlimit.cxx` is similar to `testHACC_Async_IO.cxx`, with the difference that it 
executes a function called `waste_time` to add more variability during the I/O phases. This was used during the experiment with TMIO as described [here](https://github.com/tuda-parallel/TMIO/tree/main/artifacts/cluster24#modified-hacc-io)

## Running


HACC-IO requires MPI and can be built from the provided makefile via

```bash
make run MPICXX=mpicxx
```

To use the tracing library [TMIO](https://github.com/tuda-parallel/TMIO/) with the tool, 
TMIO needs to be cloned and the path needs to be adjusted in the Makefile:

```bash
TMIO_REPO=/d/github/TMIO
```

Afterwards, the code can be executed with different flavors of running the library with the code:
```bash
# execute the code without TMIO
make run
# use LD_PRELOAD with TMIO
make run_with_lib
# include TMIO dynamically with msgpack support
make run_msgpack
# include TMIO dynamically 
make run_with_include
make run_with_include2
# include TMIO statically 
make run_with_include_static
```

Note: Starting with version 0.0.3 of TMIO, version 0.0.2 of HACC-IO is required. 

## Running


The general syntax for `testHACC_IO` is shown bellow. Optionally, the run command can be directly used. 
```bash
mpirun ./testHACC_IO numparticles /path/to/outputfile
# or the async version
mpirun ./testHACC_Async_IO numparticles /path/to/outputfile
#or 
make run N=numparticles /path/to/outputfile
```

`numparticles` is the length of the arrays that each MPI rank should allocate.
HACC IO currently uses this parameter to size the following arrays:

variable | type  | size
---------|-------|---------
      xx | float | 4 bytes
      yy | float | 4 bytes
      zz | float | 4 bytes
      vx | float | 4 bytes
      vy | float | 4 bytes
      vz | float | 4 bytes
     phi | float | 4 bytes
     pid | int64 | 8 bytes
    mask | int16 | 2 bytes

So each rank will write out `numparticles` * 38 bytes worth of data.

[coral benchmarks]: https://asc.llnl.gov/CORAL-benchmarks/#hacc


## Disclaimer of the Original code

"This product includes software produced by UChicago Argonne, LLC under
 Contract No. DE-AC02-06CH11357 with the Department of Energy."

The original version was authored by Venkatram Vishwanath, Argonne National Laboratory.
More details available on the official [CORAL Benchmarks][coral benchmarks]
website.
