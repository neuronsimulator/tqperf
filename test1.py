# Stress test for spike exchange.
# nrnivmodl -coreneuron mod
# python test1.py
# mpiexec -n 4 nrniv -mpi -python test1.py

from neuron import h, coreneuron
import itertools

pc = h.ParallelContext()

h("done = 0")
h.load_file("init.hoc")
h.useSHA = 1


def result():
    cells = h.pnm.cells
    if h.useSHA == 0.0:
        res = [(int(c.pp.noutput), int(c.pp.ninput)) for c in cells]
        noutput, ninput = zip(*res)
        # print("{} noutput={} ninput={}".format(pc.id(), sum(noutput), sum(ninput)), flush=True)
    else:
        res = [
            (int(c.pp.noutput), int(c.pp.ninput), int(c.pp.shafinal())) for c in cells
        ]
        noutput, ninput, sha = zip(*res)
        # print(pc.id(), sha[0:4], flush=True)
    return res


def prun():
    pc.set_maxstep(10)
    h.finitialize(-65)
    pc.psolve(h.tstop)
    return result()


def prun2():
    # exercise back and forth between NEURON and CoreNEURON
    # h.tstop needs to be a multiple of 10
    pc.set_maxstep(10)
    h.finitialize(-65)
    while h.t < h.tstop - h.dt / 2.0:
        for coreneuron.enable in [True, False]:
            tt = h.t + 5.0
            if tt > h.tstop:
                tt = h.tstop
            pc.psolve(tt)

    return result()


def compare(std, res):
    if std != res:
        for i, s in enumerate(std):
            if s != res[i]:
                print(pc.id(), h.pnm.cells.o(i).lseed, i, s, res[i], flush=True)
                break
    assert std == res


def pr(args):
    if pc.id() == 0:
        print(args, flush=True)


def send_recv_info():
    # Fairly meaningless for the ci test. And times only calculated on BGP.
    # But line coverage for bgpdma.cpp > 90%
    pr("send_time_type [min, avg, max]")
    for name, type in {"recv time":2, "send time":3, "xtra cons checks":4,"greatest length multisend":12}.items():
        r = pc.send_time(type)
        minavgmax=[pc.allreduce(r, m) for m in [3,1,2]]
        minavgmax[1] /= pc.nhost()
        pr("{} {}".format(name, minavgmax))
	
def test_1():
    h.dt = 1.0 / 32.0
    h.tstop = 50
    h.seq = 0
    h.spkfile = 0
    h.ncellpow = 8
    h.ncon = 50
    h.nconrange = 1
    h.mkmodel(h.ncellpow, h.ncon)
    print("netcon count ", h.List("NetCon").count())
    h.use2phase = 0

    pr("NEURON single thread standard")
    std = prun()
    h.cvode.cache_efficient(1)

    pr("NEURON multiple threads")
    pc.nthread(2)
    compare(std, prun())

    pr("CoreNEURON single and multiple threads")
    pc.nthread(1)
    coreneuron.verbose = 0
    coreneuron.enable = True
    compare(std, prun())
    pc.nthread(2)
    compare(std, prun())

    pr("Multiple threads NEURON <-> CoreNEURON back and forth")
    pc.nthread(2)
    compare(std, prun2())

    # Multisend method
    pc.nthread(1)  # multiple threads not allowed
    if pc.nhost() > 1:
        h.mkmodel(h.ncellpow, h.ncon) # cover destructors and check for leaks
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

            send_recv_info()

    pr("AllGather spike compression (with binq standard)")
    # As interprocess spike times are on dt boundaries, need a binq
    # standard and test with binq on.
    h.mkmodel(7, 10)
    pc.spike_compress(0, 0)
    h.cvode.queue_mode(1, 0)
    std = prun()
    pc.nthread(4)
    pr("Binq with 4 threads")
    compare(std, prun())
    pc.nthread(1)

    if pc.nhost() > 1:
        for nthread, nspk, gid_compress in itertools.product(
            [1,2], [0, 3, 10], [0, 1]
        ):
            # Note: within coreneuron, if nspk is > 0 then gid_compress is turned on.
            pc.nthread(nthread)
            pc.spike_compress(nspk, gid_compress)
            coreneuron.enable = True
            pr(
                "binq nthread={} nspk={} gid_compress={}".format(
                    nthread, nspk, gid_compress
                )
            )
            pr(coreneuron.nrncore_arg(h.tstop))
            compare(std, prun2())


if __name__ == "__main__":
    test_1()
    h.finish()
