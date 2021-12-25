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
  ARTIFICIAL_CELL IntervalFireSHA
  RANGE tau, m, invl, burst_start, burst_stop, burst_factor
  : m plays the role of voltage
  BBCOREPOINTER r
  BBCOREPOINTER nrnsha1
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
  nrnsha1
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

/*
 Using SHA1 hash to incrementally accumulate information about events
 arriving at NET_RECEIVE block of this cell. As order of events arriving
 at same time is non-deterministic, anything other than time info is
 not guaranteed to result in same hash
*/

#include <openssl/sha.h>

static size_t sha_size_int;

static void nrnsha1_delete(void** ctx) {
  if (*ctx) { free(*ctx) ; *ctx = NULL; }
}
static void nrnsha1_init(void** ctx) {
  if (!sha_size_int) {
    // needs to be multiple of sizeof(int) for bbcore write and read
    // 96 bytes (24 4 byte int)
    sha_size_int = (sizeof(SHA_CTX) + sizeof(int) - 1)/sizeof(int);
    // printf("sha_size_int=%zd\n", sha_size_int);
  }
  if (!*ctx) { *ctx = malloc(sha_size_int*sizeof(int));}
  assert(*ctx);
  assert(SHA1_Init((SHA_CTX*)(*ctx)));
}
static void nrnsha1_update(void* ctx, const void* data, size_t len) {
  assert(ctx);
  assert(SHA1_Update((SHA_CTX*)ctx, data, len));
}
static double nrnsha1_final(void* ctx) {
  union {
    unsigned char md[SHA_DIGEST_LENGTH];
    size_t val;
  } u;
  if (!ctx) {
    return 0.0;
  }
  assert(SHA1_Final(u.md, (SHA_CTX*)ctx));
  return (double)(u.val & 0xffffffffffff);
}

ENDVERBATIM


INITIAL {

  VERBATIM
    if (_p_r) {  
      /* only this style initializes the stream on finitialize */
      IFNEWSTYLE(nrnran123_setseq((nrnran123_State*)_p_r, 0, 0);)
    }
    
  nrnsha1_init((void**)&_p_nrnsha1);
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

FUNCTION shafinal() {
VERBATIM
  _lshafinal = nrnsha1_final((void*)_p_nrnsha1);
  nrnsha1_delete((void**)&_p_nrnsha1);
ENDVERBATIM
}

NET_RECEIVE (w) {
VERBATIM
  nrnsha1_update((void*)_p_nrnsha1, &(t), sizeof(double));
ENDVERBATIM
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
int nrn_random123_setseq(void* _r, uint32_t seq, char which);
int nrn_random123_getseq(void* _r, uint32_t* seq, char* which);  
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

DESTRUCTOR {
VERBATIM
  if (_p_r) {
#if NRNBBCORE
    { /*mod2c does not translate DESTRUCTOR */
#else
    if (_ran_compat == 2) {
#endif
      nrnran123_State** pv = (nrnran123_State**)(&_p_r);
      nrnran123_deletestream(*pv);
      *pv = (nrnran123_State*)0;
    }
  }
  nrnsha1_delete((void**)&_p_nrnsha1);
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
    char which;
    uint32_t* di = ((uint32_t*)d) + *offset;
#if !NRNBBCORE
    if (_ran_compat == 1) {
      void** pv = (void**)(&_p_r);
      /* error if not using Random123 generator */
      if (!nrn_random_isran123(*pv, di, di+1, di+2)) {
        fprintf(stderr, "InvlFire: Random123 generator is required\n");
        assert(0);
      }
      nrn_random123_getseq(*pv, di+3, &which);
      di[4] = (int)which;
    }else{
#else
    {
#endif
      nrnran123_State** pv = (nrnran123_State**)(&_p_r);
      nrnran123_getids3(*pv, di, di+1, di+2);
      nrnran123_getseq(*pv, di+3, &which);
int z = 0;
#if NRNBBCORE
z = 1;
#endif
      di[4] = (int)which;
#if NRNBBCORE
      /* CORENeuron does not call DESTRUCTOR so... */
      nrnran123_deletestream(*pv);
      *pv = (nrnran123_State*)0;
#endif
    }
    /*printf("Netstim bbcore_write %d %d %d\n", di[0], di[1], di[3]);*/
    {
      if (!_p_nrnsha1) { nrnsha1_init((void**)&_p_nrnsha1); }
      int* ix = (int*)_p_nrnsha1;
      for (size_t i = 0; i < sha_size_int; ++i) {
        di[5 + i] = ix[i];
      }
    }
#if NRNBBCORE
    nrnsha1_delete((void**)&_p_nrnsha1);
#endif
  }
  *offset += 5 + sha_size_int;
}

static void bbcore_read(double* x, int* d, int* xx, int* offset, _threadargsproto_) {
  uint32_t* di = ((uint32_t*)d) + *offset;
#if NRNBBCORE
  nrnran123_State** pv = (nrnran123_State**)(&_p_r);
  *pv = nrnran123_newstream3(di[0], di[1], di[2]);
  nrnran123_setseq(*pv, di[3], (char)di[4]);
#else
  uint32_t id1, id2, id3;
  assert(_p_r);
  if (_ran_compat == 1) { /* Hoc Random.Random123 */
    void** pv = (void**)(&_p_r);
    int b = nrn_random_isran123(*pv, &id1, &id2, &id3);
    assert(b);
    nrn_random123_setseq(*pv, di[3], (char)di[4]);
  }else{
    assert(_ran_compat == 2);
    nrnran123_State** pv = (nrnran123_State**)(&_p_r);
    nrnran123_getids3(*pv, &id1, &id2, &id3);
    nrnran123_setseq(*pv, di[3], (char)di[4]);
  }
  /* Random123 on NEURON side has same ids as on CoreNEURON side */
  assert(di[0] == id1 && di[1] == id2 && di[2] == id3);
#endif
  {
    if (!_p_nrnsha1) { nrnsha1_init((void**)&_p_nrnsha1); }
    int* ix = (int*)_p_nrnsha1;
    for (size_t i = 0; i < sha_size_int; ++i) {
      ix[i] = di[5 + i];
    }
  }
  *offset += 5 + sha_size_int;
}
ENDVERBATIM

