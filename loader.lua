repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

local clone = cloneref or function(x) return x end
local Players = clone(game:GetService("Players"))
local HttpService = clone(game:GetService("HttpService"))
local LocalPlayer = Players.LocalPlayer

local API = "https://spacehubv2.onrender.com/v1/script"
local MAX_ATTEMPTS = 3
local KICK_ON_NETWORK_ERROR = false

local env = getgenv()
local KEY = env.Key or env.SpaceKey

local function kick(reason)
    local msg = "[Space Hub] " .. tostring(reason)
    warn(msg)
    pcall(function()
        LocalPlayer:Kick(msg)
    end)
    task.wait(2)
    pcall(function()
        game:Shutdown()
    end)
end

if type(KEY) ~= "string" or KEY:gsub("%s", "") == "" then
    return kick("Key ausente ou vazia. Acesso negado.")
end

local req = request or http_request
if not req and syn then
    req = syn.request
end
if type(req) ~= "function" then
    return kick("Executor sem suporte a HTTP Request.")
end

local function getHwid()
    if type(gethwid) == "function" then
        local ok, result = pcall(gethwid)
        if ok and type(result) == "string" and #result >= 8 then
            return result
        end
    end
    local ok, result = pcall(function()
        return clone(game:GetService("RbxAnalyticsService")):GetClientId()
    end)
    if ok and type(result) == "string" and #result >= 8 then
        return result
    end
    return nil
end

local hwid = getHwid()
if not hwid then
    return kick("Nao foi possivel obter HWID. Acesso negado.")
end

local payload = HttpService:JSONEncode({ key = KEY, hwid = hwid })

local function validate()
    for attempt = 1, MAX_ATTEMPTS do
        local ok, res = pcall(req, {
            Url = API,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload,
        })
        if ok and type(res) == "table" then
            local status = res.StatusCode or res.Status or 0
            local body = res.Body or ""
            if status == 200 or (status >= 400 and status < 500) then
                return status, body
            end
        end
        if attempt < MAX_ATTEMPTS then
            task.wait(2 * attempt)
        end
    end
    return nil, nil
end

local status, body = validate()

if status == nil then
    if KICK_ON_NETWORK_ERROR then
        return kick("Servidor de licenca indisponivel.")
    end
    return warn("[Space Hub] Servidor de licenca indisponivel. Tente novamente.")
end

if status == 429 then
    return warn("[Space Hub] Muitas tentativas. Aguarde um minuto.")
end

if status ~= 200 then
    local reason = "Key invalida."
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if ok and type(data) == "table" and type(data.error) == "string" then
        reason = data.error
    end
    return kick(reason)
end

local chunk, compileErr = loadstring(body)
if type(chunk) ~= "function" then
    return warn("[Space Hub] Erro de compilacao: " .. tostring(compileErr))
end

local executed, err = xpcall(chunk, function(e)
    warn("[Space Hub] Stack Trace:")
    warn(debug.traceback(tostring(e), 2))
    return e
end)

if not executed then
    warn("[Space Hub] Erro de execucao: " .. tostring(err))
end
