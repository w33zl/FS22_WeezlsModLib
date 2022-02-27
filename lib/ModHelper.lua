--[[

ModHelper (Weezls Mod Lib for FS22) - Simplifies the creation of script based mods for FS22

This utility class acts as a wrapper for Farming Simulator script based mods. It hels with setting up the mod up and 
acting as a "bootstrapper" for the main mod class/table. It also add additional utility functions for sourcing additonal files, 
manage user settings, assist debugging etc.

See ModHelper.md (search my GitHub page for it since Giants won't allow "links" in the scripts) for documentation and more details.

Author:     w33zl
Version:    2.1.0
Modified:   2021-12-08

Facebook:           https://www.facebook.com/w33zl
Ko-fi:              https://ko-fi.com/w33zl
Patreon:            https://www.patreon.com/wzlmodding
Github:             https://github.com/w33zl

Changelog:
v2.0        FS22 version
v1.0        Initial public release

License:    CC BY-NC-SA 4.0
This license allows reusers to distribute, remix, adapt, and build upon the material in any medium or 
format for noncommercial purposes only, and only so long as attribution is given to the creator.
If you remix, adapt, or build upon the material, you must license the modified material under identical terms. 

]]



--[[

USAGE:

YourModName = Mod:init()

YourModName:enableDebugMode() -- To enable debug mode

-- Events
function YourModName:beforeLoadMap() end -- Super early event, caution!
function YourModName:loadMapFinished() end -- Directly after the map has finished loading
function YourModName:loadMap(filename) end -- Actually "load mod"
function YourModName:beforeStartMission() end -- When user selects "Start" (but as early as possible in that event chain)
function YourModName:startMission() end -- When user selects "Start"
function YourModName:update(dt) end -- Looped as long game is running

]]

-- This will create the "Mod" base class (and effectively reset any previous references to other mods) 
Mod = {

    debugMode = false,

    printInternal = function(self, category, message, ...)
        message = (message ~= nil and message:format(...)) or ""
        if category ~= nil and category ~= "" then
            category = string.format(" %s:", category)
        else
            category = ""
        end
        print(string.format("[%s]%s %s", self.title, category, tostring(message)))
    end,

    printDebug = function(self, message, ...)
        if self.debugMode == true then
            self:printInternal("DEBUG", message, ...)
        end
    end,

    printDebugVar = function(self, name, variable)
        if self.debugMode ~= true then
            return
        end

        -- local tt1 = (val or "")
        local valType = type(variable)
    
        if valType == "string" then
            variable = string.format( "'%s'", variable )
        end
    
        local text = string.format( "%s=%s [@%s]", name, tostring(variable), valType )
        self:printInternal("DBGVAR", text)
    end,
    
    printWarning = function(self, message, ...)
        self:printInternal("Warning", message, ...)
    end,

    printError = function(self, message, ...)
        self:printInternal("Error", message, ...)
    end,

    getIsMultiplayer = function(self) return g_currentMission.missionDynamicInfo.isMultiplayer end,
    getIsServer = function(self) return g_currentMission.getIsServer() end,
    getIsClient = function(self) return g_currentMission.getIsClient() end,
    getIsDedicatedServer = function(self) return not self:getIsClient() and self:getIsServer() end, --g_dedicatedServer
    getIsMasterUser = function(self) return g_currentMission.isMasterUser end,
    getHasFarmAdminAccess = function(self) return g_currentMission:getHasPlayerPermission("farmManager") end,
    getIsValidFarmManager = function(self) return g_currentMission.player ~= nil and self:getHasFarmAdminAccess() and g_currentMission.player.farmId ~= FarmManager.SPECTATOR_FARM_ID end,
}
Mod_MT = {
}

SubModule = {
    printInfo = function(message, ...) Mod:printInfo(message, ...) end,
    printDebug = function(message, ...) Mod:printDebug(message) end,
    printDebugVar = function(name, variable) Mod:printDebugVar(name, variable) end,
    printWarning = function(message, ...) Mod:printWarning(message) end,
    printError = function(message, ...) Mod:printError(message) end,
    parent = nil,
}
SubModule_MT = {
}


-- Set initial values for the global Mod object/"class"
Mod.dir = g_currentModDirectory;
Mod.name = g_currentModName
Mod.mod = g_modManager:getModByName(Mod.name)
Mod.env = getfenv()
Mod.globalEnv = getfenv(0)

local modDescXML = loadXMLFile("modDesc", Mod.dir .. "modDesc.xml");
Mod.title = getXMLString(modDescXML, "modDesc.title.en");
Mod.author = getXMLString(modDescXML, "modDesc.author");
Mod.version = getXMLString(modDescXML, "modDesc.version");
-- Mod.author = Mod.mod.author
-- Mod.version = Mod.mod.version
delete(modDescXML);

function Mod:printInfo(message, ...)
    self:printInternal("", message, ...)
end


-- Local aliases for convinience
local function printInfo(message) Mod:printInfo(message) end
local function printDebug(message) Mod:printDebug(message) end
local function printDebugVar(name, variable) Mod:printDebugVar(name, variable) end
local function printWarning(message) Mod:printWarning(message) end
local function printError(message) Mod:printError(message) end


-- Helper functions
local function validateParam(value, typeName, message)
    local failed = false
    failed = failed or (value == nil)
    failed = failed or (typeName ~= nil and type(value) ~= typeName)
    failed = failed or (type(value) == string and value == "")

    if failed then print(message) end

    return not failed
end

local ModSettings = {};
ModSettings.__index = ModSettings;

function ModSettings:new(mod)
    local newModSettings = {};
    setmetatable(newModSettings, self);
    self.__index = self;
    newModSettings.__mod = mod;
    return newModSettings;
end
function ModSettings:init(name, defaultSettingsFileName, userSettingsFileName)
    if not validateParam(name, "string", "Parameter 'name' (#1) is mandatory and must contain a non-empty string") then
        return;
    end

    if defaultSettingsFileName == nil or type(defaultSettingsFileName) ~= "string" then 
        self.__mod.printError("Parameter 'defaultSettingsFileName' (#2) is mandatory and must contain a filename");
        return;
    end

    --TODO: change to this: g_currentModSettingsDirectory == /Documents/My Games/FarmingSimulator2022/modSettings/MOD_NAME/
    local modSettingsDir = getUserProfileAppPath() .. "modsSettings"

    self._config = {
        xmlNodeName = name,
        modSettingsDir = modSettingsDir,
        defaultSettingsFileName = defaultSettingsFileName,
        defaultSettingsPath = self.__mod.dir .. defaultSettingsFileName,
        userSettingsFileName = userSettingsFileName,
        userSettingsPath = modSettingsDir .. "/" .. userSettingsFileName,
    }


    return self;
end
function ModSettings:load(callback)
    if not validateParam(callback, "function", "Parameter 'callback' (#1) is mandatory and must contain a valid callback function") then
        return;
    end

    local defaultSettingsFile = self._config.defaultSettingsPath;
    local userSettingsFile = self._config.userSettingsPath;
    local xmlNodeName = self._config.xmlNodeName or "settings"

    if defaultSettingsFile == "" or userSettingsFile == "" then
        self.__mod.printError("Cannot load settings, neither a user settings nor a default settings file was supplied. Nothing to read settings from.");
        return;
    end

    local function executeXmlReader(xmlNodeName, fileName, callback)
        local xmlFile = loadXMLFile(xmlNodeName, fileName)

        if xmlFile == nil then
            printError("Failed to open/read settings file '" .. fileName .. "'!")
            return
        end

        local xmlReader = {
            xmlFile = xmlFile,
            xmlNodeName = xmlNodeName,
            
            getKey = function(self, categoryName, valueName)
                local xmlKey = self.xmlNodeName

                
                if categoryName ~= nil and categoryName ~= "" then 
                    xmlKey = xmlKey .. "." .. categoryName
                end

                xmlKey = xmlKey .. "." .. valueName
                
                return xmlKey
            end,

            readBool = function(self, categoryName, valueName, defaultValue)
                return Utils.getNoNil(getXMLBool(self.xmlFile, self:getKey(categoryName, valueName)), defaultValue or false)
            end,
            readFloat = function(self, categoryName, valueName, defaultValue)
                return Utils.getNoNil(getXMLFloat(self.xmlFile, self:getKey(categoryName, valueName)), defaultValue or 0.0)
            end,
            readString = function(self, categoryName, valueName, defaultValue)
                return Utils.getNoNil(getXMLString(self.xmlFile, self:getKey(categoryName, valueName)), defaultValue or "")
            end,

        }
        callback(xmlReader);
    end

    if fileExists(defaultSettingsFile) then
        executeXmlReader(xmlNodeName, defaultSettingsFile, callback);
    end

    if fileExists(userSettingsFile) then
        executeXmlReader(xmlNodeName, userSettingsFile, callback);
    end

end


function ModSettings:save(callback)
    if not validateParam(callback, "function", "Parameter 'callback' (#1) is mandatory and must contain a valid callback function") then
        return;
    end

    local userSettingsFile = self._config.userSettingsPath;
    local xmlNodeName = self._config.xmlNodeName or "settings"

    if userSettingsFile == "" then
        printError("Missing filename for user settings, cannot save mod settings.");
        return;
    end

    if not fileExists(userSettingsFile) then
        createFolder(self._config.modSettingsDir)
    end

    local function executeXmlWriter(xmlNodeName, fileName, callback)
        local xmlFile = createXMLFile(xmlNodeName, fileName, xmlNodeName)

        if xmlFile == nil then
            printError("Failed to create/write to settings file '" .. fileName .. "'!")
            return
        end

        local xmlWriter = {
            xmlFile = xmlFile,
            xmlNodeName = xmlNodeName,
            
            getKey = function(self, categoryName, valueName)
                local xmlKey = self.xmlNodeName

                
                if categoryName ~= nil and categoryName ~= "" then 
                    xmlKey = xmlKey .. "." .. categoryName
                end

                xmlKey = xmlKey .. "." .. valueName
                
                return xmlKey
            end,

            saveBool = function(self, categoryName, valueName, value)
                return setXMLBool(self.xmlFile, self:getKey(categoryName, valueName), Utils.getNoNil(value, false))
            end,

            saveFloat = function(self, categoryName, valueName, value)
                return setXMLFloat(self.xmlFile, self:getKey(categoryName, valueName), Utils.getNoNil(value, 0.0))
            end,

            saveString = function(self, categoryName, valueName, value)
                return setXMLString(self.xmlFile, self:getKey(categoryName, valueName), Utils.getNoNil(value, ""))
            end,

        }
        callback(xmlWriter);

        saveXMLFile(xmlFile)
        delete(xmlFile)
    end

    executeXmlWriter(xmlNodeName, userSettingsFile, callback);

    return self
end


function Mod:source(file)
    source(self.dir .. file);
    return self; -- Return self to keep the "chain" (fluent)
end--function

function Mod:trySource(file, silentFail)
    local filename = self.dir .. file

    silentFail = silentFail or false

    if fileExists(filename) then
        source(filename);
    elseif not silentFail then
        self:printWarning("Failed to load sourcefile '" .. filename .. "'")
    end
    return self; -- Return self to keep the "chain" (fluent)
end--function

function Mod:init()
    local newMod = self:new();

    addModEventListener(newMod);

    print(string.format("Load mod: %s (v%s) by %s", newMod.title, newMod.version, newMod.author))

    return newMod;
end--function

function Mod:enableDebugMode()
    self.debugMode = true

    self:printDebug("Debug mode enabled")

    return self; -- Return self to keep the "chain" (fluent)
end--function

function Mod:loadSound(name, fileName)
    local newSound = createSample(name)
    loadSample(newSound, self.dir .. fileName, false)
    return newSound
end

function Mod:new()
    local newMod = {}

    setmetatable(newMod, self)
    self.__index = self

    newMod.dir = g_currentModDirectory;
    newMod.name = g_currentModName
    newMod.settings = ModSettings:new(newMod);


    local modDescXML = loadXMLFile("modDesc", newMod.dir .. "modDesc.xml");
    newMod.title = getXMLString(modDescXML, "modDesc.title.en");
    newMod.author = getXMLString(modDescXML, "modDesc.author");
    newMod.version = getXMLString(modDescXML, "modDesc.version");
    delete(modDescXML);

    -- newMod.startMission = function() end -- Dummy function/event

    -- FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, function(...)
    --     newMod.startMission(newMod, ...)
    -- end);

    FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, function(baseMission, ...) 
        if newMod.startMission ~= nil and type(newMod.startMission) == "function" then
            newMod:startMission(baseMission, ...)
        end
    end)

    FSBaseMission.onStartMission = Utils.prependedFunction(FSBaseMission.onStartMission, function(baseMission, ...) 
        if newMod.beforeStartMission ~= nil and type(newMod.beforeStartMission) == "function" then
            newMod:beforeStartMission(baseMission, ...)
        end
    end)

    -- Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(mission00, ...) 
    --     if newMod.missionLoaded ~= nil and type(newMod.missionLoaded) == "function" then
    --         newMod:missionLoaded(mission00, ...)
    --     end
    -- end)

    FSBaseMission.initialize = Utils.appendedFunction(FSBaseMission.initialize, function(baseMission, ...) 
        if newMod.initMission ~= nil and type(newMod.initMission) == "function" then
            newMod:initMission(baseMission, ...)
        end
    end)

    FSBaseMission.loadMap = Utils.prependedFunction(FSBaseMission.loadMap, function(baseMission, ...) 
        if newMod.beforeLoadMap ~= nil and type(newMod.beforeLoadMap) == "function" then
            newMod:beforeLoadMap(baseMission, ...)
        end
    end)

    FSBaseMission.loadMap = Utils.appendedFunction(FSBaseMission.loadMap, function(baseMission, ...) 
        if newMod.afterLoadMap ~= nil and type(newMod.afterLoadMap) == "function" then
            newMod:afterLoadMap(baseMission, ...)
        end
    end)


    FSBaseMission.loadMapFinished = Utils.prependedFunction(FSBaseMission.loadMapFinished, function(baseMission, ...) 
        if newMod.loadMapFinished ~= nil and type(newMod.loadMapFinished) == "function" then
            newMod:loadMapFinished(baseMission, ...)
        end
    end)

    FSBaseMission.loadMapFinished = Utils.appendedFunction(FSBaseMission.loadMapFinished, function(baseMission, ...) 
        if newMod.afterLoadMapFinished ~= nil and type(newMod.afterLoadMapFinished) == "function" then
            newMod:afterLoadMapFinished(baseMission, ...)
        end
    end)

    -- newMod:enableDebugMode()
    

    -- newMod:trySource("lib/DebugHelper.lua")

    -- printDebugVar("DebugHelper", DebugHelper)

    -- newMod:printInfo(tostring(DebugHelper))

    -- if DebugHelper ~= nil then
    --     newMod:printInfo("Okej")
    --     newMod:enableDebugMode()
    --     -- newMod.__debugHelper = DebugHelper:init(newMod.name, newMod.dir)
    --     DebugHelper:enableDebugMode(newMod.title)
    -- end

    -- FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, function(baseMission, ...) 
    --     if newMod.unloadMod ~= nil and type(newMod.unloadMod) == "function" then
    --         newMod:unloadMod(baseMission, ...)
    --     end
    -- end)

    return newMod;
