#!/bin/bash
set -ex
unset CORENEURONLIB
CPU="`arch`"
cp mod/*.mod modx

if test "$CPU" != "" ; then
  rm -r -f `arch`
fi

if test "`uname -s`" = "Darwin" ; then
  # <crypto/sha.h> might not exist so cannot test event times, only total
  # number of input and output events per cell
  $NRNHOME/bin/nrnivmodl -coreneuron mod
else
  $NRNHOME/bin/nrnivmodl -coreneuron -l -lcrypto -loadflags -lcrypto modx
fi

mpiexec -oversubscribe -n 16 $NRNHOME/bin/nrniv -mpi -python test1.py
 
