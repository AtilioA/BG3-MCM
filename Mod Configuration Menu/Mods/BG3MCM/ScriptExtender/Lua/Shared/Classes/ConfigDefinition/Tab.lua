---@class BlueprintTab
---@field private TabId string
---@field private TabName string
---@field private TabDescription string
---@field private VisibleIf string
---@field private Tabs? BlueprintTab[]
---@field private Sections? BlueprintSection[]
---@field private Settings? BlueprintSetting[]
---@field private Handles? table
BlueprintTab = _Class:Create("BlueprintTab", nil, {
    TabId = "",
    TabName = "",
    TabDescription = "",
    VisibleIf = "",
    Tabs = {},
    Sections = {},
    Settings = {},
    Handles = {}
})

--- Constructor for the BlueprintTab class.
--- @param options table
function BlueprintTab:New(options)
    local self = setmetatable({}, BlueprintTab)
    self.TabId = options.TabId or ""
    self.TabName = options.TabName or ""
    self.TabDescription = options.TabDescription or ""
    self.VisibleIf = options.VisibleIf or ""
    self.Tabs = {}
    self.Sections = {}
    self.Settings = {}
    self.Handles = options.Handles

    if options.Tabs then
        for _, tabOptions in ipairs(options.Tabs) do
            table.insert(self.Tabs, BlueprintTab:New(tabOptions))
        end
    end

    if options.Sections then
        for _, sectionOptions in ipairs(options.Sections) do
            local section = BlueprintSection:New(sectionOptions)
            table.insert(self.Sections, section)
        end
    end

    if options.Settings then
        for _, settingOptions in ipairs(options.Settings) do
            local setting = BlueprintSetting:New(settingOptions)
            table.insert(self.Settings, setting)
        end
    end

    return self
end

--- Get the TabId of the BlueprintTab.
--- @return string
function BlueprintTab:GetId()
    return self.TabId
end

--- Get the TabName of the BlueprintTab.
--- @return string
function BlueprintTab:GetTabName()
    return self.TabName
end

--- Get the localized TabName of the BlueprintTab.
--- @return string
function BlueprintTab:GetLocaName()
    local tabName = self.TabName
    if self.Handles then
        if self.Handles.NameHandle then
            local translatedName = Ext.Loca.GetTranslatedString(self.Handles.NameHandle)
            if translatedName ~= nil and translatedName ~= "" then
                tabName = translatedName
            end
        end
    end

    return tabName
end

--- Get the TabDescription of the BlueprintTab.
--- @return string
function BlueprintTab:GetTabDescription()
    return self.TabDescription
end

function BlueprintTab:GetVisibleIf()
    return self.VisibleIf
end

--- Get the Sections of the BlueprintTab.
--- @return BlueprintSection[]
--- @return nil - If there are no sections
function BlueprintTab:GetSections()
    return self.Sections
end

--- Get the Settings of the BlueprintTab.
--- @return BlueprintSetting[]
--- @return nil - If there are no settings
function BlueprintTab:GetSettings()
    return self.Settings
end

--- Add a new BlueprintSection to the BlueprintTab.
--- @param sectionOptions table
--- @return BlueprintTab
function BlueprintTab:AddSection(sectionOptions)
    local section = BlueprintSection:New(sectionOptions)
    table.insert(self.Sections, section)
    return self
end

--- Add a new BlueprintSetting to the BlueprintTab.
--- @param settingOptions table
--- @return BlueprintTab
function BlueprintTab:AddSetting(settingOptions)
    local setting = BlueprintSetting:New(settingOptions)
    table.insert(self.Settings, setting)
    return self
end

--- Get the Handles of the BlueprintTab.
--- @return table
function BlueprintTab:GetHandles()
    return self.Handles
end

--- Set the Handles of the BlueprintTab.
--- @param handles table
function BlueprintTab:SetHandles(handles)
    self.Handles = handles
end

--- Get all settings under this tab, including those in sections.
--- @return BlueprintSetting[]
function BlueprintTab:GetAllSettings()
    local settings = {}

    for _, setting in ipairs(self.Settings or {}) do
        table.insert(settings, setting)
    end

    for _, section in ipairs(self.Sections or {}) do
        for _, setting in ipairs(section:GetSettings() or {}) do
            table.insert(settings, setting)
        end
    end

    return settings
end
