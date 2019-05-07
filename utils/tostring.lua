-- This script makes tostring convert tables to a
-- representation of their contents.

-- The real tostring:
_tostring = _tostring or tostring

-- Characters that have non-numeric backslash-escaped versions:
local BsChars = {
    ["\a"] = "\\a",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\v"] = "\\v",
    ["\""] = "\\\"",
    ["\\"] = "\\\\"}

-- Is Str an "escapeable" character (a non-printing character other than
-- space, a backslash, or a double quote)?
local function IsEscapeable(Char)
    return string.find(Char, "[^%w%p]") -- Non-alphanumeric, non-punct.
            and Char ~= " " -- Don't count spaces.
            or string.find(Char, '[\\"]') -- A backslash or quote.
end

-- Converts an "escapeable" character (a non-printing character,
-- backslash, or double quote) to its backslash-escaped version; the
-- second argument is used so that numeric character codes can have one
-- or two digits unless three are necessary, which means that the
-- returned value may represent both the character in question and the
-- digit after it:
local function EscapeableToEscaped(Char, FollowingDigit)
    if IsEscapeable(Char) then
        local Format = FollowingDigit == ""
                and "\\%d"
                or "\\%03d" .. FollowingDigit
        return BsChars[Char]
                or string.format(Format, string.byte(Char))
    else
        return Char .. FollowingDigit
    end
end

-- Quotes a string in a Lua- and human-readable way.  (This is a
-- replacement for string.format's %q placeholder, whose result
-- isn't always human readable.)
local function StrToStr(Str)
    -- return '"' .. string.gsub(Str, "(.)(%d?)", EscapeableToEscaped) .. '"'
	return '"' .. Str .. '"'
end

-- Lua keywords:
local Keywords = {["and"] = true, ["break"] = true, ["do"] = true,
    ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true,
    ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true,
    ["true"] = true, ["until"] = true, ["while"] = true}

-- Is Str an identifier?
local function IsIdent(Str)
    return not Keywords[Str] and string.find(Str, "^[%a_][%w_]*$")
end

-- Converts a non-table to a Lua- and human-readable string:
local function ScalarToStr(Val)
    local Ret
    local Type = type(Val)
    if Type == "string" then
        Ret = StrToStr(Val)
    elseif Type == "function" or Type == "userdata" or Type == "thread" then
        -- Punt:
        Ret = "<" .. _tostring(Val) .. ">"
    else
        Ret = _tostring(Val)
    end -- if
    return Ret
end

-- Converts a table to a Lua- and human-readable string.
local function TblToStr(Tbl, Seen)
    Seen = Seen or {}
    local Ret = {}
    if not Seen[Tbl] then
        Seen[Tbl] = true
		local LastArrayKey = 0
		for Key, Val in pairs(Tbl) do
			if type(Key) == "table" then
				Key = "[" .. TblToStr(Key, Seen) .. "]"
            elseif type(Key) == "boolean" then
                Key = "[" .. _tostring(Key) .. "]"
			elseif not IsIdent(Key) then
				if type(Key) == "number" and Key == LastArrayKey + 1 then
					-- Don't mess with Key if it's an array key.
					LastArrayKey = Key
				else
					Key = "[" .. ScalarToStr(Key) .. "]"
				end
			end
			if type(Val) == "table" then
				Val = TblToStr(Val, Seen)
			else
				Val = ScalarToStr(Val)
			end
			Ret[#Ret + 1] =
			(type(Key) == "string"
					and (Key .. " = ") -- Explicit key.
					or "") -- Implicit array key.
					.. Val
		end
		Ret = "{" .. table.concat(Ret, ", ") .. "}"
        Seen[Tbl] = nil
    else
        Ret = "<cycle to " .. _tostring(Tbl) .. ">"
    end
    return Ret
end

-- A replacement for tostring that prints tables in Lua- and
-- human-readable format:
function table.tostring(Val)
    return type(Val) == "table"
            and TblToStr(Val)
            or _tostring(Val)
end

