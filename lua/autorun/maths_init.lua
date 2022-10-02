----------------------------------
-------------- Core --------------
----------------------------------
mathQuestions = {}
mathQuestions.db = "math_points"
mathQuestions.prefix = "[Math] "

mathQuestions.math = {
    ["add"] = {
        ["symbol"] = "+",
        ["type"] = "add",
    },
    ["sub"] = {
        ["symbol"] = "-",
        ["type"] = "sub",
    },
    ["mul"] = {
        ["symbol"] = "×",
        ["type"] = "mul",
    },
    ["div"] = {
        ["symbol"] = "÷",
        ["type"] = "div",
    }
}

----------------------------------
------------- Convars ------------
----------------------------------
CreateConVar("math_add_min", 10, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Min amount to add", 1, 500)
CreateConVar("math_add_max", 100, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Max amount to add", 1, 500)
CreateConVar("math_sub_min", 10, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Min amount to subtract", 1, 500)
CreateConVar("math_sub_max", 100, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Max amount to subtract", 1, 500)
CreateConVar("math_mul_min", 2, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Min amount to multiply", 1, 500)
CreateConVar("math_mul_max", 20, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Max amount to multiply", 1, 500)
CreateConVar("math_div_min", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Min amount to divide", 1, 500)
CreateConVar("math_div_max", 15, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Max amount to divide", 1, 500)

CreateConVar("math_ask_timer", 60, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "The time between questions in seconds", 10, 600)
CreateConVar("math_sub_minus", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "The result of the subtraction will be negative", 0, 1)

----------------------------------
------------ Database ------------
----------------------------------

if SERVER and not sql.TableExists(mathQuestions.db) then
    sql.Query([[CREATE TABLE IF NOT EXISTS ]] .. mathQuestions.db .. [[ ( id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    steamid64 VARCHAR(255) NOT NULL,
    points INTEGER NOT NULL )]])
end


----------------------------------
------------ Hooks --------------
----------------------------------
hook.Add("PlayerInitialSpawn", "mathQuestions_PlayerInitialSpawn", function(ply)
    local row = sql.QueryRow("SELECT * FROM " .. mathQuestions.db .. " WHERE steamid64 = " .. sql.SQLStr(ply:SteamID64()))
    if row then
       sql.Query("UPDATE " .. mathQuestions.db .. " SET name = " .. sql.SQLStr(ply:Nick()) .. " WHERE steamid64 = " .. sql.SQLStr(ply:SteamID64()))
    else
        sql.Query("INSERT INTO " .. mathQuestions.db .. " (name, steamid64, points) VALUES (" .. sql.SQLStr(ply:Nick()) .. ", " .. sql.SQLStr(ply:SteamID64()) .. ", 0)")
    end
end)

----------------------------------
------------ Functions -----------
----------------------------------
if SERVER then

local currentQuestion
local formula 

function mathAddPoints(ply, points)
    local bPoints = tonumber(sql.QueryValue("SELECT points FROM " .. mathQuestions.db .. " WHERE steamid64 = " .. sql.SQLStr(ply:SteamID64())).points)
    sql.Query("UPDATE " .. mathQuestions.db .. " SET points = points + " .. points .. " WHERE steamid64 = " .. sql.SQLStr(ply:SteamID64()))
end

local function tn(v)
    return tonumber(v)
end

function mathKillTimer()
    print("Correct!")
    timer.Stop("mathQuestion")
    hook.Remove("PlayerSay", "mathQuestionAnswered")
    currentQuestion = nil
    formula = nil

    timer.Simple(2, function()
        mathQuestion()
        timer.Create("mathQuestion", GetConVar("math_ask_timer"):GetInt(), 0, mathQuestion)
    end)
end

function mathGetEquation()
    local mathType = table.Random(mathQuestions.math)
    local a = math.random(GetConVar("math_" .. mathType.type .. "_min"):GetInt(), GetConVar("math_" .. mathType.type .. "_max"):GetInt())
    local b = math.random(GetConVar("math_" .. mathType.type .. "_min"):GetInt(), GetConVar("math_" .. mathType.type .. "_max"):GetInt())

    local mType = mathType.type

    if mType == "add" then
        answer = a + b
    elseif mType == "sub" then
        if GetConVar("math_sub_minus"):GetBool() then
            answer = a - b
        else
            answer = math.max(a, b) - math.min(a, b)
        end
    elseif mType == "mul" then
        answer = a * b
    elseif mType == "div" then
        answer = a
        a = a * b
    end

    return {
        ["1"] = mathType.type,
        ["2"] = mathType.symbol,
        ["3"] = a,
        ["4"] = b,
        ["5"] = answer
    }
end

function mathQuestion()

    if currentQuestion == nil then
        currentQuestion = mathGetEquation()
        hook.Call("math_QuestionCreated", nil, 1)

        hook.Add("PlayerSay", "mathQuestionAnswered", function(ply, text)
            if ply:IsPlayer() then
                if tostring(text) == tostring(currentQuestion["5"]) then
                    hook.Call("math_QuestionAnswered", nil, ply)
                    timer.Simple(0.01, function()
                        
                        mathAddPoints(ply, 1)

                        for _, sply in ipairs(player.GetAll()) do
                            if ply != sply then
                                sply:ChatPrint("[Math] " .. ply:Nick() .. " Answered first!")
                            else
                                sply:ChatPrint("[Math] Correct!")
                            end
                        end

                        mathKillTimer()
                        hook.Remove("PlayerSay", "mathQuestionAnswered")
                    end)
                end
            end
        end)
    end

    local mType = currentQuestion["1"]
    if mType == "add" or "sub" or "mul"  then
        formula = currentQuestion["3"] .. " " .. currentQuestion["2"] .. " " .. currentQuestion["4"] .. " = "
    elseif mType == "div" then
        formula = (tn(currentQuestion["3"]) * tn(currentQuestion["4"])) .. " " .. currentQuestion["2"] .. " " .. currentQuestion["4"] .. " = "
    end

    for _, ply in ipairs(player.GetAll()) do
        ply:ChatPrint("[Math] Question: " .. formula .. "?")
    end

    if SERVER then
        print("[Math] Question: " .. formula .. currentQuestion["5"])
    end
end

timer.Create("mathQuestion", GetConVar("math_ask_timer"):GetInt(), 0, mathQuestion)

end