# User guide
## How to install Siteopt

## 

## Entering data

You will need different types of data for different parameter indices and values. For example it is recommended that you use text for entity (e.g. node) names. The following datatypes can be entered in the input tables.

| Type        | Example |Notes|
|-------------|----------|----------|
| text        | n_7_elec   | use letters, numbers and underscores |
| number     | 7.1       | scientific notation is also allowed |
| Datetime     | 2025-12-31T13:00:00  | |
| timeseries     | ts:elec7       | always begin with ts: |

The actual timeseries data should be placed in a CSV file in the input data folder. The file should have two columns which have column titles "time" and "value". File name should have the format ts_ + time series name + .csv. For example if you write ts:elec7 in the input data table, file name ts_elec7.csv is expected.


