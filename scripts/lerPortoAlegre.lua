local util = require 'util'
local http = require 'http'

PROPRIEDADE_NOME = 'mensagempoa'


local URL = "http://h264.lavid.ufpb.br/~alan/poa.txt"

function handler (e)

	if (e.class == 'ncl' and e.type == 'presentation' and e.action=='start') then
		print('imagem1 iniciada')
		readTextFromHtml(URL)
	end

end


function readTextFromHtml(url)
	print("<><> Acessando:", url) io.flush()

	http.request(url, display)
end


--funcao callback
--header: cabecalho da resposta do http
--body: corpo da resposta (neste caso, texto)
function display(header, body)

	
	print("<><> valor lido:", body) io.flush()

	geraEventoDeAtriuicao(PROPRIEDADE_NOME, valorNumericoTemperatura)

end


function geraEventoDeAtriuicao(nomePropriedade, valor)

		evt = {
			class    = 'ncl',
			type     = 'attribution',
			action   = 'start',
			name	 = nomePropriedade,
			value    = valor,
		}

		event.post(evt) -- evento de inicio da atribuicao
		evt.action = 'stop'
		event.post(evt) -- evento de final da atribuicao

		print('Evento de atribuicao gerado:', evt.value) io.flush()
end


event.register(handler)
