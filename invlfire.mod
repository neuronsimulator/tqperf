: dm/dt = (minf - m)/tau
: input event adds w to m
: when m = 1, or event makes m >= 1 cell fires
: minf is calculated so that the natural interval between spikes is invl

: Modified so that the invl can vary randomly by picking from a hoc
: Random instance.
: Modified 5/20/2010 so invl can transiently increase

NEURON {
	ARTIFICIAL_CELL IntervalFire
	RANGE tau, m, invl, burst_start, burst_stop, burst_factor
	: m plays the role of voltage
	POINTER r
	RANGE noutput, ninput : count number of spikes generated and coming in
}

PARAMETER {
	tau = 5 (ms)   <1e-9,1e9>
	invl = 10 (ms) <1e-9,1e9> : varies if r is non-nil
	burst_start = 0 (ms)
	burst_stop = 0 (ms)
	burst_factor = 1
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

INITIAL {
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
:	printf("firetime=%g\n", firetime)
}

PROCEDURE specify_invl() {
VERBATIM {
	extern double nrn_random_pick(void*);
	if (!_p_r) {
		return 0.;
	}
	invl = nrn_random_pick((void*)_p_r);
	if (t >= burst_start && t <= burst_stop) {
		invl *= burst_factor;
	}
}
ENDVERBATIM
	minf = 1/(1 - exp(-invl*tau1)) : so natural spike interval is invl
	minf1 = 1/(minf - 1)
}

PROCEDURE set_rand() {
VERBATIM {
	extern void* nrn_random_arg(int);
	void** ppr;
	ppr = (void**)(&(_p_r));
	*ppr = nrn_random_arg(1);
}
ENDVERBATIM
}

