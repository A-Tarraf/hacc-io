#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <mpi.h>
#include <iostream>
#include "RestartIO_GLEAN.h"

using namespace std;

  // #define INCLUDE
#ifdef INCLUDE
#include "tmio.h"
#endif 

  // #define SCOREP
#ifdef SCOREP
#include <scorep/SCOREP_User.h>
#endif

#ifndef DO_TEST  // if set to 1, a MPI test is done for the async writes and reads
#define DO_TEST 1
#endif

#ifdef MALLEABLE
#include "dmr.h"
#endif

  // fills the arrays
  void compute(int, int, int64_t, float *, float *, float *, float *, float *, float *, float *, int64_t *, uint16_t *,RestartIO_GLEAN * p = NULL);
  // verifies their coontent
  void verify(int, int64_t, float *, float *, float *, float *, float *, float *, float *, int64_t *, uint16_t *, float *, float *, float *, float *, float *, float *, float *, int64_t *, uint16_t *,RestartIO_GLEAN * p = NULL);
  // replicates array for async mode
   void copydata(int64_t, float *, float *, float *, float *, float *, float *, float *, int64_t *, uint16_t *, float *, float *, float *, float *, float *, float *, float *, int64_t *, uint16_t *,RestartIO_GLEAN * p = NULL);

#ifdef MALLEABLE
   void dmr_checkpoint(int, char *, int);
   void dmr_restart(int, char *, int *);
   void func3(int, char *);
#endif

