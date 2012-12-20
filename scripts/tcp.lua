---M�dulo para realiza��o de conex�es TCP. 
--Utiliza co-rotinas de lua para simular multi-thread.
--Fonte: <a href="http://www.telemidia.puc-rio.br/~francisco/nclua/index.html">Tutorial de NCLua</a>
--@class module

-- TODO:
-- * nao aceita `tcp.execute` reentrante

--Declara localmente m�dulos e fun��e globais pois, ao definir
--o script como um m�dulo, o acesso ao ambiente global � perdido
local _G, coroutine, event, assert, pairs, type, print
    = _G, coroutine, event, assert, pairs, type, print
local s_sub = string.sub

module 'tcp'

---Lista de conex�es TCP ativas
local CONNECTIONS = {}

---Obt�m a co-rotina em execu��o
--@returns Retorna o identificador da co-rotina em execu��o
local current = function ()
    return assert(CONNECTIONS[assert(coroutine.running())])
end

---(Re)Inicia a execu��o de uma co-rotinas. Estas, s�o criadas
--suspensas, assim, � necess�rio resum�-las para entrarem
--em execu��o.
--@param co Co-rotina a ser resumida
--@param ... Todos os par�metros adicionais
--s�o passados � fun��o que a co-rotina executa.
--Quando a co-rotina � suspensa com yield, ao ser resumida
--novamente, estes par�metros extras passados na chamada de resume
--s�o retornados pela yield. Isto � usado, por exemplo, na co-rotina da
--fun��o receive, para receber a resposta de uma requisi��o TCP. Assim,
--ao iniciar, co-rotina da fun��o � suspensa para que fique aguardando
--a resposta da requisi��o TCP. Quando a fun��o tratadora de eventos (handler)
--recebe os dados, ela resume a co-rotina da fun��o receive. Os dados
--recebidos s�o passados � fun��o resume, e estes s�o retornados pela fun��o
--yield depois que a co-rotina � reiniciada.
local resume = function (co, ...)
    assert(coroutine.status(co) == 'suspended')
    assert(coroutine.resume(co, ...))
    if coroutine.status(co) == 'dead' then
       CONNECTIONS[co] = nil
    end
end

---Fun��o tratadora de eventos. Utilizada para tratar 
--os eventos gerados pelas chamadas �s fun��es da classe tcp.
--@param evt Tabela contendo os dados do evento capturado
function handler (evt)
    if evt.class ~= 'tcp' then return end

    if evt.type == 'connect' then
        for co, t in pairs(CONNECTIONS) do
            if (t.waiting == 'connect') and
               (t.host == evt.host) and (t.port == evt.port) then
                t.connection = evt.connection
                t.waiting = nil
                --Continua a execu��o da co-rotina,
                --fazendo com que a fun��o connect, que causou
                --o disparo do evento connect, capturado
                --por esta fun��o (handler), seja finalizada.
                resume(co) 
                break
            end
        end
        return
    end

    if evt.type == 'disconnect' then
        for co, t in pairs(CONNECTIONS) do
            if t.waiting and
               (t.connection == evt.connection) then
                t.waiting = nil
                resume(co, nil, 'disconnected')
            end
        end
        return
    end

	--Evento disparado quando existem dados a serem recebidos,
	--ap�s a chamada da fun��o send (para enviar uma requisi��o)
  --e a chamada subsequente da fun��o receive.
    if evt.type == 'data' then
        for co, t in pairs(CONNECTIONS) do
            if (t.waiting == 'data') and
            (t.connection == evt.connection) then
                --O atributo value da tabela evt cont�m os dados
                --recebidos. Assim, continua a execu��o da fun��o que disparou
                --este evento (fun��o receive). O valor de evt.value
                --� retornado pela fun��o coroutine.yield, chamada
                --dentro da fun��o receive (que ficou suspensa
                --aguardando os dados serem recebidos).
                --Desta forma, dentro da fun��o receive, o retorno
                --de coroutine.yield cont�m os dados recebidos.
                resume(co, evt.value)
            end
        end
        return
    end
