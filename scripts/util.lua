

local _G, io, print, string, coroutine, canvas, tonumber, pairs, type = 
      _G, io, print, string, coroutine, canvas, tonumber, pairs, type

module "util"


function cloneTable(tb)
  local result = {}
  for k, v in pairs(tb) do
    result[k] = v
  end
  return result
end


function printable(tb, level)
  level = level or 1
  local spaces = string.rep(' ', level*2)
  for k,v in pairs(tb) do
      if type(v) ~= "table" then
         print(spaces .. k..'='..v)
      else
         print(spaces .. k)
         level = level + 1
         printable(v, level)
      end
  end  
end


function breakString(text, maxLineSize)
  local t = {}
  local str = text
  local i, fim, countLns = 1, 0, 0

  if (str == nil) or (str == "") then
     return t
  end 

  str = string.gsub(str, "\n", " ")
  str = string.gsub(str, "\r", " ")
    
  while i <= #str do
     countLns = countLns + 1
     if i > #str then
        t[countLns] = str
     else
        fim = i+maxLineSize-1
        if fim > #str then
           fim = #str
        else
	       
	        if string.byte(str, fim) ~= 32 then
	           fim = string.find(str, ' ', fim)
	           if fim == nil then
	              fim = #str
	           end
	        end
        end
        t[countLns]=string.sub(str, i, fim)
        i=fim+1
     end
  end
  
  return t
end



function paintBreakedString(areaWidth, x, initialY, text)
     
     local tw, th = canvas:measureText("a")
    
     local charsByLine = tonumber(string.format("%d", areaWidth / tw))
     
     
     local textTable = breakString(text, charsByLine)
     local y = initialY
     
     for k,ln in pairs(textTable) do
         canvas:drawText(x, y, ln)
         y = y + th
         print("---------------------"..ln)
     end
end


function paintText(x, y, text, fontName, fontSize, fontColor)
     if fontName and fontSize then
        canvas:attrFont(fontName, fontSize)
     end
     if fontColor then
        canvas:attrColor(fontColor)
     end
     
     
     local cw, ch = canvas:attrSize()
     canvas:drawText(x, y, text)     
end


--DEVIDO AO USO DO MÓDULO IO, ESTA FUNÇÃO
--NÃO É PERMITIDA NO CONTEXTO DE TVD,
--POIS O MÓDULO IO NÃO FAZ PARTE DO GINGA
---Verifica se um arquivo existe
--@param fileName Nome do arquivo a ser verificado
--@return Retorna true se o arquivo existir
--[[
function fileExists(fileName)
  local file = io.open(fileName)
  if file then
    io.close(file)
    return true
  else
    return false
  end
end
--]]



function createFile(content, fileName, binaryFile)
    binaryFile = binaryFile or false
    local mode = ""
    if binaryFile then
       mode = "w+b"
    else
       mode = "w+"
    end
    file, err = io.open(fileName, mode)
    if file == nil then
    	print("Erro ao abrir arquivo "..fileName.."\n".. err)
    	return false
    else
    	print("Arquivo", fileName, "criado com sucesso")
        file:write(content)
        file:close()
        return true
    end
end


function urlEncode(t)
	  local function escape (s)
	    s = string.gsub(s, "([&=+%c])", function (c)
	          return string.format("%%%02X", string.byte(c))
	        end)
	    s = string.gsub(s, " ", "+")
 	    return s
 	  end

      if type(t) == "string" then
         return escape(t)
      else
	     local s = ""
	     for k,v in pairs(t) do
	       s = s .. "&" .. escape(k) .. "=" .. escape(v)
	     end
	     return string.sub(s, 2)     -- remove first `&'
      end
end    

--Conta o total de elementos em uma tabela indexada com chaves string,
--pois o operador # não funciona para obter o total de elementos de tais tabelas.
--@param Tabela a ser contato o total de elementos
--@return Retorna o total de elementos da tabela
function count(tb)
   local i = 0
   for k, v in pairs(tb) do
      i = i + 1
   end
   return i
end

---Verifica se uma tabela contém apenas um elemento
--@param tb Tabela ser verificada
--@return Retorna true caso a tabela contenha apenas um elemento.
function hasSingleElement(tb)
   --Para tabelas mais complexas, geradas a partir de um XML este código não funciona, 
   --congelando a aplicação.
   --local k=next(tb)
   --return k~=nil and next(tb,k)==nil

    local i = 0
    for k, v in pairs(tb) do
        i = i + 1
        if i > 1 then
           return false
        end
    end

    return i == 1    
end

--Obtém o primeiro elemento de uma tabela
--@param Tabela de onde deverá ser obtido o primeiro elemento
--@return Retorna o primeiro elemento da tabela
function getFirstElement(tb)
   if type(tb) == "table" then
       --O uso da função next não funciona para pegar o primeiro elemento. Trava aqui 
      --k, v = next(tb)
      --return v
      for k, v in pairs(tb) do
          return v
      end
   else
     return tb
   end
end

--Obtém a primeira chave de uma tabela
--@param Tabela de onde deverá ser obtido o primeiro elemento
--@return Retorna a primeira chave da tabela
function getFirstKey(tb)
   if type(tb) == "table" then
       --O uso da função next não funciona para pegar o primeiro elemento. Trava aqui 
      --k, v = next(tb)
      --return k
      for k, v in pairs(tb) do
          return k
      end
   else
     return tb
   end
end

---Percorre uma tabela recursivamente. Se ela contém apenas um elemento,
--a tabela a qual ele pertence (a externa) é eliminada, ficando apenas a tabela interna,
--passando esta a ser a tabela principal. Repete isto até chegar no item mais interno da tabela.
--Assim, uma tabela como nivel1 = { nivel2 = nivel3 = {desc = "mouse", valor = 99}}
--se transforma em {desc="mouse", valor = 99}
--Outra tabela como nivel1 = { nivel2 = nivel3 = {pais = "Brasil"}}
--se transforma em pais = "Brasil", sem nenhuma tabela.
--@param tb Table lua gerada a partir de código XML
--@return Retorna a nova tabela simplificada. Se dentro de toda a estrutura
--da tabela original só existia um campo com valor, tal valor é retornado
--como uma variável simples.
function simplifyTable(tb)
   local tmp = tb
   ---[[
   while type(tmp) == "table" and hasSingleElement(tmp) do
      tmp = getFirstElement(tmp)
   end
   --]]
   return tmp
end

---Cria uma co-rotina para execução de uma determinada função.
--@param f Função body a ser executada pela co-rotina
--@param ... Parâmetros adicionais que serão passados à função
--body da co-rotina, passada no parâmetro f.
function coroutineCreate(f, ...)
    coroutine.resume(coroutine.create(f), ...)
end
