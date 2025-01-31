module server

import lsp
import analyzer.psi
import loglib

pub fn (mut ls LanguageServer) signature_help(params lsp.SignatureHelpParams) lsp.SignatureHelp {
	mut help := lsp.SignatureHelp{}
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri) or { return help }

	offset := file.find_offset(params.position)
	element := file.psi_file.find_element_at(offset) or {
		loglib.with_fields({
			'offset': offset.str()
		}).warn('Cannot find element')
		return help
	}

	call := element.parent_of_type_or_self(.call_expression) or {
		loglib.with_fields({
			'offset': offset.str()
		}).warn('Cannot find call expression')
		return help
	}

	if call is psi.CallExpression {
		resolved := call.resolve() or {
			loglib.with_fields({
				'offset': offset.str()
			}).warn('Cannot resolve call expression for signature help')
			return help
		}

		if resolved is psi.FunctionOrMethodDeclaration {
			ctx := params.context
			active_parameter := call.parameter_index_on_offset(offset)

			if ctx.is_retrigger {
				help = ctx.active_signature_help
				help.active_parameter = active_parameter
				return help
			}

			signature := resolved.signature() or { return help }
			parameters := signature.parameters()

			mut param_infos := []lsp.ParameterInformation{}
			for parameter in parameters {
				param_infos << lsp.ParameterInformation{
					label: parameter.get_text()
				}
			}

			return lsp.SignatureHelp{
				active_parameter: active_parameter
				signatures: [
					lsp.SignatureInformation{
						label: 'fn ${resolved.name()}${signature.get_text()}'
						parameters: param_infos
					},
				]
			}
		}
	}

	return help
}