int main(int argc, char *argv[])
{
    char *fname = 0;
    int numtasks, myrank, status;
    int runs = 16;
	int start = 1;
    double time = 0;


    status = MPI_Init(&argc, &argv);
    if (MPI_SUCCESS != status)
    {
        printf(" Error Starting the MPI Program \n");
        MPI_Abort(MPI_COMM_WORLD, status);
    }

    MPI_Comm_size(MPI_COMM_WORLD, &numtasks);
    MPI_Comm_rank(MPI_COMM_WORLD, &myrank);

    if (argc != 3)
    {
        printf(" USAGE <exec> <particles/rank>  < Full file path>  ");
        MPI_Abort(MPI_COMM_WORLD, -1);
    }

	#ifdef MALLEABLE
	if (myrank == 0)
			printf("[MALLEABLE] ---------- ranks: %d --------------\n", numtasks);	
		char processor_name[MPI_MAX_PROCESSOR_NAME];
		int proc_length;
		MPI_Get_processor_name(processor_name, &proc_length);
	    // DMR_AUTO(dmr_init(argc, argv), (void)NULL, func2(myrank, processor_name), (void)NULL);
		DMR_AUTO(dmr_init(argc, argv), (void)NULL, dmr_restart(myrank, processor_name, &start), (void)NULL);
		
		dmr_set_policy_min_nodes(1);
        dmr_set_policy_max_nodes(8);
		if (myrank == 0)
			printf("[MALLEABLE] DMR initialized with min nodes = 1 and max nodes = 8 ---- ranks: %d\n", numtasks);
	#endif


    int64_t num_particles = atoi(argv[1]);
    fname = (char *)malloc(strlen(argv[2]) + 1);
    strncpy(fname, argv[2], strlen(argv[2]));
    fname[strlen(argv[2])] = '\0';

    // Let's Populate Some Dummy Data
    float *xx, *yy, *zz, *vx, *vy, *vz, *phi;
    int64_t *pid;
    uint16_t *mask;

    // Let's Read Restart File Now
    float *xx_r, *yy_r, *zz_r, *vx_r, *vy_r, *vz_r, *phi_r;
    int64_t *pid_r;
    uint16_t *mask_r;
    int64_t my_particles;

    xx   = new float[num_particles];
    yy   = new float[num_particles];
    zz   = new float[num_particles];
    vx   = new float[num_particles];
    vy   = new float[num_particles];
    vz   = new float[num_particles];
    phi  = new float[num_particles];
    pid  = new int64_t[num_particles];
    mask = new uint16_t[num_particles];

    RestartIO_GLEAN *rst = new RestartIO_GLEAN();

    // used for async mode
    float *xx_pre, *yy_pre, *zz_pre, *vx_pre, *vy_pre, *vz_pre, *phi_pre;
    int64_t *pid_pre;
    uint16_t *mask_pre;
    xx_pre   = new float[num_particles];
    yy_pre   = new float[num_particles];
    zz_pre   = new float[num_particles];
    vx_pre   = new float[num_particles];
    vy_pre   = new float[num_particles];
    vz_pre   = new float[num_particles];
    phi_pre  = new float[num_particles];
    pid_pre  = new int64_t[num_particles];
    mask_pre = new uint16_t[num_particles];




    //**********************************
    //* Options                        *
    //**********************************
    //    rst->DisablePreAllocateFile();

    //? set interface for I/O (read & write)
    //? ******************************************
    //rst->Set_POSIX_IO_Interface();
    rst->Set_Sync_MPI_IO_Interface();
    //rst->Set_Async_MPI_IO_Interface();

    //! sync:  [compute_1][write_1][read_1][verify_1][compute_2][write_2][read_2][verify_2][compute_3][write_3][read_3][verify_3]
    //!
    //! asnyc: [compute_1][write_1][compute_2][write_2] [compute_3][write_3]
    //!                           [read_1]    [verify_1][read_2]   [verify_2][read_3][verify_3]

    //? set Header mode:
    rst->Set_Sync_MPI_IO_Header();
    //rst->Set_Async_MPI_IO_Header();

    //? set File mode
    //? ******************************************
    // rst->SetMPIIOSharedFilePointer();
    rst->SetMPIOIndepFilePointer();
    // rst->SetFileDistribution(GLEAN_SINGLE_FILE);
    rst->SetFileDistribution(GLEAN_FILE_PER_RANK);



    //**********************************
    //* Start                          *
    //**********************************
    rst->Initialize(MPI_COMM_WORLD);
    rst->PrintIOCoordInfo();
    if (rst->Get_IO_Interface() == USE_ASYNC_MPIIO)
        runs++;

    for (int loop = start; loop <= runs; loop++)
    { 

        if (myrank == 0)
            {cout << "\nRun  " << loop << "/" << runs << endl;
            printf("Ellapsed time: %.4f -> %.3f\n", MPI_Wtime(), MPI_Wtime() - time);
            time = MPI_Wtime();}

        if (rst->Get_IO_Interface() == USE_ASYNC_MPIIO)
        {
            if (loop != 1)
            {
                // verifiy partical count at
                my_particles = rst->OpenRestart(fname);
                rst->Read(xx_r, yy_r, zz_r, vx_r, vy_r, vz_r, phi_r, pid_r, mask_r);
            }
            if (loop != runs)
                compute(loop, myrank, num_particles, xx, yy, zz, vx, vy, vz, phi, pid, mask, rst);

            if (loop != 1)
                rst->Close();

            if (loop != runs)
            {
                rst->CreateCheckpoint(fname, num_particles);
                rst->Write(xx, yy, zz, vx, vy, vz, phi, pid, mask);
            }

            if (loop != 1)
                verify(myrank, num_particles, xx_pre, yy_pre, zz_pre, vx_pre, vy_pre, vz_pre, phi_pre, pid_pre, mask_pre, xx_r, yy_r, zz_r, vx_r, vy_r, vz_r, phi_r, pid_r, mask_r, rst);

            if (loop != runs)
                copydata(num_particles, xx_pre, yy_pre, zz_pre, vx_pre, vy_pre, vz_pre, phi_pre, pid_pre, mask_pre, xx, yy, zz, vx, vy, vz, phi, pid, mask, rst);

            if (loop != runs)
                rst->Close();
        }
        else
        {
            compute(loop, myrank, num_particles, xx, yy, zz, vx, vy, vz, phi, pid, mask);
            rst->CreateCheckpoint(fname, num_particles);
            rst->Write(xx, yy, zz, vx, vy, vz, phi, pid, mask);
            rst->Close();
            my_particles = rst->OpenRestart(fname);
            if (my_particles != num_particles)
            {
                cout << " Particles Counts Do NOT MATCH " << endl;
                MPI_Abort(MPI_COMM_WORLD, -1);
            }
            rst->Read(xx_r, yy_r, zz_r, vx_r, vy_r, vz_r, phi_r, pid_r, mask_r);
            rst->Close();
            verify(myrank, num_particles, xx, yy, zz, vx, vy, vz, phi, pid, mask, xx_r, yy_r, zz_r, vx_r, vy_r, vz_r, phi_r, pid_r, mask_r);
        }
        
        #ifdef INCLUDE
        	tmio::iotrace_summary();
        #endif

		#ifdef MALLEABLE
			if (loop == runs)
				break;
			// works good
		    // DMRSuggestion suggestion = SLURM4DMR_ROUND_POLICY;
			//
			// others
			// DMRSuggestion suggestion = SLURM4DMR_QUEUE_POLICY
			// DMRSuggestion suggestion = SLURM4DMR_ROUND_POLICY;
			// DMRSuggestion suggestion = SHOULD_EXPAND;
			dmr_set_reconf_step_inhibitor(4);
			// 
			DMRSuggestion suggestion;
			if (loop == 5){
				suggestion = SHOULD_EXPAND;
			}
			else if (loop == 10){
				suggestion = SHOULD_SHRINK;
			}
			else{
				suggestion = SHOULD_STAY;	
				// suggestion = SHOULD_SHRINK;
			}
			dmr_set_policy_min_nodes(1);
			dmr_set_policy_max_nodes(8);
			DMR_AUTO(dmr_check(suggestion), dmr_checkpoint(myrank, processor_name, loop), (void)NULL, func3(myrank, processor_name));
			// DMR_AUTO(dmr_check(suggestion), (void)NULL, (void)NULL, (void)NULL);
		#endif
    }

    rst->Finalize();
    delete rst;
    rst = 0;

    // Delete the Arrays
    delete[] xx;
    delete[] yy;
    delete[] zz;
    delete[] vx;
    delete[] vy;
    delete[] vz;
    delete[] phi;
    delete[] pid;
    delete[] mask;
    delete[] xx_r;
    delete[] yy_r;
    delete[] zz_r;
    delete[] vx_r;
    delete[] vy_r;
    delete[] vz_r;
    delete[] phi_r;
    delete[] pid_r;
    delete[] mask_r;
    delete[] xx_pre;
    delete[] yy_pre;
    delete[] zz_pre;
    delete[] vx_pre;
    delete[] vy_pre;
    delete[] vz_pre;
    delete[] phi_pre;
    delete[] pid_pre;
    delete[] mask_pre;

	#ifdef MALLEABLE
	    DMR_AUTO(dmr_finalize(), (void)NULL, (void)NULL, (void)NULL);
	#endif 
    MPI_Finalize();

    return 0;
}

