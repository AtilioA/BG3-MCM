-- REFACTOR: This file should be split into multiple files, and the functions should be moved to the appropriate files.
-- ---@class HelperMCMUtils: Helper
-- MCMUtils = _Class:Create("HelperMCMUtils", Helper)

MCMUtils = {}

MCMUtils.NPAKMWarned = false

--- Utility function to check if a table contains a value
---@param tbl table The table to search
---@param element any The element to find
---@return boolean - Whether the table contains the element
function table.contains(tbl, element)
    if type(tbl) ~= "table" then
        return false
    end

    if tbl == nil or element == nil then
        return false
    end

    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

---Utility function to find the index of an element in a table
---@param tbl table The table to search
---@param element any The element to find
---@return integer|nil i The index of the element in the table, or nil if the element is not found
function table.indexOf(tbl, element)
    for i, value in ipairs(tbl) do
        if value == element then
            return i
        end
    end
    return nil
end

-- Utility function to check if a table is an array, since Lua couldn't be bothered to separate arrays and hash tables
---@param tbl table The table to check.
---@return boolean True if the table is an array, false otherwise.
function table.isArray(tbl)
    local index = 0
    for _ in pairs(tbl) do
        index = index + 1
        if tbl[index] == nil then
            return false
        end
    end
    return true
end

-- Convert string representations of booleans to actual boolean values in a table
function table.convertStringBooleans(tbl)
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            table.convertStringBooleans(value)
        elseif value == "true" then
            tbl[key] = true
        elseif value == "false" then
            tbl[key] = false
        end
    end
end

--- Check if a table is empty ([], {})
function table.isEmpty(tbl)
    return next(tbl) == nil
end

--- Sorts the mods by name and returns a sorted array of mod GUIDs, with MCM placed first
---@param mods table The table of mods to sort
---@return table The sorted array of mod GUIDs
function MCMUtils.SortModsByName(mods)
    -- Create an array for the UUIDs, to be sorted
    local sortedUuids = {}
    for uuid in pairs(mods) do
        table.insert(sortedUuids, uuid)
    end

    -- Sort the sortedUuids, placing the mod with UUID 755a8a72-407f-4f0d-9a33-274ac0f0b53d first
    table.sort(sortedUuids, function(a, b)
        if a == "755a8a72-407f-4f0d-9a33-274ac0f0b53d" then
            return true
        elseif b == "755a8a72-407f-4f0d-9a33-274ac0f0b53d" then
            return false
        else
            local modAName = MCMClientState:GetModName(a)
            local modBName = MCMClientState:GetModName(b)
            return modAName < modBName
        end
    end)

    return sortedUuids
end

--- Add newlines after each period in a string
function MCMUtils.AddNewlinesAfterPeriods(description)
    return string.gsub(description, "%. ", ".\n")
end

--- Replace <br> tags with newlines in a string
function MCMUtils.ReplaceBrWithNewlines(description)
    return string.gsub(description, "<br>", "\n")
end

function MCMUtils:ConditionalWrapper(conditionFunc, func)
    return function(...)
        if conditionFunc() then
            func(...)
        end
    end
end

