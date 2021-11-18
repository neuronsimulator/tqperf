from neuron import h, coreneuron
pc = h.ParallelContext()

h("done = 0")
h.load_file("init.hoc")

def result():
  cells = h.pnm.cells
  res =  [(int(c.pp.noutput), int(c.pp.ninput)) for c in cells]
  noutput,ninput = zip(*res)
  print("{} total cell={} output={} ninput={}".format(pc.id(), len(ninput), sum(noutput), sum(ninput)), flush=True)
  return res

def prun():
  pc.set_maxstep(10)
  h.finitialize(-65)
  pc.psolve(h.tstop)
  return result()

def prun2():
  # exercise back and forth between NEURON and CoreNEURON
  # h.tstop needs to be a multiple of 10
  pc.set_maxstep(.5)
  h.finitialize(-65)
  while h.t < h.tstop - h.dt/2.:
    for coreneuron.enable in [True, False]:
        pc.psolve(h.t + 5.0)

  return result()

def compare(std, res):
  assert std == res

def test_1():
  h.dt = 1./32.
  h.tstop = 100
  h.seq = 0
  h.spkfile = 0
  h.ncellpow = 10
  h.ncon = 100
  h.nconrange = 1
  h.mkmodel(h.ncellpow, h.ncon)
  print("netcon count ", h.List("NetCon").count())
  h.use2phase = 0
  std = prun()
  h.cvode.cache_efficient(1)

  pc.nthread(4)
  compare(std, prun())

  pc.nthread(1)
  coreneuron.verbose = 0
  coreneuron.enable = True
  compare(std, prun())
  pc.nthread(4)
  compare(std, prun())

  pc.nthread(4)
  compare(std, prun2())

if __name__ == '__main__':
  test_1()
  h.finish()