/*! compute function
* all parameters are filled with the current value of the variable i except @param mask which is filled with the current rank @param myrank
*/
void compute(int loop, int myrank, int64_t num_particles, float *xx, float *yy, float *zz, float *vx, float *vy, float *vz, float *phi, int64_t *pid, uint16_t *mask, RestartIO_GLEAN *p)
{
#ifdef SCOREP
    SCOREP_USER_REGION_DEFINE(handle1)
    SCOREP_USER_REGION_BEGIN(handle1, "compute", SCOREP_USER_REGION_TYPE_COMMON)
#endif
    for (uint64_t i = 0; i < (uint64_t)num_particles; i++)
    {
        xx[i]   = (float)i * loop;
        yy[i]   = (float)i * loop;
        zz[i]   = (float)i * loop;
        vx[i]   = (float)i * loop;
        vy[i]   = (float)i * loop;
        vz[i]   = (float)i * loop;
        phi[i]  = (float)i * loop;
        pid[i]  = (int64_t)i;
        mask[i] = (uint16_t)myrank;

#if DO_TEST == 1
        if (p != NULL && i % num_particles/10 == 0)
            p->test_read();
#endif
    }
#ifdef SCOREP
    SCOREP_USER_REGION_END(handle1)
#endif
}

/*! verify function
* verifies the values of the array variables previously filled via @see #compute(int, int64_t, float*, float*, float*, float*, float*, float*, float*, int64_t*, uint16_t*)
*/
void verify(int myrank, int64_t num_particles, float *xx, float *yy, float *zz, float *vx, float *vy, float *vz, float *phi, int64_t *pid, uint16_t *mask, float *xx_r, float *yy_r, float *zz_r, float *vx_r, float *vy_r, float *vz_r, float *phi_r, int64_t *pid_r, uint16_t *mask_r, RestartIO_GLEAN *p)
{
#ifdef SCOREP
    SCOREP_USER_REGION_DEFINE(handle2)
    SCOREP_USER_REGION_BEGIN(handle2, "verify", SCOREP_USER_REGION_TYPE_COMMON)
#endif

    // Verify The contents
    for (uint64_t i = 0; i < (uint64_t)num_particles; i++)
    {
        if ((xx[i] != xx_r[i]) || (yy[i] != yy_r[i]) || (zz[i] != zz_r[i]) || (vx[i] != vx_r[i]) || (vy[i] != vy_r[i]) || (vz[i] != vz_r[i]) || (phi[i] != phi_r[i]) || (pid[i] != pid_r[i]) || (mask[i] != mask_r[i]))
        {
            cout << " Values Don't Match Index:" << i << endl;
            cout << "XX "    << xx[i]   << " " << xx_r[i]   << " YY "  << yy[i]  << " " << yy_r[i] << endl;
            cout << "ZZ "    << zz[i]   << " " << zz_r[i]   << " VX "  << vx[i]  << " " << vx_r[i] << endl;
            cout << "VY "    << vy[i]   << " " << vy_r[i]   << " VZ "  << vz[i]  << " " << vz_r[i] << endl;
            cout << "PHI "   << phi[i]  << " " << phi_r[i]  << " PID " << pid[i] << " " << pid_r[i] << endl;
            cout << "Mask: " << mask[i] << " " << mask_r[i] << endl;

            MPI_Abort(MPI_COMM_WORLD, -1);
        }
#if DO_TEST == 1
        if (p != NULL && i % num_particles/10 == 0)
            p->test_write();
#endif
    }

    //MPI_Barrier(MPI_COMM_WORLD);

    if (0 == myrank)
        cout << " CONTENTS VERIFIED... Success " << endl;

#ifdef SCOREP
    SCOREP_USER_REGION_END(handle2)
#endif
}

