import PyCall
using Pkg

Pkg.activate(".")
ENV["PYTHON"] = "/home/jube/anaconda3/envs/spinedb/bin/python"
Pkg.build("PyCall")
#println(PyCall.pyprogramname)