end
event.register(handler)



---Fun��o que deve ser chamada para iniciar uma conex�o TCP.
--@param f Fun��o que dever� executar as rotinas
--para realiza��o de uma conex�o TCP, envio de requisi��es
--e obten��o de resposta.   
--@param ... Todos os par�metros adicionais 
--s�o passados � fun��o que a co-rotina executa.
--@see resume
function execute (f, ...)
    resume(coroutine.create(f), ...)
end

---Conecta em um servidor por meio do protocolo TCP.
--A fun��o s� retorna quando a conex�o for estabelecida.
--@param host Nome do host para conectar
--@param port Porta a ser usada para a conex�o
function connect (host, port)
    local t = {
        host    = host,
        port    = port,
        waiting = 'connect'
    }
    CONNECTIONS[coroutine.running()] = t

    event.post {
        class = 'tcp',
        type  = 'connect',
        host  = host,
        port  = port,
    }
    
    --Suspende a execu��o da co-rotina.
    --A fun��o atual (connect) s� retorna quando
    --a co-rotina for resumida, o que ocorre
    --quando o evento connect � capturado
    --pela fun��o handler. 
    return coroutine.yield() 
end

---Fecha a conex�o TCP e retorna imediatamente
function disconnect ()
    local t = current()
    event.post {
        class      = 'tcp',
        type       = 'disconnect',
        connection = assert(t.connection),
    }
end

---Envia uma requisi��o TCP ao servidor no qual se est� conectado, e retorna imediatamente.
--@param value Mensagem a ser enviada ao servidor.
function send (value)
    local t = current()
    event.post {
        class      = 'tcp',
        type       = 'data',
        connection = assert(t.connection),
        value      = value,
    }
end


---Recebe resposta de uma requisi��o enviada previamente
--ao servidor.
--@param pattern Padr�o para recebimento dos dados.
--Se passado *a, todos os dados da resposta s�o 
--retornados de uma s� vez, sem precisar fazer
--chamadas sucessivas a esta fun��o.
--Se omitido, os dados v�o sendo retornados parcialmente,
--sendo necess�rias v�rias chamadas � fun��o.  
function receive (pattern)
    pattern = pattern or '' -- TODO: '*l'/number
    local t = current()
    t.waiting = 'data'
    t.pattern = pattern
    
    if s_sub(pattern, 1, 2) ~= '*a' then
        --Suspende a execu��o da fun��o, at� que
        --um bloco de dados seja recebido.
        --Ela s� � resumida depois que 
        --a fun��o handler (tratadora de eventos)
        --receber um bloco de dados. Nesse momento,
        --a fun��o receive retorna o bloco de dados.   
        --Tendo entrado neste if, o par�metro pattern ser�
        --diferente de '*a', logo, ser�o necess�rias
        --v�rias chamadas sucess�vas a receive para obter
        --toda a resposta da requisi��o enviada previamente
        --por meio da fun��o send.
        --A fun��o receive retorna nil quando n�o houver
        --mais nada para ser retornado.
        return coroutine.yield()
    end
    
    --Chegando aqui, � porque o par�metro pattern � igual
    --a '*a', indicando que a fun��o s� deve retornar depois
    --que toda a resposta da requisi��o enviada previamente,
    --por meio da fun��o send, tiver sido retornada.
    local all = ''
    while true do
        --Suspende a execu��o da fun��o, at� que
        --um bloco de dados seja recebido.
        --Ela s� � resumida depois que 
        --a fun��o handler (tratadora de eventos)
        --receber um bloco de dados. Nesse momento,
        --a fun��o receive retorna o bloco de dados.   
        --Se o resultado for nil, a fun��o finaliza 
        --devolvendo todos os blocos de resposta recebidos,
        --concatenados. N�o sendo nil, a fun��o suspende a execu��o
        --at� receber novo bloco.
        local ret = coroutine.yield()
        if ret then
            all = all .. ret
        else
            return all
        end
    end
end
