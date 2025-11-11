using SpineOpt

for url in ARGS
	SpineOpt.import_data(url, SpineOpt.template(), "Load SpineOpt template")
end
