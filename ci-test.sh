#!/bin/bash
set -ex
unset CORENEURONLIB
CPU="`uname -m`"
cp mod/*.mod modx

if test "$CPU" != "" ; then
  rm -r -f "$CPU"
fi

if test "`uname -s`" = "Darwin" ; then
  # <crypto/sha.h> might not exist so cannot test event times, only total
  # number of input and output events per cell
  $NRNHOME/bin/nrnivmodl -coreneuron mod
else
  $NRNHOME/bin/nrnivmodl -coreneuron -l -lcrypto -loadflags -lcrypto modx
fi

special_exe=`find . -type f -name "special" -print -quit`
mpiexec ${MPIEXEC_OVERSUBSCRIBE---oversubscribe} -n 16 $special_exe -mpi -python test1.py

