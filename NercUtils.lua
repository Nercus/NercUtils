-- -------------------------------------------------------------------------- --
-- Title: NercUtils
-- Description: A collection of utility functions for WoW addons as an Ace3 module
-- Version: 1.0.0 (05/2025)
-- Author: Nerc
-- License: MIT
-- -------------------------------------------------------------------------- --


local MAJOR, MINOR = "NercUtils", 1
assert(LibStub, MAJOR .. " requires LibStub")

local NercUtils = LibStub:NewLibrary(MAJOR, MINOR)
if not NercUtils then return end


_G.NercLib = NercLib


-- -------------------------------------------------------------------------- --
--                                 Persistence                                --
-- -------------------------------------------------------------------------- --
function NercUtils:InitDB()
  if self.db then return end
  local addon = self.name
  self.defaults = self.defaults or {}
  self.db = _G[addon .. "DB"]
  if not self.db then
    self.db = {}
    _G[addon .. "DB"] = self.db
  end
end

function NercUtils:GetDefault(...)
  local arg = { ... }
  local currentTable = self.defaults
  for index, key in ipairs(arg) do
    if index == #arg then -- last key
      if currentTable[key] == nil then
        assert(false, "Key does not exist in DEFAULTS table: " .. table.concat(arg, ".", 1, #arg - 1))
      end
      return currentTable[key]
    end
    if currentTable[key] == nil then
      assert(false, "Key does not exist in DEFAULTS table: " .. table.concat(arg, ".", 1, #arg - 1))
    end
    currentTable = currentTable[key] --[[@as table]]
  end
  error("DEFAULT table is empty")
end

function NercUtils:SetDefault(...)
  -- move all arguments into a table
  local arg = { ... }
  local value = arg[#arg] -- last argument is the value

  -- remove the last argument from the tables
  arg[#arg] = nil
  -- iterate table and create sub-tables if needed and on last iteration set the value
  local currentTable = self.defaults -- start at the root
  for index, key in ipairs(arg) do
    if index == #arg then
      break
    end
    if not currentTable[key] then
      currentTable[key] = {}
    end
    currentTable = currentTable[key]
  end
  if type(currentTable) ~= "table" then
    return
  end
  -- arg[#arg] is the last key
  currentTable[arg[#arg]] = value
end

function NercUtils:SetVar(...)
  if not self.db then
    self:InitDB()
  end
  -- move all arguments into a table
  local arg = { ... }
  local value = arg[#arg] -- last argument is the value

  -- remove the last argument from the tables
  arg[#arg] = nil
  -- iterate table and create sub-tables if needed and on last iteration set the value

  local currentTable = self.db -- start at the root
  for index, key in ipairs(arg) do
    if index == #arg then
      break
    end
    if not currentTable[key] then
      currentTable[key] = {}
    end
    currentTable = currentTable[key]
  end
  if type(currentTable) ~= "table" then
    return
  end
  -- arg[#arg] is the last key
  currentTable[arg[#arg]] = value ---@type boolean | number | string | table
end

function NercUtils:GetVar(...)
  if not self.db then
    self:InitDB()
  end
  -- move all arguments into a table
  local arg = { ... }


  local dbTable = self.db
  for index, key in ipairs(arg) do
    if index == #arg then
      return dbTable[key]
    end
    if not dbTable[key] then
      return nil
    end
    dbTable = dbTable[key]
  end
  error("Error receiving value from saved variables")
end

function NercUtils:DeleteVar(...)
  if not self.db then
    self:InitDB()
  end
  -- move all arguments into a table
  local arg = { ... }
  local dbTable = self.db
  for index, key in ipairs(arg) do
    if index == #arg then
      dbTable[key] = nil ---@type nil
    end
    if not dbTable[key] then
      return
    end
    -- this annotation is not fully correct as we might already have traversed into a sub-table
    dbTable = dbTable[key]
  end
end

function NercUtils:MigrateVar(prevKeys, newKeys)
  local prevValue = self:GetVar(type(prevKeys) == "table" and unpack(prevKeys) or prevKeys --[[@as string]])
  if prevValue ~= nil then
    self:SetVar(type(newKeys) == "table" and unpack(newKeys) or newKeys, prevValue)
    self:DeleteVar(type(prevKeys) == "table" and unpack(prevKeys) or prevKeys --[[@as string]])
  end
end

-- -------------------------------------------------------------------------- --
--                                    Debug                                   --
-- -------------------------------------------------------------------------- --


local function AddDebugMenu(addon)
  local devAddonList = {
    "!!NoWarnings",
    "!BugGrabber",
    "BugSack",
    "TextureAtlasViewer",
    "DevTool",
  }
  local preFiredQueue = {}
  local playerLoginFired = false

  function addon:Debug(...)
    --@do-not-package@
    local args = ...
    if (playerLoginFired == false) then
      table.insert(preFiredQueue, { args })
      return
    end
    if (C_AddOns.IsAddOnLoaded("DevTool") == false) then
      C_Timer.After(1, function()
        self:Debug(args)
      end)
      return
    end
    local DevToolFrame = _G["DevToolFrame"] ---@type Frame
    local DevTool = _G["DevTool"] ---@type any // don't want to type all of DevTool
    DevTool:AddData(args)
    if not DevToolFrame then
      return
    end
    if not DevToolFrame:IsShown() then
      DevTool:ToggleUI()
      C_Timer.After(1, function()
        self:Debug(args)
      end)
      return
    end
    --@end-do-not-package@
  end

  function addon:AddAddonToWhitelist(addonName)
    --@do-not-package@
    assert(type(addonName) == "string", "Addon name must be a string")
    assert(C_AddOns.GetAddOnInfo(addonName), "Addon must exist")
    table.insert(devAddonList, addonName)
    --@end-do-not-package@
  end

  function addon:AddDebugCustomDebugAction(menuTemplate)
    assert(type(menuTemplate) == "table", "Menu template not provided or not a table")
    table.insert(self.debugMenuTemplate, menuTemplate)
  end

  local tickAtlas = "UI-QuestTracker-Tracker-Check"
  local crossAtlas = "UI-QuestTracker-Objective-Fail"
  local pausedAtlas = "CreditsScreen-Assets-Buttons-Pause"


  table.insert(devAddonList, addon.name)
  local function loadDevAddons(isDev)
    if not isDev then
      local loadedAddons = addon:GetVar("loadedAddons") or {}
      if #loadedAddons == 0 then
        C_AddOns.EnableAllAddOns()
        return
      end
      for i = 1, #loadedAddons do
        local name = loadedAddons[i] ---@type string
        C_AddOns.EnableAddOn(name)
      end
    else
      C_AddOns.DisableAllAddOns()
      for i = 1, #devAddonList do
        local name = devAddonList[i]
        C_AddOns.EnableAddOn(name)
      end
    end
  end


  local function setDevMode()
    local devModeEnabled = addon:GetVar("devMode")
    if (devModeEnabled) then
      addon:SetVar("devMode", false)
    else
      addon:SetVar("devMode", true)
    end
    loadDevAddons(not devModeEnabled)
    C_UI.Reload()
  end
  addon:AddSlashCommand("dev", setDevMode, "Toggle dev mode")

  ---@enum DevModeKeysToKeep
  local keysToKeep = {
    "devMode",
    "loadedAddons",
    "version",
  }

  ---@diagnostic disable-next-line: no-unknown
  StaticPopupDialogs[addon.name .. "RESETSAVEDVARS_POPUP"] = {
    text = "Are you sure you want to reset all saved variables?",
    button1 = "Yes",
    button2 = "No",
    onAccept = function()
      local DB = _G[addon.name .. "DB"]
      if not DB then
        DB = {}
        _G[addon.name .. "DB"] = DB
      end
      local DBToKeep = {}
      for i = 1, #keysToKeep do
        local key = keysToKeep[i] --[[@as DevModeKeysToKeep]]
        DBToKeep[key] = DB[key]
      end
      DB = DBToKeep
      C_UI.Reload()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }

  local f = CreateFrame("Frame", nil, UIParent, "DefaultPanelTemplate")
  local f = CreateFrame("Frame", "NercUtilsDebugMenuFrame", UIParent, "DefaultPanelTemplate")
  f:SetSize(640, 130)
  f:SetFrameStrata("HIGH")
  f:SetFrameLevel(100)
  f:SetPropagateKeyboardInput(true)
  f:Hide()
  f:SetPoint("BOTTOM", 0, 5)

  local title = f:CreateFontString("$parentTitle", "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -30)
  title:SetText("Press 1 to reload UI")

  local button1 = CreateFrame("Button", nil, f, "SharedButtonLargeTemplate")
  button1:SetSize(150, 40)
  button1:SetPoint("LEFT", 15, 0)
  button1:SetText("Open Debug Menu")
  f.debugMenuButton = button1

  local button2 = CreateFrame("Button", nil, f, "SharedButtonLargeTemplate")
  button2:SetSize(150, 40)
  button2:SetPoint("LEFT", button1, "RIGHT", 5, 0)
  button2:SetText("Reset Saved Vars")
  f.resetVarsButton = button2

  local button3 = CreateFrame("Button", nil, f, "SharedButtonLargeTemplate")
  button3:SetSize(150, 40)
  button3:SetPoint("LEFT", button2, "RIGHT", 5, 0)
  button3:SetText("Debug Addon")
  f.debugAddonButton = button3

  local button4 = CreateFrame("Button", nil, f, "SharedButtonLargeTemplate")
  button4:SetSize(150, 40)
  button4:SetPoint("LEFT", button3, "RIGHT", 5, 0)
  button4:SetText("Exit Dev Mode")
  f.exitDevButton = button4

  local statusbar = CreateFrame("StatusBar", nil, f)
  statusbar:SetSize(420, 27)
  statusbar:SetPoint("BOTTOM", 0, 10)
  statusbar:SetStatusBarTexture("Interface/AddOns/YourAddon/delves-dashboard-bar-fill") -- Replace with actual path or atlas
  statusbar:SetMinMaxValues(0, 100)
  statusbar:SetValue(0)
  f.testStatusbar = statusbar

  local border = statusbar:CreateTexture(nil, "BORDER")
  border:SetAtlas("delves-dashboard-bar-border")
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)

  local sbText = statusbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sbText:SetPoint("CENTER", 0, 1)
  sbText:SetText("Test StatusBar")
  statusbar.text = sbText

  function statusbar:SetStatusbarValue(min, max, value)
    self:SetMinMaxValues(min, max)
    self:SetValue(value)
    self.text:SetText(string.format("Tests completed: %d/%d", value, max))
  end

  local runTestsButton = CreateFrame("Button", nil, statusbar)
  runTestsButton:SetSize(30, 30)
  runTestsButton:SetPoint("LEFT", statusbar, "RIGHT", 5, 0)
  runTestsButton:SetNormalTexture("Interface/AddOns/YourAddon/CreditsScreen-Assets-Buttons-Play") -- Replace with actual path or atlas
  statusbar.runTestsButton = runTestsButton

  f:RegisterEvent("ADDON_LOADED")
  f:RegisterEvent("PLAYER_LOGIN")

  f:SetScript("OnKeyDown", function(_, key)
    if key == "1" then
      C_UI.Reload()
    end
  end)


  f.debugMenuButton:SetScript("OnClick", function(self)
    if not addon.debugMenuTemplate or #addon.debugMenuTemplate == 0 then return end
    addon:GenerateMenu(self, addon.debugMenuTemplate)
  end)
  f.resetVarsButton:SetScript("OnClick", function()
    StaticPopup_Show(addon.name .. "RESETSAVEDVARS_POPUP")
  end)
  f.debugAddonButton:SetScript("OnClick", function()
    addon:Debug(addon)
  end)
  f.exitDevButton:SetScript("OnClick", setDevMode)


  local function BuildStatusBarMenu(testsStates)
    if not testsStates then return {} end

    ---@type AnyMenuEntry[]
    local menuTemplate = {}
    local tests = addon:GetTests()

    for _, test in ipairs(tests) do
      ---@type string
      local testStateIcon
      if testsStates[test.name] == nil then
        testStateIcon = CreateAtlasMarkup(pausedAtlas, 16, 16)
      elseif testsStates[test.name] == true then
        testStateIcon = CreateAtlasMarkup(tickAtlas, 16, 16)
      elseif testsStates[test.name] == false then
        testStateIcon = CreateAtlasMarkup(crossAtlas, 16, 16)
      end
      table.insert(menuTemplate, {
        type = "button",
        label = string.format("%s %s", test.name, testStateIcon),
        onClick = function()
          test:Run()
        end
      })
    end
    return menuTemplate
  end


  local testStates
  local function UpdateTestStatusbar()
    local testCount = addon:GetNumberOfTests()
    f.testStatusbar:SetStatusbarValue(0, testCount, 0)
    local runTestsButton = f.testStatusbar.runTestsButton
    runTestsButton:SetScript("OnClick", function()
      if not testCount or testCount == 0 then return end
      local testIndex = 0
      runTestsButton:Disable()
      runTestsButton:DesaturateHierarchy(1)
      addon:RunTests(function(success)
        if not success then return end
        testIndex = testIndex + 1
        f.testStatusbar:SetStatusbarValue(0, testCount, testIndex)
      end, function(states)
        runTestsButton:Enable()
        runTestsButton:DesaturateHierarchy(0)
        testStates = states
        local numErrors = 0
        for _, v in pairs(states) do
          if not v then
            numErrors = numErrors + 1
          end
        end
        f.testStatusbar.text:SetText(string.format("Tests successful: %d / %d", testCount - numErrors, testCount))
      end)
    end)
  end




  f.testStatusbar:SetScript("OnEnter", function(self)
    if not testStates then return end
    addon:GenerateMenu(self, BuildStatusBarMenu(testStates),
      { gridModeColumns = math.ceil(addon:GetNumberOfTests() / 25) })
  end)

  local function loadDevMode()
    local devModeEnabled = addon:GetVar("devMode")
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if (devModeEnabled) then
      addon:Print("Dev mode enabled")
      f:Show()
      UpdateTestStatusbar()
      C_Timer.After(1, function()
        LDBIcon:Show("BugSack")
        LDBIcon:Show(addon.name)
      end)
    else
      -- check what addons are loaded right now and save them
      local loadedAddons = {}
      for i = 1, C_AddOns.GetNumAddOns() do
        local name, _, _, _, reason = C_AddOns.GetAddOnInfo(i)
        if reason ~= "DISABLED" then
          table.insert(loadedAddons, name)
        end
      end
      if f and f:IsShown() then
        f:Hide()
      end
      addon:SetVar("loadedAddons", loadedAddons)
      C_Timer.After(1, function()
        LDBIcon:Hide("BugSack")
        LDBIcon:Hide(addon.name)
      end)
    end
  end


  f:SetScript("OnEvent", function(_, event, addonName)
    if (event == "ADDON_LOADED" and addonName == addon.name) then
      loadDevMode()
    end
    if (event == "PLAYER_LOGIN") then
      playerLoginFired = true
      C_Timer.After(0.1, function()
        for i = 1, #preFiredQueue do
          addon:Debug(unpack(preFiredQueue[i]))
        end
      end)
    end
  end)
end





-- -------------------------------------------------------------------------- --
--                                    Menu                                    --
-- -------------------------------------------------------------------------- --
---@param rootDescription SharedMenuDescriptionProxy
---@param entry AnyMenuEntry
---@return ElementMenuDescriptionProxy
local function GenerateMenuElement(rootDescription, entry)
  if entry.type == "title" then
    return rootDescription:CreateTitle(entry.label)
  elseif entry.type == "button" then
    return rootDescription:CreateButton(entry.label, entry.onClick)
  elseif entry.type == "checkbox" then
    return rootDescription:CreateCheckbox(entry.label, entry.isSelected, entry.setSelected, entry.data)
  elseif entry.type == "radio" then
    return rootDescription:CreateRadio(entry.label, entry.isSelected, entry.setSelected, entry.data)
  elseif entry.type == "divider" then
    return rootDescription:CreateDivider()
  elseif entry.type == "spacer" then
    return rootDescription:CreateSpacer()
  elseif entry.type == "template" then
    local templateEl = rootDescription:CreateTemplate(entry.template)
    templateEl:AddInitializer(entry.initializer)
    return templateEl
  elseif entry.type == "submenu" then
    assert(entry.entry.type == "button" or entry.entry.type == "checkbox" or entry.entry.type == "radio" or
      entry.entry.type == "template", "Submenu entry must be a button, checkbox, radio or template")
    ---@diagnostic disable-next-line: missing-parameter for submenus the second and third parameter are not used
    local subMenuButton = GenerateMenuElement(rootDescription, entry.entry)
    ---@type AnyMenuEntry[]
    local entries = type(entry.entries) == "function" and entry.entries() or
        entry.entries --[[@as AnyMenuEntry[]]
    for _, subEntry in ipairs(entries) do
      GenerateMenuElement(subMenuButton, subEntry)
    end
    return subMenuButton
  end
  error("Unknown menu entry type received!")
end



function NercUtils:GetGeneratorFunction(menuTemplate)
  assert(type(menuTemplate) == "table", "Menu template not provided or not a table")
  return function(_, rootDescription)
    ---@cast rootDescription ElementMenuDescriptionProxy
    for _, entry in ipairs(menuTemplate) do
      GenerateMenuElement(rootDescription, entry)
    end
  end
end

function NercUtils:GenerateMenu(parentFrame, menuTemplate, options)
  assert(type(parentFrame) == "table", "Parent frame not provided orr not a region")
  assert(type(menuTemplate) == "table", "Menu template not provided or not a table")
  options = options or {}
  local gridModeColumns = options.gridModeColumns
  MenuUtil.CreateContextMenu(parentFrame, function(_, rootDescription)
    ---@cast rootDescription ElementMenuDescriptionProxy
    if gridModeColumns then
      rootDescription:SetGridMode(MenuConstants.VerticalGridDirection, gridModeColumns)
    end
    for _, entry in ipairs(menuTemplate) do
      GenerateMenuElement(rootDescription, entry)
    end
  end)
end

-- -------------------------------------------------------------------------- --
--                                    Tests                                   --
-- -------------------------------------------------------------------------- --
local function FormatTestError(message, stack)
  assert(type(message) == "string", "Message not provided")
  assert(type(stack) == "string", "Stack not provided")
  -- split stack on new lines and remove the first line
  local stackLines = { strsplit("\n", stack) }
  return string.format("%s\n%s", message, stackLines[2])
end

local function serializeTable(t)
  local serializedValues = {}
  ---@type any, string
  local value, serializedValue
  for i = 1, #t do
    ---@type any
    value = t[i]
    serializedValue = type(value) == 'table' and serializeTable(value) or value
    table.insert(serializedValues, serializedValue)
  end
  return string.format("{ %s }", table.concat(serializedValues, ', '))
end

local function ToString(value)
  assert(value ~= nil, "Value not provided")
  if not value then
    return "nil"
  end
  if (type(value) == "table") then
    return serializeTable(value)
  end
  return tostring(value)
end


function NercUtils:Test(name, func)
  assert(type(name) == "string", "Test Name not provided")
  assert(type(func) == "function", "Test Function not provided")

  if (not self.tests) then
    self.tests = {}
  end

  local test = {
    name = name,
  }

  function test:Expect(value)
    ---@param expected any
    local function ToBe(expected)
      -- check if the value is a table
      if (type(value) == "table") then
        ---@cast value table<any, any>
        for k, v in pairs(value) do
          if (v ~= expected[k]) then
            error(FormatTestError(
              string.format("Expected %s to be %s.", ToString(v), ToString(expected[k])),
              debugstack(1)))
          end
        end
        return
      end
      if (value ~= expected) then
        error(FormatTestError(
          string.format("Expected %s to be %s.", ToString(value), ToString(expected)),
          debugstack(1)))
      end
    end

    local function ToBeTruthy()
      if not value then
        error(FormatTestError(string.format("Expected %s to be truthy.", ToString(value)),
          debugstack(1)))
      end
    end

    local function ToBeFalsy()
      if value then
        error(FormatTestError(string.format("Expected %s to be falsy.", ToString(value)),
          debugstack(1)))
      end
    end

    ---@param expected type
    local function ToBeType(_, expected)
      if (type(value) ~= expected) then
        error(FormatTestError(
          string.format("Expected %s to be of type %s.", ToString(value), ToString(expected)),
          debugstack(1)))
      end
    end

    return {
      ToBe = ToBe,
      ToBeTruthy = ToBeTruthy,
      ToBeFalsy = ToBeFalsy,
      ToBeType = ToBeType,
    }
  end

  ---@return boolean success
  ---@return string result
  function test:Run()
    return pcall(func, self)
  end

  table.insert(self.tests, test)
end

---@return number count
function NercUtils:GetNumberOfTests()
  return #(self.tests or {})
end

function NercUtils:GetTests()
  return self.tests
end

function NercUtils:RunTests(onUpdate, onFinish)
  local tests = self.tests
  if not tests then return end
  local testCount = self:GetNumberOfTests()
  ---@type table<string, boolean>
  local testState = {}

  ---@type FunctionContainer
  local ticker
  local testIndex = 1
  ticker = C_Timer.NewTicker(0.05, function()
    local test = tests[testIndex]
    if not test then return end
    local success, result = test:Run()
    onUpdate(success, result)
    testState[test.name] = success
    if (not success) then
      error(string.format("Test %s failed with error:\n%s", test.name, result))
    end
    if (testIndex >= testCount) then
      ticker:Cancel()
      onFinish(testState)
    end
    testIndex = testIndex + 1
  end, testCount)
end

-- -------------------------------------------------------------------------- --
--                                    Print                                   --
-- -------------------------------------------------------------------------- --

local defaultColor = ConsoleGetColorFromType(1)
function NercUtils:Print(...)
  local str = select(1, ...)
  local args = select(2, ...)
  if args then
    str = string.format(str, args) ---@type string
  end
  assert(type(str) == "string", "Print must be passed a string")
  local prefix = self:WrapTextInColor(self.name .. ": ", defaultColor)
  ---@diagnostic disable-next-line: undefined-global, no-unknown
  DEFAULT_CHAT_FRAME:AddMessage(prefix .. str)
end

function NercUtils:PrintUnformatted(...)
  local str = select(1, ...)
  local args = select(2, ...)
  if args then
    str = string.format(str, args) ---@type string
  end
  assert(type(str) == "string", "PrintUnformatted must be passed a string")
  ---@diagnostic disable-next-line: undefined-global, no-unknown
  DEFAULT_CHAT_FRAME:AddMessage(str)
end

function NercUtils:WrapTextInColor(text, color)
  assert(type(text) == "string", "Text not provided or incorrect type")
  assert(type(color) == "table", "Color not provided or incorrect type")
  local colorEscape = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
  return colorEscape .. text .. "|r"
end

local random = math.random



function NercUtils:GenerateUUID(prefix)
  assert(type(prefix) == "string" or prefix == nil, "Prefix must be a string or nil")
  local template = 'xxxxxxxx-yxxx'
  local ans = string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return string.format('%x', v)
  end)
  return prefix and prefix .. '-' .. ans or ans
end

-- -------------------------------------------------------------------------- --
--                                SlashCommands                               --
-- -------------------------------------------------------------------------- --

function NercUtils:SetSlashTrigger(trigger, triggerIndex)
  assert(type(trigger) == "string", "Slash command trigger not provided")
  assert(trigger:sub(1, 1) == "/", "Slash command trigger must start with /")

  local SLASH_PREFIX = string.format("SLASH_%s", self.name:upper())
  local GLOBAL_NAME = string.format("%s%d", SLASH_PREFIX, triggerIndex)
  ---@diagnostic disable-next-line: no-unknown
  _G[GLOBAL_NAME] = trigger
  ---@type function
  SlashCmdList[self.name:upper()] = function(msg)
    local args = {} ---@type table<number, string>
    for word in string.gmatch(msg, "[^%s]+") do
      table.insert(args, word)
    end
    local command = args[1]
    if self.commandList[command] then
      pcall(self.commandList[command], unpack(args))
    else
      local defaultAction = self.commandList["default"]
      if defaultAction then
        pcall(defaultAction, unpack(args))
      else
        self:PrintHelp()
      end
    end
  end
end

local normalColor = CreateColor(1, 0.82, 0)
local helpPattern = "|A:communities-icon-notification:8:8:2:-2|a %s - %s"

function NercUtils:PrintHelp()
  local addonVersion = C_AddOns.GetAddOnMetadata(self.name, "Version")
  local titleString = string.format("%s %s", self.name, addonVersion)
  self:PrintUnformatted(self:WrapTextInColor(titleString, normalColor))
  for command, help in pairs(self.commandHelpStrings) do
    local helpString = helpPattern:format(command, self:WrapTextInColor(help, normalColor))
    self:PrintUnformatted(helpString)
  end
end

function NercUtils:SetDefaultAction(func)
  assert(type(func) == "function", "Default action not provided")
  assert(not self.commandList["default"], "Default action already set")
  if not self.commandList then
    self.commandList = {}
  end
  self.commandList["default"] = func
end

function NercUtils:AddSlashCommand(command, func, help)
  assert(type(command) == "string", "Command not provided")
  assert(type(func) == "function", "Function not provided")
  assert(type(help) == "string", "Help not provided")
  if not self.commandList then
    self.commandList = {}
  end
  if not self.commandHelpStrings then
    self.commandHelpStrings = {}
  end
  self.commandList[command] = func
  self.commandHelpStrings[command] = help
end

function NercUtils:RemoveSlashCommand(command)
  assert(type(command) == "string", "Command not provided")
  self.commandList[command] = nil
  self.commandHelpStrings[command] = nil
end

function NercUtils:EnableHelpCommand()
  ---@diagnostic disable-next-line: undefined-global
  self:AddSlashCommand(HELP_LABEL, function()
    self:PrintHelp()
    ---@diagnostic disable-next-line: undefined-global
  end, HELP_LABEL)
end

-- -------------------------------------------------------------------------- --
--                                AsyncUtils                                  --
-- -------------------------------------------------------------------------- --


function NercUtils:DebounceChange(func, delay, callback)
  assert(type(func) == "function", "Function not provided")
  assert(type(delay) == "number", "Delay not provided")
  ---@type FunctionContainer?
  local timer
  return function(...)
    local args = { ... }
    if timer then
      timer:Cancel()
    end
    timer = C_Timer.NewTimer(delay, function()
      local result = { func(unpack(args)) }
      if callback and result then
        callback(unpack(result))
      end
    end)
  end
end

function NercUtils:BatchExecution(funcList, onUpdate, onFinish)
  assert(type(funcList) == "table", "Function list not provided")
  assert(type(onUpdate) == "function" or onUpdate == nil, "OnUpdate not a function")
  assert(type(onFinish) == "function" or onFinish == nil, "OnFinish not a function")
  local frameRate = GetFramerate()
  if frameRate == 0 then frameRate = 1 end
  local delay = 1 / frameRate

  ---@async
  local function Worker()
    local maxProgress = #funcList
    local nextTime = coroutine.yield()
    for i = 1, maxProgress do
      funcList[i]()
      if onUpdate then onUpdate(i, maxProgress) end
      if GetTimePreciseSec() > nextTime then
        nextTime = coroutine.yield()
      end
    end
  end

  local workerThread = coroutine.create(Worker)
  local ticker
  ticker = C_Timer.NewTicker(delay,
    function()
      local success = coroutine.resume(workerThread, GetTimePreciseSec() + delay)
      if not success or coroutine.status(workerThread) == "dead" then
        ticker:Cancel()
        if onFinish then onFinish() end
        return
      end
    end
  )
end

-- -------------------------------------------------------------------------- --
--                               Localization                                 --
-- -------------------------------------------------------------------------- --
local function AddLocalalization()
  local L = {}
  setmetatable(L, {
    __index = function(t, k)
      local v = tostring(k)
      --@do-not-package@
      error("Missing localization for: " .. v)
      --@end-do-not-package@
      rawset(t, k, v)
      return v
    end
  })
  return L
end

-- -------------------------------------------------------------------------- --
--                                 Events                                     --
-- -------------------------------------------------------------------------- --
function NercUtils:RegisterEvent(event, func)
  assert(event, "Event must be provided")
  assert(func, "Function must be provided")
  if not self.registeredEvents then
    self.registeredEvents = {}
  end
  if not self.registeredEvents[event] then
    self.registeredEvents[event] = {}
  end
  table.insert(self.registeredEvents[event], func)
  if (not self.addonEventFrame) then
    self.addonEventFrame = CreateFrame("Frame")
    self.addonEventFrame:SetScript("OnEvent", function(_, event, ...)
      local funcs = self.registeredEvents[event]
      if (funcs) then
        for _, func in ipairs(funcs) do
          func(...)
        end
      end
    end)
  end
  self.addonEventFrame:RegisterEvent(event)
end

function NercUtils:UnregisterEventForFunction(event, func)
  assert(event, "Event must be provided")
  assert(func, "Function must be provided")
  if not self.registeredEvents then
    self.registeredEvents = {}
  end
  if not self.registeredEvents[event] then
    self.registeredEvents[event] = {}
  end
  if self.registeredEvents[event] then
    for i, f in ipairs(self.registeredEvents[event]) do
      if f == func then
        table.remove(self.registeredEvents[event], i)
        break
      end
    end
  end
  if #self.registeredEvents[event] == 0 then
    self.registeredEvents[event] = nil
    self.addonEventFrame:UnregisterEvent(event)
  end
end

function NercUtils:UnregisterEvent(event)
  assert(event, "Event must be provided")
  if not self.registeredEvents then
    self.registeredEvents = {}
  end
  self.registeredEvents[event] = nil
  self.addonEventFrame:UnregisterEvent(event)
end

-- -------------------------------------------------------------------------- --
--                                  Core                                      --
-- -------------------------------------------------------------------------- --

function NercUtils:GetModule(name)
  assert(self.modules, "Modules not initialized")
  assert(name, "Module name not provided")

  if (not self.modules or not self.modules[name]) then
    local m = {}
    if (not self.modules) then
      self.modules = {}
    end
    self.modules[name] = m
    return m
  end
  return self.modules[name]
end

local mixins = {
  "InitDB",
  "RegisterEvent",
  "UnregisterEventForFunction",
  "UnregisterEvent",
  "GetModule",
  "GetDefault",
  "SetDefault",
  "SetVar",
  "GetVar",
  "DeleteVar",
  "MigrateVar",
  "GetGeneratorFunction",
  "GenerateMenu",
  "Test",
  "GetNumberOfTests",
  "GetTests",
  "RunTests",
  "Print",
  "PrintUnformatted",
  "WrapTextInColor",
  "GenerateUUID",
  "SetSlashTrigger",
  "PrintHelp",
  "SetDefaultAction",
  "AddSlashCommand",
  "RemoveSlashCommand",
  "EnableHelpCommand",
  "DebounceChange",
  "BatchExecution",
}

---@type table<string, NercUtilsAddon>
local addons = {}

function NercUtils:GetAddon(addonName, addonTable)
  if (addons[addonName]) then
    return addons[addonName]
  end

  addonTable.name = addonName
  addonTable.modules = {}

  for _, v in pairs(mixins) do
    addonTable[v] = self[v]
  end

  -- Set up localization
  addonTable.locale = GetLocale() --[[@as AceLocale.LocaleCode]]
  addonTable.L = AddLocalalization()

  AddDebugMenu(addonTable)

  addons[addonName] = addonTable
  return addonTable
end
