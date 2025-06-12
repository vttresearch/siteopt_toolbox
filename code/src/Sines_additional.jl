module Sines_additional

using SpineInterface
using DataFrames, CSV, XLSX

export add_object_param
export add_object_object
export add_object_object_param
export add_object_object_param_wmuls
export add_unit
export add_unit_to_node
export add_unit_param2
export add_unit_node_param
export add_unit_node_param_emission
export add_unit_node_node
export add_unit_node_node_param
export augment_basetable
export calc_model_len
export import_objects
export import_object_param
export import_relations_2dim
export import_relations_3dim
export import_rel_param_2dim
export import_rel_param_3dim
export loadmodel_nofilter
export summarizeresults


include("common.jl")
include("db.jl")
include("results.jl")
end # module Sines_additional
