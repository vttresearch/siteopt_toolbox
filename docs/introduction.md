# User guide

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

## Preparing the input data 

The following input files are expected to lie in the **current_input** folder:

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
 
It is recommended that you start with an example data set an modify it as needed. Not all of the files are expected to containt data. In that case just leave the header row (first row) in the file. 

In the following we will go through each of the files and show how to fill them.

### Connections table

In Siteopt and SpineOpt connections are entities which can transfer energy and material from one node to another. These include power lines and pipelines. However, Siteopt does not require that you specify what type of real infrastructure the connection represents. Instead you enter parameters which determine how these connection behave.

In **connections_input.xlsx** each row represents one connection entity. The header row shows what is expected on each column. The columns are as follows:

 Column    | Required | Description
 -------------|----------|----------
node1 | x | The originating node of the connection
node2  | x | The destination node of the connection
grid | x | The type of energy transferred: "elec", "heat" or "cool" 
alternative_name | x | The alternative which the given values refer to (normally "Base")
connection_flow_cost |  | The unit cost of energy or material transfer
connection_flow_cost.mul |  | Multiplier for the unit cost of energy or material transfer
connection_flow_cost_reverse |  | The unit cost of energy or material transfer in reverse direction
connection_flow_cost_reverse.mul |  | Multiplier for the unit cost of energy or material transfer in reverse direction
fix_ratio_out_in_connection_flow | x | Transfer efficiency
connection_investment_variable_type | x | 

### Demand data

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


## Entering data

You will need different types of data for different parameter indices and values. The following datatypes can be entered in the input tables.

| Type        | Example |Notes|
|-------------|----------|----------|
| text        | n_7_elec   | use letters, numbers and underscores |
| number     | 7.1       | scientific notation is also allowed |
| Datetime     | 2025-12-31T13:00:00  | |
| Duration     | 3h  | represents a time duration|
| timeseries     | ts:elec7       | always begin with ts: |

For datetimes such as time stamps the recommended format is ISO8601 (e.g. 2020-03-01T01:00). In case of timeseries, the actual timeseries data should be placed in a CSV file in the input data folder. The file should have two columns which have column titles "time" and "value". File name should have the format ts_ + time series name + .csv. For example if you write ts:elec7 in the input data table, file name ts_elec7.csv is expected. Note that Siteopt does not make daylight saving time adjustments.

For durations we recommed entering data in the format xU where x is an integer and U is either Y (for year), M (for month), D (for day), h (for hour), m (for minute), or s (for second). For example "60m".

## Running optimization

Optimization of the model can be started by selecting the "Optimize" tool in Toolbox and clicking "Execute selection" in the toolbar.


