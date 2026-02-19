
# Script for installing Spine Toolbox, Siteopt and its Julia dependencies.
# Prerequisities: Julia language and Miniconda must be installed.
# Running: julia install.jl in command prompt.

using Pkg

# assuming Miniconda has been installed
# check if environment already exists, in that case delete it
buf = IOBuffer()
run(pipeline(`conda env list`, buf))
seekstart(buf)
env_exists = any(x -> occursin("spinetb", x), readlines(buf))
if env_exists
	println("Removing previous installation...")
	run(`conda env remove --name spinetb --yes`)
end
	
# create conda environment and install Spine Toolbox
run(`conda create --name spinetb python=3.12 --yes`)
println("Installing Spine Toolbox. This can take several minutes.")
run(`conda run -n spinetb python -m pip install spinetoolbox`)

# find python path
buf = IOBuffer()
run(pipeline(`conda run -n spinetb where python`, buf))
seekstart(buf)
myline = filter(x -> occursin("miniconda", x), readlines(buf))
if isempty(myline)
	error("Miniconda Python path not found!")
end

# setting PyCall to use the prepared Miniconda environment
println("Updating PyCall library...")
Pkg.activate()
ENV["PYTHON"] = myline[1]
Pkg.add("PyCall")
Pkg.build("PyCall")

println("Installing Siteopt...")
Pkg.activate("./code")
Pkg.add(url="https://github.com/spine-tools/SpinePeriods.jl.git", rev="clustering")
Pkg.add(url="https://github.com/spine-tools/SpineOpt.jl.git", rev="elexia")
Pkg.instantiate()
