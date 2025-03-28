# Installing the Siteopt tool

You need Spine Toolbox and Julia language for running the Siteopt tool. You also need the Git software. Install them first.

## Spine Toolbox
You need Spine Toolbox for running the toolbox project. In addition, it is needed for using the databases.

- Install Git software (https://git-scm.com/downloads). The installer asks many questions, use the default answers.
- Install Miniconda (https://docs.anaconda.com/miniconda/install/). Add Miniconda to path variable in Windows
- Create a Miniconda environment for Spine Toolbox and activate it. I.e., run the following in command prompt:


```
> conda init
> conda create -n spinetoolbox python=3.12
> conda activate spinetoolbox
```

N.B. If you get error CondaError: Run 'conda init' before 'conda activate', run 

```
> source activate base
> conda activate spinetoolbox
```

- Install Spine toolbox as described in https://github.com/Spine-tools/Spine-Toolbox?tab=readme-ov-file#installation-from-sources-using-git


## Python dependencies of the Siteopt tool

- Create a Miniconda environment for Siteopt python dependencies and activate it. I.e., run the following in command prompt:

```
>conda create -n spinedb python=3.11
>conda activate spinedb
```

Next install the Spine DB API (https://github.com/spine-tools/Spine-Database-API) and Scikit learn extra (https://scikit-learn-extra.readthedocs.io/en/stable/install.html)
```
>pip install spinedb_api
>conda install -c conda-forge scikit-learn-extra
```

## Julia language

Install Julia language (at least version 1.10). See https://julialang.org/downloads/ for instructions.


## Downloading the Siteopt tool

Install Git software (https://git-scm.com/downloads). The installer asks many questions, use the default answers. Check the URL of the siteopt repository by logging into extgit.vtt.fi. Press the "Code" button to see the address. Use the one which begins with https. 

Select an empty folder in your machine. Start command prompt and 

```
git clone https://extgit.vtt.fi/...
```

(replace ... by the actual URL). 


## Siteopt installation

Go to Siteopt **code** folder and start Julia console (type "julia" in command prompt). Run commands:
  
```
Using Pkg
Pkg.activate(".")
Pkg.resolve()
Pkg.instantiate()
```	
Rebuilding Julia PyCall package is needed to be able to connect to the databases. This is done by running the following commands in Julia console:

```
Pkg.add("PyCall")
ENV["PYTHON"] = raw"C:\\path\\to\\your\\python\\python.exe" #(replace the path by the Python executable in the Miniconda environment where you installed Spine Toolbox )
Pkg.build("PyCall")
```


## Input data

Check that you have the following input files in the **current_input** folder.

XXX

# Running the Siteopt tool

Spine Toolbox provides a graphical user interface for running SpineOpt and editing databases. Of the different tools the Toolbox project needs most configurations.

Activate the proper Miniconda environment, which you used to install Spine Toolbox. Start Spine Toolbox by command

```
> conda activate spinetoolbox
> spinetoolbox
```

in console (e.g. "cmd" in Windows).

Install SpineOpt plugin (Plugins->Install plugin…, select SpineOpt). 
Now Open the Siteopt toolbox project (File->open). You select a folder, not a file when opening a project.
Go to File->Settings. Go to Tools tab. Check that in **Julia** box the second line points to the code folder (See figure below).

XXX

Check also the tool specifications Julia project settings.


Select each of the databases one at a time. In "data store properties" click "New Spine db". A new dialogue opens. Click "Save".



