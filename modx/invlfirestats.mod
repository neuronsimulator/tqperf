: dm/dt = (minf - m)/tau
: input event adds w to m
: when m = 1, or event makes m >= 1 cell fires
: minf is calculated so that the natural interval between spikes is invl
: Modified so that the invl can vary randomly by picking from a hoc
: Random instance.
: Modified 5/20/2010 so invl can transiently increase
: Modified 6oct2016 to be compatible with CoreNEURON
: Copied 26 January 2023 from IntervalFireSHA to compute the mean of time between events to allow for slightly fuzzy comparisons
NEURON {
  THREADSAFE
  ARTIFICIAL_CELL IntervalFireStats
  RANGE tau, m, invl, burst_start, burst_stop, burst_factor
  : m plays the role of voltage
  BBCOREPOINTER r
  RANGE noutput, ninput : count number of spikes generated and coming in
  RANGE count, mean : compute mean of time since the last spike
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
  count
  mean
}

INITIAL {
  VERBATIM
  if (_p_r) {
    nrnran123_setseq(static_cast<nrnran123_State*>(_p_r), 0, 0);
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
  count = 0
  mean = 0
  net_send(firetime(), 1)
}

FUNCTION M() {
  M = minf + (m - minf)*exp(-(t - t0)*tau1)
}

FUNCTION meangap() {
    meangap = mean
}

NET_RECEIVE (w) {
  count = count + 1
  mean = mean + (((t - t0) - mean) / count)
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
}

PROCEDURE specify_invl() {
VERBATIM {
  if (!_p_r) {
    return 0.;
  }
  invl = invl_low + (invl_high - invl_low) * nrnran123_dblpick(static_cast<nrnran123_State*>(_p_r));
  if (t >= burst_start && t <= burst_stop) {
    invl *= burst_factor;
  }
}
ENDVERBATIM
  minf = 1/(1 - exp(-invl*tau1)) : so natural spike interval is invl
  minf1 = 1/(minf - 1)
}

PROCEDURE set_rand123() {
VERBATIM
#if !NRNBBCORE
  {
    auto* stream = static_cast<nrnran123_State*>(_p_r);
    if (stream) {
      nrnran123_deletestream(stream);
    }
    if (ifarg(3)) {
      stream = nrnran123_newstream3((uint32_t)*getarg(1), (uint32_t)*getarg(2), (uint32_t)*getarg(3));
    } else if (ifarg(2)) {
      stream = nrnran123_newstream((uint32_t)*getarg(1), (uint32_t)*getarg(2));
    }
    _p_r = stream;
  }
#endif
ENDVERBATIM
}

DESTRUCTOR {
VERBATIM
  if (_p_r) {
    nrnran123_deletestream(static_cast<nrnran123_State*>(_p_r));
    _p_r = nullptr;
  }
ENDVERBATIM
}

VERBATIM
static void bbcore_write(double* x, int* d, int* xx, int *offset, _threadargsproto_) {
  assert(_p_r);
  if (d) {
    char which;
    uint32_t* di = ((uint32_t*)d) + *offset;
    auto* stream = static_cast<nrnran123_State*>(_p_r);
    nrnran123_getids3(stream, di, di+1, di+2);
    nrnran123_getseq(stream, di+3, &which);
    di[4] = (int)which;
#if NRNBBCORE
    // CoreNEURON does not call DESTRUCTOR so...
    nrnran123_deletestream(stream);
    _p_r = nullptr;
#endif
  }
  *offset += 5;
}

static void bbcore_read(double* x, int* d, int* xx, int* offset, _threadargsproto_) {
  uint32_t* di = ((uint32_t*)d) + *offset;
#if NRNBBCORE
  auto* const stream = nrnran123_newstream3(di[0], di[1], di[2]);
  nrnran123_setseq(stream, di[3], (char)di[4]);
  _p_r = stream;
#else
  uint32_t id1, id2, id3;
  assert(_p_r);
  auto* const stream = static_cast<nrnran123_State*>(_p_r);
  nrnran123_getids3(stream, &id1, &id2, &id3);
  nrnran123_setseq(stream, di[3], (char)di[4]);
  // Random123 on NEURON side has same ids as on CoreNEURON
  assert(di[0] == id1 && di[1] == id2 && di[2] == id3);
#endif
  *offset += 5;
}
ENDVERBATIM

