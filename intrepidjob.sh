#!/bin/sh

np=256
np=65536

workdir=/gpfs/home/hines/perf1
env='BG_COREDUMPDISABLED=1'

#cobalt-mpirun -nofree -mode vn -np $np -verbose 2 -cwd $workdir -env "$env" powerpc64/special -mpi -c runs=1 runs.hoc
#cobalt-mpirun -nofree -mode vn -np $np -verbose 2 -cwd $workdir -env "$env" powerpc64/special -mpi -c runs=2 runs.hoc
#cobalt-mpirun -nofree -mode vn -np $np -verbose 2 -cwd $workdir -env "$env" powerpc64/special -mpi -c runs=3 runs.hoc
cobalt-mpirun -nofree -mode vn -np $np -verbose 2 -cwd $workdir -env "$env" powerpc64/special -mpi -c runs=4 runs.hoc
cobalt-mpirun -nofree -mode vn -np $np -verbose 2 -cwd $workdir -env "$env" powerpc64/special -mpi -c runs=5 runs.hoc

cobalt-mpirun -free wait

