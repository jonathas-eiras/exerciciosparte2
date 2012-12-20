
require "tcp"
require "base64"
require "util"

local _G, tcp, print, util, base64, string, coroutine, table, type = 
      _G, tcp, print, util, base64, string, coroutine, table, type

module "http"

version = "NCLuaHTTP/0.9.9"

---Separa o header do body de uma resposta a uma requisi��o HTTP
--@param response String contendo a resposta a uma requisi��o HTTP
--@return Retorna o header e o body da resposta da requisi��o
local function getHeaderAndContent(response)
    --Procura duas quebras de linha consecutivas, que separam
    --o header do body da resposta
	local i = string.find(response, string.char(13,10,13,10))
	local header, body = "", ""
	if i then
	   header = string.sub(response, 1, i)
	   body = string.sub(response, i+4, #response)
	else 
	   header = response
	end
	return header, body
end

---Envia uma requisi��o HTTP para um determinado servidor
--@param url URL para a p�gina que deseja-se acessar. A mesma pode incluir um n�mero de porta,
--n�o necessitando usar o par�metro port.
--@param callback Fun��o de callback a ser executada quando
--a resposta da requisi��o for obtida. A mesma deve possuir
--em sua assinatura, um par�metro header e um body, que conter�o, 
--respectivamente, os headers retornados e o corpo da resposta
--(os dois como strings).
--@param method M�todo HTTP a ser usado: GET ou POST. Se omitido, � usado GET.
--onde a requisi��o deve ser enviada
--@param params String com o conte�do a ser adicionado � requisi��o,
--ou uma tabela, contendo pares de paramName=value,
--no caso de requisi��es post enviando campos de formul�rio. 
--Deve estar no formato URL Encode. 
--No caso de requisi��es GET, os par�metros devem ser passados 
--diretamente na URL. Opcional
--@param userAgent Nome da aplica��o/vers�o que est� enviando a requisi��o. Opcional
--@param headers Headers HTTP adicionais a serem inclu�dos na requisi��o. Opcional
--@param user Usu�rio para autentica��o b�sica. Opcional
--@param password Senha para autentica��o b�si��o. Opcional
--@param port Porta a ser utilizada para a conex�o. O padr�o � 80, no caso do valor ser omitido.
--A porta tamb�m pode ser especificada diretamente na URL. Se for indicada uma porta l� e aqui
--no par�metro port, a porta da url � que ser� utilizada e a do par�metro port ser� ignorada.
--@return Retorna o header e o body da resposta da requisi��o HTTP
function request(url, callback, method, params, userAgent, headers, user, password, port)
    headers = headers or ""
    params = params or ""
    if method == nil or method == "" then
       method = "GET"
    end
    userAgent = userAgent or version
		port = port or 80
    method = string.upper(method)
    if method ~= "GET" and method ~= "POST" then
       error("Par�metro method deve ser GET ou POST")
    end
    
    local co = false
    local protocol, host, port1, path = splitUrl(url)
    --Se existir uma n�mero de porta dentro da URL, o valor do par�metro port � ignorado e 
    --recebe a porta contida na URL.
    if port1 ~= "" then
       port = port1
    end
    if protocol == "" then
       protocol = "http://"
       url = protocol .. url
    end
    
    function sendRequest()
	    tcp.execute(
	        function ()
	            tcp.connect(host, port)
	            --conecta no servidor
	            print("Conectado a "..host.." pela porta " .. port)
	            
				  		--Troca espa�os na URL por %20
	            url = string.gsub(url, " ", "%%20")
	            local request = {}
				local fullUrl = ""
				if port == 80 then
				   fullUrl = url
				else
				   fullUrl = protocol .. host .. ":" ..port .. path
				end
              --TODO: O uso de HTTP/1.1 tava fazendo com que a app congelasse 
              --ao tentar obter toda resposta de uma requisi��o.
              --No entanto, pelo q sei, o cabe�alho Host: usado abaixo
              --� espec�fico de HTTP 1.1, mas isto n�o causou problema.
	            table.insert(request, method .." "..fullUrl.." HTTP/1.0")
	            
	            if userAgent and userAgent ~= "" then
	               table.insert(request, "User-Agent: " .. userAgent)
	            end
	               
	            if params ~= "" then
	               --Se params for uma tabela 
	               --� porque ela representa uma lista
	               --de campos a serem enviados via POST, logo
	               --adicione o content-type espec�fico para este caso.
	               if (method=="POST") and (type(params) == "table") then
	                   if headers ~= "" then
	                      headers = headers .. "\n"
	                   end
	                   headers = headers.."Content-type: application/x-www-form-urlencoded"
	               end
	            end
	               
	            if headers ~= "" then
	               table.insert(request, headers)
	            end   
	            --O uso de Host na requisi��o � necess�rio
	            --para tratar redirecionamentos informados 
	            --pelo servidor (c�digo HTTP como 301 e 302)
	            table.insert(request, "Host: "..host)
	            if user and password and user ~= "" and password ~= "" then
	               table.insert(request, "Authorization: Basic " .. 
	                     base64.enc(user..":"..password))
	            end
                if params ~= "" then
                   if type(params) == "table" then
                      params = util.urlEncode(params)
                   end
                   --length of the URL-encoded params data
                   table.insert(request, "Content-Length: " .. #params.."\n")
                   table.insert(request, params)
                end   	            
		        table.insert(request, "\n")
                --Pega a tabela contendo os dados da requisi��o HTTP e gera uma string para ser enviada ao servidor
			    local requestStr = table.concat(request, "\n")
	            print("\n--------------------Request: \n\n"..requestStr)
	            --envia uma requisi��o HTTP para obter o arquivo XML do feed RSS
	            tcp.send(requestStr)
	            --obt�m todo o conte�do do arquivo XML solicitado
	            local response = tcp.receive("*a") --par�metro "*a" = receber todos os dados da requisi��o de uma vez s�
	            if response ~= nil then
                   print("\n\n----------------------------Resposta da requisi��o obtida\n\n")
  		        end
		          
	            tcp.disconnect()
			    print("\n--------------------------Desconectou")
	    	    coroutine.resume(co, response)        
	        end
	    )    
	    print("\n--------------------------Saiu da body function")
    end
    
    local function startRequestProcess()
	    print("\n--------------------------Iniciar co-rotina (resume)")
	    coroutine.resume(coroutine.create(sendRequest))
	    print("\n--------------------------Terminou resume")
	    co = coroutine.running()
	    print("\n--------------------------Co-rotina suspensa (yield)")
	    --Bloqueia o programa at� obter o retorno da co-rotina
	    --(que retornar� a resposta da requisi��o HTTP)
	    local response =  coroutine.yield()
	    print("\n--------------------------Co-rotina finalizada (terminou yield)")
        if callback then
           callback(getHeaderAndContent(response))
	    end
    end
    
    util.coroutineCreate(startRequestProcess)
end

---Envia uma requisi��o HTTP para uma URL que represente um arquivo,
--e ent�o faz o download do mesmo.
--@param url URL para a p�gina que deseja-se acessar. A mesma pode incluir um n�mero de porta,
--n�o necessitando usar o par�metro port.
--@param callback Fun��o de callback a ser executada quando
--a resposta da requisi��o for obtida. A mesma deve possuir
--em sua assinatura, um par�metro header e um body, que conter�o, 
--respectivamente, os headers retornados e o corpo da resposta
--(os dois como strings).
--@param fileName Caminho completo para salvar o arquivo localmente.
--S� deve ser usado para depura��o, pois passando-se
--um nome de arquivo, far� com que a fun��o use o m�dulo io,
--n�o dispon�vel no Ginga. Para uso em ambientes
--reais (Set-top boxes), deve-se passar nil para o par�metro
--@param userAgent Nome/vers�o do cliente http. Opcional
--@param user Usu�rio para autentica��o b�sica. Opcional
--@param password Senha para autentica��o b�si��o. Opcional
--@param port Porta a ser utilizada para a conex�o. O padr�o � 80, no caso do valor ser omitido.
--A porta tamb�m pode ser especificada diretamente na URL. Se for indicada uma porta l� e aqui
--no par�metro port, a porta da url � que ser� utilizada e a do par�metro port ser� ignorada.
--@return Se o par�metro fileName for diferente de nil,
--retorna true em caso de sucesso, e false em caso de erro.
--Caso contr�rio, retorna o conte�do do arquivo, caso o mesmo
--seja obtido, caso contr�rio, retorna false.
function getFile(url, callback,headers, fileName, userAgent, user, password, port)
    --(url, method, params, userAgent, headers, user, password)
    local header, body = request(url, callback, "GET",nil, userAgent,headers, user, password, port)

    if header then
       --print(response, "\n")
       print("Dados da conexao TCP recebidos")
       --Verifica se o c�digo de retorno � OK

       if string.find(header, "200 OK") then
          if fileName == nil then
             return body
          else
             util.createFile(body, fileName, true)
	     print("chamei a funcao de criar")
             return true
          end
       end
       return false
    else
       print("Erro ao receber dados da conexao TCP")
       return false
    end
end

---Obt�m o valor de um determinado campo de uma resposta HTTP
--@param header Conte�do do cabe�alho da resposta HTTP de onde deseja-se extrair
--o valor de um campo do cabe�alho
--@param fieldName Nome do campo no cabe�alho HTTP
function getHttpHeader(header, fieldName)
  --Procura a posi��o de in�cio do campo
  local i = string.find(header, fieldName .. ":")
  --Se o campo existe
  if i then
     --procura onde o campo termina (pode terminar com \n ou espa�o
     --a busca � feita a partir da posi��o onde o campo come�a
     local fim = string.find(header, "\n", i) or string.find(header, " ", i)
     return string.sub(header, i, fim)
  else
     return nil
  end
end

---Obt�m uma URL e divide a mesma em protocolo, host, porta e path
--@param url URL a ser dividida
--@return Retorna o protocolo, host, porta e o path obtidas da URL.
--Caso algum destes valores n�o exita na URL, � retornada uma string vazia no seu lugar.
function splitUrl(url)
  --TODO: O uso de express�es regulares seria ideal nesta fun��o
  --por meio de string.gsub

  local protocolo = ""
  local separadorProtocolo = "://"
  --procura onde inicia o nome do servidor, que � depois do separadorProtocolo
  local i = string.find(url, separadorProtocolo)
  if i then 
     protocolo = string.sub(url, 1, i+2)
 	   --soma o tamanho do separadorProtocolo em i para pular o separadorProtocolo, 
     --que identifica o protocolo,
	   --e iniciar na primeira posi��o do nome do host
	   i=i+#separadorProtocolo
  else
     --se a URL n�o possui um protocolo, ent�o o nome
     --do servidor inicia na primeira posi��o
     i = 1
  end

  local host, porta, path = "", "", ""
  --procura onde termina o nome do servidor, 
  --na primeira barra ap�s o separadorProtocolo
  local j = string.find(url, "/", i)
  --se encontrou uma barra, copia o nome do servidor at� a barra,
  --pois ap�s ela, � o path
  if j then
     host = string.sub(url, i, j-1)
     path  = string.sub(url, j, #url)
  else
     --sen�o, n�o h� um path ap�s o nome do servidor, sendo o restante da url
     --o nome do servidor
     host = string.sub(url, i)
  end

  --verifica se h� um n�mero de porta dentro do host (a porta vem ap�s os dois pointos)
  i = string.find(host, ":")
  if i then
    porta = string.sub(host, i+1, #host)
    host = string.sub(host, 1, i-1)
  end
  
  return protocolo, host, porta, path
end