void copydata(int64_t num_particles, float *xx_pre, float *yy_pre, float *zz_pre, float *vx_pre, float *vy_pre, float *vz_pre, float *phi_pre, int64_t *pid_pre, uint16_t *mask_pre, float *xx, float *yy, float *zz, float *vx, float *vy, float *vz, float *phi, int64_t *pid, uint16_t *mask, RestartIO_GLEAN *p)
{
#if DO_TEST == 1
    if (p != NULL)
        p->test_write();
#endif

    memcpy(xx_pre,     xx, num_particles * sizeof(float));
    memcpy(yy_pre,     yy, num_particles * sizeof(float));
    memcpy(zz_pre,     zz, num_particles * sizeof(float));
    memcpy(vx_pre,     vx, num_particles * sizeof(float));
    memcpy(vy_pre,     vy, num_particles * sizeof(float));
    memcpy(vz_pre,     vz, num_particles * sizeof(float));
    memcpy(phi_pre,   phi, num_particles * sizeof(float));
    memcpy(pid_pre,   pid, num_particles * sizeof(int64_t));
    memcpy(mask_pre, mask, num_particles * sizeof(uint16_t));

#if DO_TEST == 1
    if (p != NULL)
        p->test_write();
#endif
}

# ifdef MALLEABLE
void dmr_checkpoint(int rank, char *processor_name, int iteration)
{
    // Only rank 0 writes the checkpoint
    if (rank == 0) {
        FILE *fp = fopen("checkpoint_all.txt", "w");
        if (!fp) {
            perror("fopen");
            return;
        }

        fprintf(fp, "Iteration: %d\n", iteration);
        fclose(fp);

        printf("Rank %d (master) checkpointed iteration %d\n", rank, iteration);
    }


}


void dmr_restart(int rank, char *processor_name, int *iter)
{
    FILE *fp = fopen("checkpoint_all.txt", "r");
    if (!fp) {
        if (rank == 0) perror("fopen");
        *iter = 0;  // default start if no checkpoint
    } else {
        fscanf(fp, "Iteration: %d", iter);
        fclose(fp);
    }

    // All ranks synchronize on the same iteration
    int global_iter = *iter;
    MPI_Bcast(&global_iter, 1, MPI_INT, 0, MPI_COMM_WORLD);
    *iter = global_iter + 1; // start from next iteration

    printf("%s rank %d restarted at iteration %d\n",
           processor_name, rank, *iter);
}


	void func3(int rank, char *processor_name)
	{
		printf("%s rank %d func3\n", processor_name, rank);
	}
#endif
