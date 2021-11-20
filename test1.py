# Stress test for spike exchange.
# nrnivmodl -coreneuron mod
# python test1.py
# mpiexec -n 4 nrniv -mpi -python test1.py

from neuron import h, coreneuron
import itertools

pc = h.ParallelContext()

h("done = 0")
h.load_file("init.hoc")


def result():
    cells = h.pnm.cells
    res = [(int(c.pp.noutput), int(c.pp.ninput)) for c in cells]
    noutput, ninput = zip(*res)
    return res


def prun():
    pc.set_maxstep(10)
    h.finitialize(-65)
    pc.psolve(h.tstop)
    return result()


def prun2():
    # exercise back and forth between NEURON and CoreNEURON
    # h.tstop needs to be a multiple of 10
    pc.set_maxstep(0.5)
    h.finitialize(-65)
    while h.t < h.tstop - h.dt / 2.0:
        for coreneuron.enable in [True, False]:
            pc.psolve(h.t + 5.0)

    return result()


def compare(std, res):
    assert std == res


def pr(args):
    if pc.id() == 0:
        print(args, flush=True)


def test_1():
    h.dt = 1.0 / 32.0
    h.tstop = 100
    h.seq = 0
    h.spkfile = 0
    h.ncellpow = 10
    h.ncon = 100
    h.nconrange = 1
    h.mkmodel(h.ncellpow, h.ncon)
    print("netcon count ", h.List("NetCon").count())
    h.use2phase = 0

    pr("NEURON single thread standard")
    std = prun()
    h.cvode.cache_efficient(1)

    pr("NEURON multiple threads")
    pc.nthread(4)
    compare(std, prun())

    pr("CoreNEURON single and multiple threads")
    pc.nthread(1)
    coreneuron.verbose = 0
    coreneuron.enable = True
    compare(std, prun())
    pc.nthread(4)
    compare(std, prun())

    pr("Multiple threads NEURON <-> CoreNEURON back and forth")
    pc.nthread(4)
    compare(std, prun2())

    # Multisend method
    pc.nthread(1)  # multiple threads not allowed
    if pc.nhost() > 1:
        for use2phase, use2subinterval in itertools.product([0, 1], [0, 1]):
            pr(
                "multisend use2phase={}, use2subinterval={}".format(
                    use2phase, use2subinterval
                )
            )
            pc.spike_compress(0, 0, 1 + 4 * use2subinterval + 8 * use2phase)
            coreneuron.enable = True
            pr(coreneuron.nrncore_arg(h.tstop))
            coreneuron.enable = False
            compare(std, prun2())


if __name__ == "__main__":
    test_1()
    h.finish()
