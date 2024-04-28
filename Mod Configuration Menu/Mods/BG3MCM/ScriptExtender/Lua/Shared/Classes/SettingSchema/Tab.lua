---@class SchemaTab
---@field private TabId string
---@field private TabName string
---@field private TabDescription string
---@field private Sections? SchemaSection[]
---@field private Settings? SchemaSetting[]
---@field private Handles? table
SchemaTab = _Class:Create("SchemaTab", nil, {
    TabId = "",
    TabName = "",
    TabDescription = "",
    Sections = {},
    Settings = {},
    Handles = {}
})

--- Constructor for the SchemaTab class.
--- @param options table
function SchemaTab:New(options)
    local self = setmetatable({}, SchemaTab)
    self.TabId = options.TabId or ""
    self.TabName = options.TabName or ""
    self.TabDescription = options.TabDescription or ""
    self.Sections = {}
    self.Settings = {}
    self.Handles = options.Handles

    if options.Sections then
        for _, sectionOptions in ipairs(options.Sections) do
            local section = SchemaSection:New(sectionOptions)
            table.insert(self.Sections, section)
        end
    end

    if options.Settings then
        for _, settingOptions in ipairs(options.Settings) do
            local setting = SchemaSetting:New(settingOptions)
            table.insert(self.Settings, setting)
        end
    end

    return self
end

--- Get the TabId of the SchemaTab.
--- @return string
function SchemaTab:GetTabId()
    return self.TabId
end

--- Get the TabName of the SchemaTab.
--- @return string
function SchemaTab:GetTabName()
    return self.TabName
end

--- Get the TabDescription of the SchemaTab.
--- @return string
function SchemaTab:GetTabDescription()
    return self.TabDescription
end

--- Get the Sections of the SchemaTab.
--- @return SchemaSection[]
--- @return nil - If there are no sections
function SchemaTab:GetSections()
    return self.Sections
end

--- Get the Settings of the SchemaTab.
--- @return SchemaSetting[]
--- @return nil - If there are no settings
function SchemaTab:GetSettings()
    return self.Settings
end

--- Add a new SchemaSection to the SchemaTab.
--- @param sectionOptions table
--- @return SchemaTab
function SchemaTab:AddSection(sectionOptions)
    local section = SchemaSection:New(sectionOptions)
    table.insert(self.Sections, section)
    return self
end

--- Add a new SchemaSetting to the SchemaTab.
--- @param settingOptions table
--- @return SchemaTab
function SchemaTab:AddSetting(settingOptions)
    local setting = SchemaSetting:New(settingOptions)
    table.insert(self.Settings, setting)
    return self
end

--- Get the Handles of the SchemaTab.
--- @return table
function SchemaTab:GetHandles()
    return self.Handles
end

--- Set the Handles of the SchemaTab.
--- @param handles table
function SchemaTab:SetHandles(handles)
    self.Handles = handles
end
