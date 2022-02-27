--[[

DebugHelper (Weezls Mod Lib for FS22) - A extension "class" that improves the LogHelper by adding some additional features specifically for debugging

Author:     w33zl
Version:    1.0
Modified:   2022-01-16

Facebook:           https://www.facebook.com/w33zl
Ko-fi:              https://ko-fi.com/w33zl
Patreon:            https://www.patreon.com/wzlmodding
Github:             https://github.com/w33zl

Changelog:
v1.0        Initial public release

License:    CC BY-NC-SA 4.0
This license allows reusers to distribute, remix, adapt, and build upon the material in any medium or 
format for noncommercial purposes only, and only so long as attribution is given to the creator.
If you remix, adapt, or build upon the material, you must license the modified material under identical terms. 

]]

DebugHelper = {
    dumpTable = function(self, tableName, tableObject, maxDepth)
        maxDepth = maxDepth or 2
        DebugUtil.printTableRecursively(tableObject, tableName .. ":: ", 0, maxDepth)
    end,

    decodeTable = function(self, tableName, tableObject, skipFunctions, unwrapTables)
        if Log == nil then return end
        if tableObject == nil then
            Log:warning("Table '%s' was not found", tableName)
            return 
        end

        skipFunctions = skipFunctions or false

        local function logIt(index, value)
            local typeName = type(value)
            if typeName == "string" then
                value = "\"" .. value .. "\""
            elseif skipFunctions and typeName == "function" then
                return -- Skip function
            else
                value = tostring(value)
            end
            Log:print("TABLE", "%s%s = %s [%s]", tableName, index, value, typeName)
        end
        
        for index, value in ipairs(tableObject) do
            logIt("[" .. tostring(index) .. "]", value)
        end

        for key, value in pairs(tableObject) do
            logIt("." .. key, value)
        end
    end,

    traceLog = function(self, message, ...)
        if Log == nil then return end
        Log.traceIndex = (Log.traceIndex or 999) + 1
        Log:print("TRACE-" .. tostring(Log.traceIndex), message, ...)
    end,

    inject = function(self, log)
        log.table = self.dumpTable
        log.tableX = self.decodeTable
        log.trace = self.traceLog
    end,

    ---Intercepts a event/function call on any object and prints the input parameters
    ---@param target table The target object where to intercept a function
    ---@param functionName string Name of the function to intercept
    interceptDecode = function(self, target, functionName)
        local prefix = functionName

        local logger

        if Log ~= nil then
            logger = Log
        else
            logger = { 
                debug = function(self, message, ...) 
                    Logging.info("[DebugHelper] " .. message, ...)
                end
            }
        end

        local function internalDecoder(self, superFunc, ...)
            local a = { ... }
            print("")
            logger:debug("### %s DECODER: Args=%d", prefix:upper(), #a)
            for index, value in ipairs(a) do
                logger:debug("%s.param[%d]=%s [%s]", prefix, index, tostring(value), type(value))
            end
        
            for index, value in ipairs(a) do
                if type(value) == "table" then
                    DebugUtil.printTableRecursively(value, prefix .. ".param[" .. tostring(index) .. "]:: ", 0, 1 )
                end
            end
        
            local returnValue = superFunc(self, ...)
            logger:debug("<< RETURN=%s [%s]", tostring(returnValue), type(returnValue))
            -- if type(returnValue) == "table" then
            --     DebugUtil.printTableRecursively(returnValue, "RETURN:: ", 0, 1)
            -- else
            --     Logging.extInfo("RETURN=%s [%s]", tostring(returnValue), type(returnValue))
            -- end
            
            return returnValue
        end
            
        
        target[functionName] = Utils.overwrittenFunction(target[functionName], internalDecoder)
    end
    
}