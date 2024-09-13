-- REFACTOR: This file should be split into multiple files, and the functions should be moved to the appropriate files.
-- ---@class HelperMCMUtils: Helper
-- MCMUtils = _Class:Create("HelperMCMUtils", Helper)

MCMUtils = {}

MCMUtils.NPAKMWarned = false


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

-- TODO: move to a separate file
---@class IMGUIWarningWindow
---@field window any
---@field warningLevel integer
---@field warningMessage string
---@field title string
IMGUIWarningWindow = _Class:Create("IMGUIWarningWindow", nil, {
    window = nil,
    warningLevel = 0,
    warningMessage = "",
    title = "Warning"
})

---@param level integer The warning level
---@param title string The title of the warning window
---@param message string The message to display in the window
function IMGUIWarningWindow:new(level, title, message)
    local instance = setmetatable({}, { __index = IMGUIWarningWindow })
    instance.warningLevel = level
    instance.warningMessage = message
    instance.title = title
    instance:CreateWindow()
    return instance
end

function IMGUIWarningWindow:CreateWindow()
    self.window = Ext.IMGUI.NewWindow(self.title)
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
    -- if not itemIcon.ImageData or itemIcon.ImageData.Icon == "" then
    --     itemIcon:Destroy()
    -- end

    if itemIcon then
        itemIcon.SameLine = true
        itemIcon.Border = borderColor
        if itemIcon then
            itemIcon.IDContext = "WarningIcon"
        end
    end

    -- Add blinking functionality
    local isFocused = true
    local blinkInterval = 500 -- milliseconds
    local blinkTimer

    local function toggleVisibility()
        if not isFocused then
            self.window.Visible = not self.window.Visible
            print("Window visibility toggled to: " .. tostring(self.window.Visible))
        else
            self.window.Visible = true
            print("Window is focused, setting visibility to true.")
            if blinkTimer then
                Ext.Timer.Cancel(blinkTimer)
                blinkTimer = nil
                print("Blink timer cancelled.")
            end
        end
    end

    self.window.OnActivate = function()
        isFocused = true
        print("Window activated.")
        toggleVisibility()
    end

    self.window.OnDeactivate = function()
        isFocused = false
        print("Window deactivated.")
        if not blinkTimer then
            blinkTimer = Ext.Timer.WaitFor(blinkInterval, function()
                toggleVisibility()
            end)
            print("Blink timer started with interval: " .. blinkInterval .. " ms.")
        end
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
---@param title string The title of the warning window
---@param message string The message to display
function MCMUtils:CreateIMGUIWarning(level, title, message)
    if Ext.IsClient() then
        return IMGUIWarningWindow:new(level, title, message)
    end
end

function MCMUtils:CreateNPAKMIMGUIWarning()
    if not self.NPAKMWarned then
        IMGUIWarningWindow:new(0, "Wrong No Press Any Key Menu version",
            "You're using 'No Press Any Key Menu' without the MCM compatibility patch.\nYour main menu may not work correctly.\n\nPlease replace it with the patched version from Caites' mod page.")
        self.NPAKMWarned = true
    end
end

function MCMUtils:WarnAboutNPAKM()
    if not self:ShouldWarnAboutNPAKM() then
        return
    end

    self:CreateNPAKMIMGUIWarning()
    MCMWarn(0,
        "You're using 'No Press Any Key Menu' without the compatibility patch for MCM. Please replace it with the patched version available at its mod page.")
end

function MCMUtils:WarnAboutLoadOrderDependencies()
    local issues = DependencyCheck:EvaluateLoadOrderDependencies()
    for _, issue in ipairs(issues) do
        local dependencyIssueTitle = "Dependency issue detected: " ..
            issue.modName .. " depends on " .. issue.dependencyName
        self:CreateIMGUIWarning(0, dependencyIssueTitle, issue.errorMessage)
        MCMWarn(0, issue.errorMessage)
    end
end

return MCMUtils
