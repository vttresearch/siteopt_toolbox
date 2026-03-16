# User guide

## Introduction 

Siteopt can represent detailed interactions between buildings, local energy production, storage, and the wider grid, allowing planners to explore how different technologies and operating strategies perform over time. By capturing temporal variability such as hourly demand, weather‑driven renewable output, and dynamic electricity prices, Siteopt helps identify cost‑efficient, low‑carbon solutions for heating, cooling, and electricity supply. Its modular structure also makes it easy to test future scenarios, compare investment options for sustainable district‑level energy planning.
 
## Standard workflow

The standard workflow for Siteopt usage can be outlined as follows:

* Visualizing the model topology and needed entities in one's own mind or paper
* Preparing the input data in form of excel files and CSV files
* Moving the input files to the **current_input** folder of a Siteopt installation
* Starting Spine Toolbox and building the model database
* Optionally selecting representative time periods
* Running optimization
* Compiling result summary
* Analyzing results

## Visualizing the model topology and needed entities

It is important to understand the way energy systems are abstracted in Siteopt. Abstraction can be a bit daunting at first but it allows the Siteopt to model a wider variety of systems instead of limiting to a very restricted set of components.

![Basic example](images/basic_example.svg){title="Example energy system with two loads.}


## Preparing the input data 

The input is mostly given as Microsoft Excel files. Timeseries files are given in comma separated value (CSV) format. The following input files are expected to lie in the **current_input** folder:

 Subfolder    | Filename |Notes
-------------|----------|----------
 connections/ |  connections_input.xlsx | Connection entity parameters 
 demand/  | tscr_cooldemand.csv  | cooling demand timeseries in SpineOpt format 
 demand/  | tscr_elecdemand.csv | cooling demand timeseries in SpineOpt format 
 demand/  | tscr_heatdemand.csv | heat demand timeseries in SpineOpt format 
 nodes/   | nodes.xlsx  |  node listing and their parameters 
 other_units/   | divertingunits.xlsx  |  special units which create branching flows 
 production/   | pv-input.xlsx  |  PV and other variable generation unit parameters 
 production/   | hp-input.xlsx  |  heat pump and chiller unit parameters 
 representative_periods/   | repr_settings_elexia.json  | representative period selection settings 
 representative_periods/   | representative_periods_template.json  | generic information for representative periods 
 storages/  | storages-input.xlsx  |  storage unit parameters 
   | modelspec.xlsx  |  model time horizon parameters 
   | scenarios.xlsx  |  study scenarios definition 
 
!!! info "Important Information"
    It is recommended that you start with an example data set an modify it as needed. 

Not all of the files are expected to containt data. In that case just leave the header row (first row) in the file. In addition to the above mentioned files, the user can also add additional timeseries as CSV files. They can be referenced from the Excel files as explained below.

In the following we will go through each of the files and show how to fill them.

### Connections table

In Siteopt and SpineOpt connections are entities which can transfer energy and material from one node to another. These include power lines and pipelines. However, Siteopt does not require that you specify what type of real infrastructure the connection represents. Instead you enter parameters which determine how these connection behave.

In **connections_input.xlsx** each row represents one connection entity. The header row shows what is expected on each column. The columns are as follows:

 Column    | Required | Description
 -------------|----------|----------
node1 | x | The originating city block of the connection
node2  | x | The destination city block of the connection
grid | x | The type of energy transferred: "elec"  (electricity), "heat" (heating) or "cool" (cooling) 
alternative_name | x | The alternative which the given values refer to (normally "Base")
connection_flow_cost |  | The unit cost of energy or material transfer, e.g. €/kWh
connection_flow_cost.mul |  | Multiplier for the unit cost of energy or material transfer
connection_flow_cost_reverse |  | The unit cost of energy or material transfer in reverse direction
connection_flow_cost_reverse.mul |  | Multiplier for the unit cost of energy or material transfer in reverse direction
efficiency |  | Transfer efficiency (e.g. 0.95 meaning 95 %)


!!! info "Important Information"
    Write the grid names exactly the same way in all tables. 
	
	
### Demand data

Demand data for three grids (electricity, heating and cooling) can be given in cross-tabulated CSV files. These are:

* tscr_cooldemand.csv for cooling demand timeseries
* tscr_elecdemand.csv for electricity demand timeseries
* tscr_heatdemand.csv for heat demand timeseries

The format of these files is the following:

 Column header   | Required | Description
 -------------|----------|----------
Objectclass | x | "node"
Parameter_name | x | "demand"
alternative | x | The alternative which the given values refer to (normally "Base")
time | x | Timestamp in ISO8601 format YYYY-MM-DDTHH\:mm\:SS
n_1_elec |  | Any following columns should have header name of the node in SpineOpt format. It should be preceeded by "n_" then have the cityblock name followed by the grid name e.g. "_elec". The column then contains the actual values.


### The nodes table

In **nodes.xlsx** each row represents one node. However, you can give several alternative parameter values for a node, and in this case each alternative makes one row.

 Column    | Required | Description
 -------------|----------|----------
node | x | Node name
grid | x | The type of energy transferred: "elec", "heat" or "cool" 
alternative_name |  | The alternative which the given values refer to (normally "Base")
balance_type |  | Can define the node as free node if balance_type_none is given
demand |  | Demand of energy or material in the node

Node names should be unique. However, you can use the same name in different grids. Normally the incoming flows to node must match the outgoing flows and possible demand. However, if one declares **balance_type_none** then no such condition is enforced.

### Production units table

In **pv_units.xlsx** the user defines renewable generation units such as PV units and wind turbines or solar collectors.


Column    | Required | Description
 -------------|----------|----------
block_identifier | x | City block name
grid | x | The type of energy produced: "elec", "heat" or "cool" 
name | x | The name of the unit, which can be the same if the unit exists in many blocks
alternative_name | x | The alternative which the given values refer to (normally "Base")
unit_capacity | x | The capacity of one subunit (e.g. kilowatts). Normally here one enters the time series for the capacity factor of the unit.
unit_investment_cost |  | The investment cost of one subunit as annualized cost (e.g. €/kW/year if subunit is 1 kW).
candidate_units |  | The maximum number of subunits which can be built.
representative_unit |  | An "X" indicates that the capacity factor of this unit will be used when selecting the representative periods for optimization.

There are also data related to the supply chain carbon dioxide emissions of the production units:

Column    | Required | Description
 -------------|----------|----------
investment_emission |  | The hourly carbon dioxide emission arising from one subunit (e.g. kg/hour)
emission_cost |  | The cost of these carbon dioxide emissions (e.g. €/kg)

### Heat pumps and chiller units table

In **hp_units.xlsx** the user defines heat pumps and chillers. Unlike renewable generation units (defined in **pv_units.xlsx**) these technologies require electricity to operate.

Column    | Required | Description
 -------------|----------|----------
block_identifier | x | City block name
type | x | The type of energy produced: "heat" or "cool" 
alternative_name | x | The alternative which the given values refer to (normally "Base")
unit_capacity | x | The capacity of one subunit (e.g. kilowatts). Normally here one enters the time series for the capacity factor of the unit.
unit_investment_cost |  | The investment cost of one subunit as annualized cost (e.g. €/kW/year if subunit is 1 kW).
cop_profile | x | The coefficient of performance (COP) factor (unitless)


## Entering data

You will need different types of data for different parameter indices and values. The following datatypes can be entered in the input tables.

| Type        | Example |Notes|
|-------------|----------|----------|
| text        | n_7_elec   | use letters, numbers and underscores |
| number     | 7.1       | scientific notation is also allowed |
| Datetime     | 2025-12-31T13:00:00  | Format YYYY-MM-DDTHH\:mm\:ss |
| Duration     | 3h  | represents a time duration|
| timeseries     | ts:elec7       | always begin with ts: |

For datetimes such as time stamps the recommended format is ISO8601 (e.g. 2020-03-01T01:00). In case of timeseries, the actual timeseries data should be placed in a CSV file in the input data folder (same folder as the referencing Excel file). The file should have two columns which have column titles "time" and "value". File name should have the format ts_ + time series name + .csv. For example if you write ts:elec7 in the input data table, file name ts_elec7.csv is expected. Note that Siteopt does not make daylight saving time adjustments.

For durations we recommed entering data in the format xU where x is an integer and U is either Y (for year), M (for month), D (for day), h (for hour), m (for minute), or s (for second). For example "60m".

## Running optimization

Optimization of the model can be started by selecting the "Optimize" tool in Toolbox and clicking "Execute selection" in the toolbar.