-- Return the party members currently following the player
function MCMUtils:GetPartyMembers()
    local teamMembers = {}

    local allPlayers = Osi.DB_Players:Get(nil)
    for _, player in ipairs(allPlayers) do
        if not string.match(player[1]:lower(), "%f[%A]dummy%f[%A]") then
            teamMembers[#teamMembers + 1] = string.sub(player[1], -36)
        end
    end

    return teamMembers
end

-- Returns the character that the user is controlling
function MCMUtils:GetUserCharacter(userId)
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        if entity.UserReservedFor.UserID == userId then
            return entity.Uuid.EntityUuid
        end
    end

    return nil
end

function MCMUtils:IsUserHost(userId)
    if userId == 65537 then
        return true
    end

    local character = self:GetUserCharacter(userId)
    if Osi.GetHostCharacter() == character then
        return true
    end

    return false
end

-- Thanks to Aahz for this function
function MCMUtils:PeerToUserID(u)
    -- all this for userid+1 usually smh
    return (u & 0xffff0000) | 0x0001
end

--- Play a sound effect on the host character (don't know if this works for multiplayer, would probably require getting the player character)
--- @param id GUIDSTRING
function MCMUtils:PlaySound(userid, id)
    local character = self:GetUserCharacter(userid) or Osi.GetHostCharacter()
    if character == nil then
        return
    end

    Osi.PlayEffect(character, id)
    Osi.PlaySound(character, id)
    Osi.PlaySoundResource(character, id)
end

---@param module? Guid
function MCMUtils:SyncModVars(module)
    local ModVars = Ext.Vars.GetModVariables(module or ModuleUUID)
    -- Redundant but worky :catyep:
    if ModVars then
        for varName, data in pairs(ModVars) do
            ModVars[varName] = ModVars[varName]
        end
        Ext.Vars.DirtyModVariables(module or ModuleUUID)
        Ext.Vars.SyncModVariables(module or ModuleUUID)
    end
end

function MCMUtils.UpdateLoca()
    for _, file in ipairs({ "BG3MCM_English.loca" }) do
        local fileName = string.format("Localization/English/%s.xml", file)
        local contents = Ext.IO.LoadFile(fileName, "data")

        if not contents then
            return
        end

        for line in string.gmatch(contents, "([^\r\n]+)\r*\n") do
            local handle, value = string.match(line, '<content contentuid="(%w+)".->(.+)</content>')
            if handle ~= nil and value ~= nil then
                value = value:gsub("&[lg]t;", {
                    ['&lt;'] = "<",
                    ['&gt;'] = ">"
                })
                Ext.Loca.UpdateTranslatedString(handle, value)
            end
        end
    end
end

function MCMUtils:ShouldWarnAboutNPAKM()
    local NoPressAnyKeyMenuUUID = "2bae5aa8-bf6a-d196-069c-4269f71d22a3"
    local NoPressAnyKeyMenuMCMUUID = "eb263453-0cc2-4f0c-2375-f4e0f60e8a12"
    local NoPressAnyKeyMenuPTSDUUID = "8c417ab1-195a-2c2a-abbf-70a2da9166da"

    if Ext.Mod.IsModLoaded(NoPressAnyKeyMenuUUID) or Ext.Mod.IsModLoaded(NoPressAnyKeyMenuPTSDUUID) then
        return true
    end

    -- Also double check, because with inactive mods you never know
    if Ext.Mod.IsModLoaded(NoPressAnyKeyMenuMCMUUID) then
        return false
    end
end

-- TODO: move to a separate file
---@class IMGUIWarningWindow
---@field window any
---@field warningLevel integer
---@field warningMessage string
IMGUIWarningWindow = _Class:Create("IMGUIWarningWindow", nil, {
    window = nil,
    warningLevel = 0,
    warningMessage = ""
})

---@param level integer
---@param message string
function IMGUIWarningWindow:new(level, message)
    local instance = setmetatable({}, { __index = IMGUIWarningWindow })
    instance.warningLevel = level
    instance.warningMessage = message
    instance:CreateWindow()
    return instance
end

function IMGUIWarningWindow:CreateWindow()
    self.window = Ext.IMGUI.NewWindow("MCM Warning")
    self.window:SetStyle("Alpha", 1.0)
    self.window:SetColor("TitleBgActive", Color.NormalizedRGBA(255, 10, 10, 1))
    self.window:SetColor("TitleBg", Color.NormalizedRGBA(255, 38, 38, 0.78))
    self.window:SetColor("WindowBg", Color.NormalizedRGBA(18, 18, 18, 1))
    self.window:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    self.window.AlwaysAutoResize = true
    self.window.Closeable = true
    self.window.Visible = true
    self.window.Open = true

    local iconSize = 64

    local borderColor = Color.HEXToRGBA("#FF2222")
    local icon = "ico_warning_yellow"
    if self.warningLevel == 0 then
        icon = "ico_exclamation_01"
        borderColor = Color.HEXToRGBA("#FF2222")
    elseif self.warningLevel == 1 then
        borderColor = Color.HEXToRGBA("#FF9922")
        icon = "ico_exclamation_02"
    else
        icon = "ico_warning_yellow"
        borderColor = Color.HEXToRGBA("#FFCC22")
    end

    local itemIcon = self.window:AddImage(icon, { iconSize, iconSize })
    if not itemIcon.ImageData or itemIcon.ImageData.Icon == "" then
        itemIcon:Destroy()
    end

    itemIcon.SameLine = true
    itemIcon.Border = borderColor
    if itemIcon then
        itemIcon.IDContext = "WarningIcon"
    end

    local messageText = self.window:AddText(self.warningMessage)
    -- messageText.Padding = { iconPadding, iconPadding, iconPadding, iconPadding }
    messageText:SetColor("Text", borderColor)
    -- messageText.TextWrapPos = 0.0
    messageText.SameLine = true

    -- self.window:AddDummy(0, 10)
    -- self.window:AddDummy(700, 0)
    -- local dismissButton = self.window:AddButton("Dismiss")
    -- dismissButton.OnClick = function()
    --     self.window:Destroy()
    --     self.window.Visible = false
    --     -- MCMUtils.NPAKMWarned = false
    -- end
    -- dismissButton.SameLine = true
end

--- Displays a warning message to the user
---@param level integer The warning level
---@param message string The message to display
function MCMUtils:CreateIMGUIWarning(level, message)
    if not self.NPAKMWarned then
        IMGUIWarningWindow:new(level, message)
        self.NPAKMWarned = true
    end
end

function MCMUtils:WarnAboutNPAKM()
    if not self:ShouldWarnAboutNPAKM() then
        return
    end

    self:CreateIMGUIWarning(0,
        "You're using 'No Press Any Key Menu' without the MCM compatibility patch.\nYour main menu may not work correctly.\n\nPlease replace it with the patched version from Caites' mod page.")
    MCMWarn(0,
        "You're using 'No Press Any Key Menu' without the compatibility patch for MCM. Please replace it with the patched version available at its mod page.")
end

return MCMUtils
