param(
	$fbSchemaBasePath = "fluentbit.schema.yml",
	$fbJsonPath = "fluent-bit-schema-3.1.5.json",
	[switch]$Strict
)

filter New-SchemaItem {
	$item = @{
		description = $_.description
		type = 'object'
		properties = @{
			#TODO: Make this a common ref somehow. This is not perfect and has issues with input
			name = @{
				const = $_.name
				description = "Name of the plugin. Supply this first and relevant intellisense for that plugin will appear."
				type = 'string'
			}
			log_level = @{
				type = 'string'
				description = "Set the plugin's logging verbosity level. Allowed values are: off, error, warn, info, debug and trace. Defaults to the SERVICE section's Log_Level."
				enum = @('off','error','warn','info','debug','trace')
			}
		}
	}

	if ($_.type -eq 'input') {
		$item.properties.tag = @{
			description = "The tag to be used for the records generated by the plugin."
			type = 'string'
		}
		$item.required = @('name')
	} else {
		# TODO: Figure out how to make these anyOf together
		$item.properties.match = @{
			description = "A pattern to match against the tags of incoming records. It's case-sensitive and supports the star (*) character as a wildcard."
			type = 'string'
		}
		$item.properties.match_regex = @{
			description = "A regular expression to match against the tags of incoming records. Use this option if you want to use the full regex syntax."
			type = 'string'
		}
		$item.anyOf = @(
			@{
				required = @('match')
			},
			@{
				required = @('match_regex')
			}
		)
	}

	# The types in the fb output are not a 1:1 match to json schema types
	foreach ($p in $_.properties.options) {
		$item.properties[$p.name.toLower()] = $p | Select-Object -ExcludeProperty Name
		$validJsonSchemaTypes = @('array', 'boolean', 'integer', 'null', 'number', 'object', 'string')
		if ($item.properties[$p.name].type -eq 'time') {
			$item.properties[$p.name].type = 'integer'
		} elseif ($item.properties[$p.name].type -notin $validJsonSchemaTypes) {
			$item.properties[$p.name].type = 'string'
		}
	}

	#Special property for processors
	if ($_.type -in 'input', 'output') {
		$item.properties['processors'] = @{
			'$ref' = '#/$defs/processors'
		}
	}

	return $item
}

#region Main
$fbInfo = Get-Content -Raw $fbJsonPath | ConvertFrom-Json
$fbSchema = Get-Content -Raw $fbSchemaBasePath | ConvertFrom-Yaml
$pipeline = $fbSchema.properties.pipeline.properties
$definitions = $fbSchema.'$defs'


foreach ($section in 'inputs', 'filters', 'outputs') {
	foreach ($item in $fbInfo.$section) {
		$definitions.$section.($item.name) = $item | New-SchemaItem
	}
	$pipeline.$section = @{
		description = "Configuration for Fluent Bit $section"
		type        = 'array'
		items       = @{
			'anyOf' = @()
		}
	}

	$pipeline.$section.items.anyOf = $definitions.$section.Keys | ForEach-Object {
		@{
			'$ref' = "#/`$defs/$section/$_"
		}
	}
}

$definitions.processorTypes = @{
	# anyOf = @(
	# 	@{
	# 		type       = 'object'
	# 		properties = @{
	# 			name = @{
	# 				type        = 'string'
	# 				description = 'Name of the processor. Supply this first and relevant intellisense for that processor will appear. This supports filters and Pipeline processors. Pipeline processors do not currently have intellisense but are documented here: https://docs.fluentbit.io/manual/pipeline/processors'
	# 			}
	# 		}
	# 	}
	# )
}

# This anyOf works for both filters and processors
$definitions.processorTypes.anyOf += $pipeline.filters.items.anyOf

#TODO: Bespoke docs for these
$definitions.nonFilterProcessors = @{}
$nonFilterProcessorNames = 'content_modifier', 'labels', 'metrics_selector', 'opentelemetry_envelope', 'sql'
foreach ($nonFilterProcessor in $nonFilterProcessorNames) {
	$definitions.nonFilterProcessors.($nonFilterProcessor) = @{
		description          = "Configuration for the $nonFilterProcessor processor"
		type                 = 'object'
		properties           = @{
			name = @{
				const       = $nonFilterProcessor
				description = 'Name of the processor. Supply this first and relevant intellisense for that processor will appear.'
				type        = 'string'
			}
		}
		additionalProperties = $true
	}
}

$definitions.processorTypes.anyOf += $definitions.nonFilterProcessors.Keys | ForEach-Object {
	@{
		'$ref' = "#/`$defs/nonFilterProcessors/$_"
	}
}

return $fbSchema


