HACC_CPP_OBJS = RestartIO_GLEAN.o testHACC_IO.o 
HAPP_CPP_HDRS = RestartIO_GLEAN.h

#---------------------------
#Compiler Flags
#---------------------------
#MPICXX = /usr/bin/mpic++.openmpi
#MPIRUN = /usr/bin/mpirun.openmpi
# MPICH
#MPICXX = /usr/bin/mpicxx.mpich
#MPIRUN = /usr/bin/mpirun.mpich
## default (openMPI)
MPICXX = mpicxx
MPIRUN = mpirun

## For bw limit
MODIFED_MPICXX = /d/git/tarraf/bw_limit/mpich-4.0.3/mpich-bin/bin/mpicxx
MODIFED_MPIRUN = /d/git/tarraf/bw_limit/mpich-4.0.3/mpich-bin/bin/mpirun

ifeq (${MPICXX},mpicxx)
else
$(info $(shell tput setaf 1)MPICXX:${MPICXX}$(shell tput sgr0))
$(info $(shell tput setaf 1)MPIRUN:${MPIRUN} $(shell tput sgr0))
endif


# Compiler Flags
CXX_MSGPACK = 
MPI_CFLAGS  = -g -O3 -DGLEAN_PRINT_PERROR -I./ 
MPI_LDFLAGS = -L. -lstdc++ -lpthread
MPI_CFLAGS += -D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -Wall
CXXFLAGS    = $(MPI_CFLAGS)
CXX_INCLUDE =
LDFLAGS     = $(MPI_LDFLAGS)
override CXX_DEBUG  += 

# Code flags
PROCS = 8
N     = 1000000
MPI_RUN_FLAGS =


# TMIO Github location and code
TMIO_REPO = /d/github/TMIO
TMIO_INC  = $(TMIO_REPO)/include
TMIO_BLD  = $(TMIO_REPO)/build
TMIO_DEP  = $(TMIO_REPO)/dep
LIBRARY_TARGET = library


## Build modified HACC in different flavors
all: HACC_IO HACC_ASYNC_IO HACC_OPEN_CLOSE sim_clean

RestartIO_GLEAN.o:RestartIO_GLEAN.cxx
	$(MPICXX) $(MPI_CFLAGS) -c RestartIO_GLEAN.cxx  

testHACC_OPEN_CLOSE.o:testHACC_OPEN_CLOSE.cxx
	$(MPICXX) $(MPI_CFLAGS) -c testHACC_OPEN_CLOSE.cxx 

testHACC_IO.o:testHACC_IO.cxx
	$(MPICXX) $(MPI_CFLAGS) -c testHACC_IO.cxx 

testHACC_Async_IO.o: testHACC_Async_IO.cxx
	$(MPICXX) $(MPI_CFLAGS) -c testHACC_Async_IO.cxx $(CXX_INCLUDE)  $(CXX_DEBUG)

testHACC_Async_IO_bwlimit.o: testHACC_Async_IO.cxx
	$(MPICXX) $(MPI_CFLAGS) -c testHACC_Async_IO_bwlimit.cxx $(CXX_INCLUDE)  $(CXX_DEBUG)

HACC_IO_FILES=RestartIO_GLEAN.o testHACC_IO.o
HACC_IO:$(HACC_IO_FILES)
	$(MPICXX) $(MPI_CFLAGS) $(HACC_IO_FILES) -o $@ 

HACC_IO_ASYNC_FILES=RestartIO_GLEAN.o testHACC_Async_IO.o
HACC_ASYNC_IO:$(HACC_IO_ASYNC_FILES)
	$(MPICXX) $(MPI_CFLAGS) $(HACC_IO_ASYNC_FILES) -o $@  $(CXX_INCLUDE) $(CXX_DEBUG) $(INCLUDE_LIB)

HACC_ASYNC_IO_BWLIMIT=RestartIO_GLEAN.o testHACC_Async_IO_bwlimit.o
HACC_ASYNC_IO_BWLIMIT:$(HACC_ASYNC_IO_BWLIMIT)
	$(MPICXX) $(MPI_CFLAGS) $(HACC_ASYNC_IO_BWLIMIT) -o $@  $(CXX_INCLUDE) $(CXX_DEBUG) $(INCLUDE_LIB)

