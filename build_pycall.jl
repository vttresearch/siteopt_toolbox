import PyCall
using Pkg

Pkg.activate(".")
ENV["PYTHON"] = "/home/jube/anaconda3/envs/spinetb08/bin/python"
Pkg.build("PyCall")
#println(PyCall.pyprogramname)