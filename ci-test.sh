#!/bin/bash
set -ex
unset CORENEURONLIB
rm -r -f x86_64
cp mod/*.mod modx
$NRNHOME/bin/nrnivmodl -coreneuron -l -lcrypto -loadflags -lcrypto modx
mpiexec -oversubscribe -n 16 $NRNHOME/bin/nrniv -mpi -python test1.py
 
