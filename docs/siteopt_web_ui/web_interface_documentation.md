# SiteOpt Web Interface

SiteOpt Web Interface (https://extgit.vtt.fi/siteopt/siteopt-web-interface) is a web application for using the 
SiteOpt tool (https://extgit.vtt.fi/siteopt/siteopt_toolbox) tool. 
It enables users to edit input data, define/select different scenarios, create work folders, execute the scenarios, 
and view output results. SiteOpt tool has been implemented as a Spine Toolbox project. Spine Toolbox is available in 
a public GitHub repository https://github.com/spine-tools/Spine-Toolbox. Spine Toolbox is an open source Python 
package to manage data, scenarios and workflows for modelling and simulation. Spine Toolbox project is a combination 
of a workflow, computational steps (tools), the relationships between tools and input data. **SiteOpt 
Web Interface** is a simplified version of Spine Toolbox, dedicated to running a single project, i.e. SiteOpt tool. 
This is a web app, so you need to use a browser to view the site. Supported browsers are Firefox and Chrome. Other 
browsers may work as well but are not supported.

<figure markdown="span">
    ![Image title](web_interface_front_page.png){ width="100%" }
  <figcaption><i>Web interface home page (draft)</i></figcaption>
</figure>

## 1. Overview
**Name:** SiteOpt Web Interface  
**Purpose:** A web application for using the SiteOpt tool.  
**Status:** beta  
**Repo(s):** https://extgit.vtt.fi/siteopt/siteopt-web-interface  
**Maintainer:** Pekka Savolainen (Research Scientist, VTT)  
**Developers:** Pekka Savolainen (VTT), Tomasz Wolski (AMC TECH), Jussi Ikäheimo (VTT)  

## 2. Architecture
- Frontend: Vue 3 (Composition API, Pinia/Vuex, Vite or webpack)
- Backend: Python (Django + Django REST Framework)
- Database: SQLite
- Auth: None
- Build/Deploy: [Tauri](https://v2.tauri.app/), Docker

## Installation instructions
See installation instructions in SiteOpt Web Interface repository (https://extgit.vtt.fi/siteopt/siteopt-web-interface)

## Core Features

- Feature A: Adding input data to the website
- Feature B: Adding SiteOpt project to the website
- Feature C: Creating a work folder
- Feature D: Inspecting and editing input data
- Feature E: Selecting scenarios
- Feature F: Selecting SiteOpt tool execution mode
- Feature G: Executing the SiteOpt tool
- Feature H: Inspecting output data

### Feature A: Adding input data to the website
Input data (available in https://extgit.vtt.fi/siteopt/siteopt_data) is a collection of files that are available in 
a Git repository hosted by VTT. It consists of Excel files, CSV (comma separated value), 
and JSON files. The files are categorized into the following categories.

- connections
- demand
- nodes
- other_units
- production
- representative_periods
- storages

In addition, modelspec.xlsx, scenarios.xlsx and output_recipe.json contain basic information about the 
model. Users should clone the repo into a local folder on their computer. To add the input data into the Web
app, there is a widget on the page to add the local input data folder path.

Input data could have been shared in the same repo as the SiteOpt project, but for data confidentiality reasons, it's separated
into it's own repo.

### Feature B: Adding SiteOpt project to the website
SiteOpt project (https://extgit.vtt.fi/siteopt/siteopt_toolbox) contains the definition of the workflow, 
relationships between different workflow items, source code for the items in the workflow, database files (SQLite), 
and paths to the files used by the workflow items. The root folder of the repo is a Spine Toolbox project, which means
that it has been created using Spine Toolbox. You can view the project yourself by installing Spine Toolbox 
(https://github.com/spine-tools/Spine-Toolbox), starting the app and opening the SiteOpt project using the menu in the 
app.

### Feature C: Creating a work folder
The input data and the SiteOpt project are delivered as a Git repo, so we need a system which supports different users 
to edit the data and the project settings to their liking. For this purpose, we have a system called 'work' folders in 
the app. The idea is that the user can make a work folder where he/she can edit the data for a specific run to their
liking, and keep at the same time keep the original data intact.

When user creates a work folder in the app, the system first creates a new folder with the given name, then copies 
all the contents of the SiteOpt project folder to the new folder, and then copies all the contents of the input data 
folder into the same work folder. The files in the work folder are editable. The original input data and project 
folder are not editable.

### Feature D: Inspecting and editing input data 
Once a work folder has been created, the user can view the data of a selected input file (Excel, CSV, JSON) in a 
table or plot the data if the data format is such that it allows plotting. Users can also edit the data of a selected 
cell.

### Feature E: Selecting scenarios
Scenarios are defined in the SiteOpt project, and they are exposed to the web app for easy access. The user can 
select the scenarios to run once the SiteOpt tool is executed.

### Feature F: Selecting SiteOpt tool execution mode
The SiteOpt tool provides different execution modes, which depend on the parts of the workflow that are executed. 
In addition to running the whole workflow, there are options for running for example, 'collect data', and 
'run SpineOpt' parts of the workflow. 

### Feature G: Executing the SiteOpt Tool
Once the work folder is created, data edited, scenarios and execution mode selected, the user can execute the 
project by clicking the Play button in the vicinity of the work folder in the UI. Executing the whole workflow can 
take 1-2 hours. 

### Feature H: Inspecting output data
Once execution has finished, the output data files appear in the work folder. When the user selects an output file, 
the data from the file appears in a table and there's an option to plot the data as well. 