HACC_OC_FILES=RestartIO_GLEAN.o testHACC_OPEN_CLOSE.o 
HACC_OPEN_CLOSE: $(HACC_OC_FILES) 
	$(MPICXX) $(MPI_CFLAGS) $(HACC_OC_FILES) -o $@


## Run modified HACC-IO
run: sim_clean HACC_ASYNC_IO
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi   

## Run modifed HACC-IO with TMIO
run_with_lib: sim_clean HACC_ASYNC_IO library
	LD_PRELOAD=./libtmio.so $(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi   


run_zmq: LIBRARY_TARGET := zmq_library
run_zmq: override CXX_DEBUG := -DINCLUDE=1 $(CXX_DEBUG) 
run_zmq: CXX_INCLUDE = -I$(TMIO_INC) 
run_zmq: CXX_MSGPACK = -I$(TMIO_DEP)/msgpack/msgpack-c/include
run_zmq: INCLUDE_LIB = -lzmq
run_zmq: clean library $(HACC_IO_ASYNC_FILES)
	$(MPICXX) $(MPI_CFLAGS) $(HACC_IO_ASYNC_FILES) $(wildcard $(TMIO_BLD)/tmp/*.o) -o  HACC_ASYNC_IO $(CXX_INCLUDE) $(CXX_DEBUG) $(INCLUDE_LIB)
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi   


run_msgpack: LIBRARY_TARGET := msgpack_library
run_msgpack: override CXX_DEBUG := -DINCLUDE=1 $(CXX_DEBUG) 
run_msgpack: CXX_INCLUDE = -I$(TMIO_INC) 
run_msgpack: CXX_MSGPACK = -I$(TMIO_DEP)/msgpack/msgpack-c/include
run_msgpack: clean library $(HACC_IO_ASYNC_FILES)
	$(MPICXX) $(MPI_CFLAGS) $(HACC_IO_ASYNC_FILES) $(wildcard $(TMIO_BLD)/tmp/*.o) -o  HACC_ASYNC_IO $(CXX_INCLUDE) $(CXX_DEBUG) $(INCLUDE_LIB)
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi   

run_with_include: CXX_INCLUDE := -I$(TMIO_INC)
run_with_include: override CXX_DEBUG := "-DINCLUDE=1 $(CXX_DEBUG)"
run_with_include: INCLUDE_LIB = -L. -ltmio
run_with_include: clean library HACC_ASYNC_IO
	LD_LIBRARY_PATH=. $(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi   

run_with_include2: CXX_INCLUDE = -I$(TMIO_INC)
run_with_include2: override CXX_DEBUG := -DINCLUDE=1 $(CXX_DEBUG)
run_with_include2: INCLUDE_LIB = -L. -ltmio -Wl,-rpath,$(PWD)
run_with_include2: clean library HACC_ASYNC_IO
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi   

run_with_include_static: CXX_INCLUDE = -I$(TMIO_INC)
run_with_include_static: override CXX_DEBUG := "-DINCLUDE=1 $(CXX_DEBUG)"
run_with_include_static: clean library $(HACC_IO_ASYNC_FILES)
	$(MPICXX) $(MPI_CFLAGS) $(HACC_IO_ASYNC_FILES) $(wildcard $(TMIO_BLD)/tmp/*.o) -o  HACC_ASYNC_IO $(CXX_INCLUDE) $(CXX_DEBUG) $(INCLUDE_LIB)
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi   

## Run HACC-IO with bandwidth limit. This needs modi
run_limit: override CXX_DEBUG := "-DBW_LIMIT $(CXX_DEBUG)"
run_limit: override MPICXX := $(MODIFED_MPICXX)
run_limit: override MPIRUN := $(MODIFED_MPIRUN)
run_limit: info clean HACC_ASYNC_IO_BWLIMIT library
	LD_PRELOAD=./libtmio.so $(MPIRUN)  -np $(PROCS) ./HACC_ASYNC_IO_BWLIMIT $(N) test_run/mpi   

run_nolimit: override CXX_DEBUG := "-DCUSTOM_MPI $(CXX_DEBUG)"
run_nolimit: override MPICXX := $(MODIFED_MPICXX)
run_nolimit: override MPIRUN := $(MODIFED_MPIRUN)
run_nolimit:info clean HACC_ASYNC_IO_BWLIMIT library
	LD_PRELOAD=./libtmio.so $(MPIRUN)  -np $(PROCS) ./HACC_ASYNC_IO_BWLIMIT $(N) test_run/mpi   

info:
	$(info $(shell tput setaf 1)HACC: testHACC_Async_IO_bwlimit.cxx $(shell tput sgr0))
	$(info $(shell tput setaf 1)MPICXX:${MPICXX}$(shell tput sgr0))
	$(info $(shell tput setaf 1)MPIRUN:${MPIRUN} $(shell tput sgr0))
# -------------------------------------------------------------------


clean: sim_clean
	@rm -f *.a *.o a.out core* HACC_IO HACC_ASYNC_IO HACC_OPEN_CLOSE *.jsonl *.json *.msgpack *.bin *.txt

sim_clean: test_dir
	@rm -f test_run/*


test_dir:
	@mkdir -p test_run 2>&1

library: $(shell find ${TMIO_REPO}/src -type f) $(shell find ${TMIO_REPO}/include -type f)
	@cd $(TMIO_REPO)/build && make $(LIBRARY_TARGET) CXX_DEBUG+=$(CXX_DEBUG) MPICXX=$(MPICXX) MPIRUN=$(MPIRUN) CXX_INC=$(CXX_MSGPACK)
	@cp $(TMIO_REPO)/build/libtmio.so . 
	@echo "library created"




#***************************************
#! ScoreP
#***************************************
SCOREP     := scorep --mpp=mpi --thread=pthread --io=posix --user $(MPICXX)
SHELL := /bin/bash
scorep: clean scorep_build library #scorep_run #scorep_result

scorep_build: MPICXX = $(SCOREP)

scorep_build:  HACC_ASYNC_IO

scorep_run:
	#@ source $(GIT_REPO)/roofline/scoreP.sh ||  source ~/git/roofline/scoreP.sh && 
	source ./scoreP.sh &&\
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/async

scorep_result:
	@scorep-score -r ScoreP_Result/profile.cubex  

scorep_clean:
	@ rm -rf ScoreP_Result*

#***************************************
#! Tau
#***************************************
TAU_MAKEFILE := /d/tools/linux_software/tau/tau-2.31/x86_64/lib/Makefile.tau-mpi-pthread
TAU_CXX := export TAU_MAKEFILE=$(TAU_MAKEFILE) ; tau_cxx.sh 
TAU_EXEC := /d/tools/linux_software/Tau_workshop/tau/x86_64/bin/tau_exec
TAU_2OTF2 := /d/tools/linux_software/tau/tau-2.31/x86_64/bin/tau2otf2
TAU_DIR := ./tau_trace
TAU_TREEMERGE := /d/tools/linux_software/Tau_workshop/tau/x86_64/bin/tau_treemerge.pl

tau_dir: tau_clean
	mkdir $(TAU_DIR)

tau_run_preload: HACC_ASYNC_IO tau_dir
	export TAU_PROFILE=0; export TAU_TRACE=1 &&  export TRACEDIR=$(TAU_DIR); export TAU_TRACE_FORMAT=otf2 ;\
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) $(TAU_EXEC)  -io -T pthread  ./HACC_ASYNC_IO $(N) test_run/mpi

tau_run_Makefile: tau_build tau_dir
	export TAU_TRACE=1 && export TRACEDIR=$(TAU_DIR); \
	$(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi

tau_build: MPICXX = $(TAU_CXX)

tau_build:  HACC_ASYNC_IO


tau_profile_view:
	paraprof

tau_trace_view:
	cd $(TAU_DIR) && $(TAU_TREEMERGE) && $(TAU_2OTF2) tau.trc tau.edf matmult
	vampir $(shell pwd)/$(TAU_DIR)/matmult.otf2 

tau_clean:
	@rm -rf $(TAU_DIR) profile.*



#**************************************
# Recorder
#**************************************

recorder: HACC_ASYNC_IO
	LD_PRELOAD=$${RECORDER_DIR}/lib/librecorder.so $(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi 
	$${RECORDER_DIR}/bin/recorder2text recorder-logs
	cp ./recorder-logs/_text/* .

recorder_clean:
	@ rm -f  file* *.out *.txt *.err
	@ rm -rf ScoreP_Result* 
	@ rm -rf recorder-logs 



#**************************************
# strace
#**************************************

strace: strace_clean HACC_ASYNC_IO
	strace -Tttff -o strace_result $(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi 

strace2: strace_clean HACC_ASYNC_IO
	strace -Tttf -o strace_result $(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi 

strace_clean:
	@ rm -f strace_result* 

#**************************************
# gdb 
#**************************************

gdb_run:
	$(MPIRUN)  -np 1 gdb --args ./HACC_ASYNC_IO $(N) test_run/mpi	

gdb_help:
	echo "----------------------------------------------"
	echo "use: "
	echo "    catch syscall"
	echo "    break compute"
	echo "    break verify"
	echo "    set filename-display absolute                "
	echo " then use -step- or -next- or -continue- to step through the code and -where- or -backtrace- to see current position"
	echo " and -info breakpoint- to see placed breakpoints"
	echo "----------------------------------------------"
	echo "                                              "
	echo " ldd HACC_ASYNC_IO          -> to see loaded libraries"
	echo " catch load libc            -> sets breakpoint once linc (POSIX) is loaded"
	echo " set breakpoint pending on  -> to see set breakpoint for future" 
	echo " break aio_init             -> to see number of threads" 

#**************************************
# darshan 
#**************************************

#DARSHAN_DIR = /home/av53jyqe
DARSHAN_DIR = /opt/darshan

darshan: HACC_ASYNC_IO
	# echo "FILE ^./test_run" > ./dxt_config ; \
	# export DXT_TRIGGER_CONF_PATH=./dxt_config ; \
	export DXT_ENABLE_IO_TRACE=1; \
	LD_PRELOAD=$(DARSHAN_DIR)/darshan_runtime/lib/libdarshan.so  $(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS) ./HACC_ASYNC_IO $(N) test_run/mpi	


darshan_parser:
	a=$$(date +'%m/%d/%Y'); b=$${a:0:2}; c=$${a:3:2}; d=$${a:6:4}; \
	ls -t $(DARSHAN_DIR)/darshan-logs/$${d}/$${b##0}/$${c##0}/$(USER)_* | tail -1 | xargs -i darshan-parser {} > darshan.txt
darshan_dxt:
	a=$$(date +'%m/%d/%Y'); b=$${a:0:2}; c=$${a:3:2}; d=$${a:6:4}; \
    ls -t $(DARSHAN_DIR)/darshan-logs/$${d}/$${b##0}/$${c##0}/$(USER)_* | tail -1 | xargs -i darshan-dxt-parser {} > dxt.txt

darshan_clean:
	@a=$$(date +'%m/%d/%Y'); b=$${a:0:2}; c=$${a:3:2}; =$${a:6:4}; \
    rm $(DARSHAN_DIR)/darshan-logs/$${d}/$${b##0}/$${c##0}/* -f 
	@rm dxt.txt darshan.txt dxt_config -f 

	
Memory_Overhead: M1 M2

M1: sim_clean HACC_ASYNC_IO libtmio.so 
	LD_PRELOAD=./libtmio.so  $(MPIRUN)  -np  $(PROCS)  valgrind  --tool=massif  ./HACC_ASYNC_IO 1000000 test_run/mpi
	for i in massif.out.*; do mv $$i lib_on_$$i; done
	
M2: sim_clean HACC_ASYNC_IO
	$(MPIRUN)  -np  $(PROCS)  valgrind  --tool=massif  ./HACC_ASYNC_IO 1000000 test_run/mpi
	for i in massif.out.*; do mv $$i lib_ogg_$$i; done
#valgrind $(MPIRUN)  -np $(PROCS) $(MPI_RUN_FLAGS)   --oversubscribe ./HACC_ASYNC_IO $(N) test_run/mpi 2>&1 | grep "total heap usage" --color
	



clean_ALL: clean sim_clean recorder_clean tau_clean scorep_clean strace_clean darshan_clean
	@rm -rf *.json *.txt *.data
	@echo "--- done ---"
 
