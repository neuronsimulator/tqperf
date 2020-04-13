: dm/dt = (minf - m)/tau
: input event adds w to m
: when m = 1, or event makes m >= 1 cell fires
: minf is calculated so that the natural interval between spikes is invl

: Modified so that the invl can vary randomly by picking from a hoc
: Random instance.
: Modified 5/20/2010 so invl can transiently increase

: Modified 6oct2016 to be compatible with CoreNEURON

NEURON {
  THREADSAFE
  ARTIFICIAL_CELL IntervalFire
  RANGE tau, m, invl, burst_start, burst_stop, burst_factor
  : m plays the role of voltage
  BBCOREPOINTER r
  RANGE noutput, ninput : count number of spikes generated and coming in
  GLOBAL invl_low, invl_high
}

PARAMETER {
  tau = 5 (ms)   <1e-9,1e9>
  invl = 10 (ms) <1e-9,1e9> : varies if r is non-nil
  burst_start = 0 (ms)
  burst_stop = 0 (ms)
  burst_factor = 1
  invl_low = 10
  invl_high = 20
}

ASSIGNED {
  m
  minf
  t0(ms)
  r
  tau1
  minf1
  ninput noutput
}

VERBATIM
#if NRNBBCORE /* running in CoreNEURON */

#define IFNEWSTYLE(arg) arg
        
#else /* running in NEURON */
        
/*
   1 means set_rand was called when _ran_compat was previously 0 .
   2 means set_rand123 was called when _ran_compart was previously 0.
*/
static int _ran_compat; /* specifies the noise style for all instances */
#define IFNEWSTYLE(arg) if(_ran_compat == 2) { arg }
        
#endif /* running in NEURON */
ENDVERBATIM


INITIAL {

  VERBATIM
    if (_p_r) {  
      /* only this style initializes the stream on finitialize */
      IFNEWSTYLE(nrnran123_setseq((nrnran123_State*)_p_r, 0, 0);)
    }
  ENDVERBATIM

  ninput = 0
  noutput = 0
  tau1 = 1/tau
  minf = 1/(1 - exp(-invl*tau1)) : so natural spike interval is invl
  minf1 = 1/(minf - 1)
  specify_invl() : will change invl and minf if r is non-nil
  m = 0
  t0 = t
  net_send(firetime(), 1)
}

FUNCTION M() {
  M = minf + (m - minf)*exp(-(t - t0)*tau1)
}

NET_RECEIVE (w) {
  m = M()
  t0 = t
  if (flag == 0) {
    ninput = ninput + 1
    m = m + w
    if (m > 1) {
      m = 0
      noutput = noutput + 1
      net_event(t)
    }
    net_move(t+firetime())
  }else{
    net_event(t)
    noutput = noutput + 1
    m = 0
    specify_invl()
    net_send(firetime(), 1)
  }
}

FUNCTION firetime()(ms) { : m < 1 and minf > 1
  firetime = tau*log((minf-m)*minf1)
:  printf("firetime=%g\n", firetime)
}

VERBATIM        
#include "nrnran123.h"
        
#if !NRNBBCORE
/* backward compatibility */
double nrn_random_pick(void* _r);
void* nrn_random_arg(int argpos);
int nrn_random_isran123(void* _r, uint32_t* id1, uint32_t* id2, uint32_t* id3);
#endif
ENDVERBATIM


PROCEDURE specify_invl() {
VERBATIM {
  if (!_p_r) {
    return 0.;
  }

#if !NRNBBCORE
  if (_ran_compat == 2) {
    invl = nrnran123_dblpick((nrnran123_State*)_p_r);
  }else{
    invl = nrn_random_pick(_p_r);
  }
#else
  invl = nrnran123_dblpick((nrnran123_State*)_p_r); 
#endif

  invl = invl_low + (invl_high-invl_low)*invl;
  if (t >= burst_start && t <= burst_stop) {
    invl *= burst_factor;
  }
}
ENDVERBATIM

  minf = 1/(1 - exp(-invl*tau1)) : so natural spike interval is invl
  minf1 = 1/(minf - 1)
}

PROCEDURE set_rand() {
VERBATIM
#if !NRNBBCORE
 {
  void** pv = (void**)(&_p_r);
  if (_ran_compat == 2) {
    fprintf(stderr, "NetStim.set_rand123 was previously called\n");
    assert(0);
  }       
  _ran_compat = 1;
  if (ifarg(1)) {
    *pv = nrn_random_arg(1);
  }else{
    *pv = (void*)0;
  }
 }
#endif
ENDVERBATIM
}
    
PROCEDURE set_rand123() {
VERBATIM
#if !NRNBBCORE
 {
  nrnran123_State** pv = (nrnran123_State**)(&_p_r);
  if (_ran_compat == 1) {
    fprintf(stderr, "NetStim.set_rand was previously called\n");
    assert(0);
  }
  _ran_compat = 2;
  if (*pv) {
    nrnran123_deletestream(*pv);
    *pv = (nrnran123_State*)0;
  }
  if (ifarg(3)) {
    *pv = nrnran123_newstream3((uint32_t)*getarg(1), (uint32_t)*getarg(2), (uint32_t)*getarg(3));
  }else if (ifarg(2)) {
    *pv = nrnran123_newstream((uint32_t)*getarg(1), (uint32_t)*getarg(2));
  }
 }
#endif
ENDVERBATIM
}

VERBATIM
static void bbcore_write(double* x, int* d, int* xx, int *offset, _threadargsproto_) {
  /* error if using the legacy scop_exprand */
  if (!_p_r) {
    fprintf(stderr, "InvlFire: must use Random123\n");
    assert(0);
  }
  if (d) {
    uint32_t* di = ((uint32_t*)d) + *offset;
#if !NRNBBCORE
    if (_ran_compat == 1) {
      void** pv = (void**)(&_p_r);
      /* error if not using Random123 generator */
      if (!nrn_random_isran123(*pv, di, di+1, di+2)) {
        fprintf(stderr, "InvlFire: Random123 generator is required\n");
        assert(0);
      }
    }else{
#else
    {
#endif
      nrnran123_State** pv = (nrnran123_State**)(&_p_r);
      nrnran123_getids3(*pv, di, di+1, di+2);
    }
    /*printf("Netstim bbcore_write %d %d %d\n", di[0], di[1], di[3]);*/
  }
  *offset += 3;
}

static void bbcore_read(double* x, int* d, int* xx, int* offset, _threadargsproto_) {
  assert(!_p_r);
  uint32_t* di = ((uint32_t*)d) + *offset;
  nrnran123_State** pv = (nrnran123_State**)(&_p_r);
  *pv = nrnran123_newstream3(di[0], di[1], di[2]);
  *offset += 3;
}
ENDVERBATIM