end--function

function SubModule:new(parent, table)
    local newSubModule = table or {}

    setmetatable(newSubModule, self)
    self.__index = self
    newSubModule.parent = parent
    return newSubModule
end


function Mod:newSubModule(table)
    return SubModule:new(self, table)
end



--- Check if the third party mod is loaded
---@param modName string The name of the mod/zip-file
---@param envName string (Optional)The environment name to check for
function Mod:getIsModActive(modName, envName)
    -- local andersonDlc = getfenv(0)["pdlc_andersonPack"]
    -- if andersonDlc ~= nil and g_modIsLoaded["pdlc_andersonPack"] then

    if modName == nil and envName == nil then
        return false
    end

    local testMod = g_modManager:getModByName(modName)
    if testMod == nil then
        return false
    end

    -- local isModMissing = true -- Do an inverted check
    local modNameCheck = false
    local envCheck = false


    modNameCheck = (modName == nil) or (g_modIsLoaded[modName] ~= nil)
    envCheck = (envName == nil) or (getfenv(0)[envName] ~= nil)

    return modNameCheck and envCheck

    -- if modName ~= nil then
    --     modNameCheck = g_modIsLoaded[modName]

    --     isModMissing = isModMissing and (modNameCheck == false)
    -- end

    -- if envName ~= nil then
    --     envCheck = getfenv(0)[envName] ~= nil

    --     wasModFound = wasModFound or envCheck
    --     isModMissing = isModMissing and (modNameCheck == false)
    -- end

    -- return not isModMissing
end

function Mod:getIsSeasonsActive()
    --TODO: fix check basegame option
    return false -- Mod:getIsModActive(nil, "g_seasons")
end

function Mod:getIsMaizePlusActive()
    -- return Mod:getIsModActive(nil, "??")FS19_MaizePlus  FS19_MaizePlus_forageExtension
    return Mod:getIsModActive("FS22_MaizePlus")
end

function Mod:getIsMaizePlusForageActive()
    return Mod:getIsModActive("FS22_MaizePlus_forageExtension")
end

-- function Mod:getIsMaizePlusForageActive()
--     return Mod:getIsModActive("FS19_MaizePlus_forageExtension")
-- end

function Mod:getIsMaizePlusAnimalFoodAdditionsActive()
    return Mod:getIsModActive("FS22_maizePlus_animalFoodAdditions")
    -- return g_modManager:getModByName("FS19_maizePlus_animalFoodAdditions") ~= nil and g_modIsLoaded["FS19_maizePlus_animalFoodAdditions"]
end

function Mod:getIsStrawHarvestActive()
    return Mod:getIsModActive("FS22_addon_strawHarvest")
end

