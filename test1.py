from neuron import h
pc = h.ParallelContext()

h("done = 0")
h.load_file("init.hoc")

def result():
  cells = h.pnm.cells
  res =  [(int(c.pp.noutput), int(c.pp.ninput)) for c in cells]
  noutput,ninput = zip(*res)
  print("{} total cell={} output={} ninput={}".format(pc.id(), len(ninput), sum(noutput), sum(ninput)))
  return res

def prun():
  pc.set_maxstep(10)
  h.finitialize()
  pc.psolve(h.tstop)
  return result()

def compare(std, res):
  assert std == res

def test_1():
  h.seq = 0
  h.spkfile = 0
  h.ncellpow = 10
  h.ncon = 100
  h.mkmodel(h.ncellpow, h.ncon)
  h.use2phase = 0
  std = prun()
  h.cvode.cache_efficient(1)

  pc.nthread(4)
  compare(std, prun())

  pc.nthread(1)
  from neuron import coreneuron
  coreneuron.verbose = 0
  coreneuron.enable = True
  compare(std, prun())

  pc.nthread(4)
  compare(std, prun())

if __name__ == '__main__':
  test_1()
  h.finish()
