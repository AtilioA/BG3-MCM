---@class BlueprintShapeEntry
---@field id string
---@field setting BlueprintSetting
---@field path string[]

---@class BlueprintShape
BlueprintShape = _Class:Create("BlueprintShape", nil)

---@param values table|nil
---@return table
local function copyPath(values)
    local copy = {}
    for index, value in ipairs(values or {}) do
        copy[index] = value
    end
    return copy
end

---@param path table
---@param id string|nil
---@return table
local function appendPath(path, id)
    local nextPath = copyPath(path)
    if id and id ~= "" then
        table.insert(nextPath, id)
    end
    return nextPath
end

---@param element any
---@return string|nil
local function getElementId(element)
    if not element then
        return nil
    end

    if element.GetId then
        return element:GetId()
    end

    return element.Id or element.TabId or element.SectionId
end

---@param element any
---@return BlueprintTab[]
function BlueprintShape:GetTabs(element)
    if not element then
        return {}
    end

    if element.GetTabs then
        return element:GetTabs() or {}
    end

    return element.Tabs or {}
end

---@param element any
---@return BlueprintSection[]
function BlueprintShape:GetSections(element)
    if not element then
        return {}
    end

    if element.GetSections then
        return element:GetSections() or {}
    end

    return element.Sections or {}
end

---@param element any
---@return BlueprintSetting[]
function BlueprintShape:GetSettings(element)
    if not element then
        return {}
    end

    if element.GetSettings then
        return element:GetSettings() or {}
    end

    return element.Settings or {}
end

---@param blueprint Blueprint
---@param callback fun(element: any, elementType: string)
function BlueprintShape:ForEachElement(blueprint, callback)
    local function visitElement(element, elementType)
        callback(element, elementType)

        for _, section in ipairs(self:GetSections(element)) do
            visitElement(section, "section")
        end

        for _, tab in ipairs(self:GetTabs(element)) do
            visitElement(tab, "tab")
        end

        for _, setting in ipairs(self:GetSettings(element)) do
            callback(setting, "setting")
        end
    end

    visitElement(blueprint, "blueprint")
end

---@param blueprint Blueprint
---@param callback fun(tab: BlueprintTab)
function BlueprintShape:ForEachTab(blueprint, callback)
    local function visitTabs(tabs)
        for _, tab in ipairs(tabs or {}) do
            callback(tab)
            visitTabs(self:GetTabs(tab))

            for _, section in ipairs(self:GetSections(tab)) do
                visitTabs(self:GetTabs(section))
            end
        end
    end

    visitTabs(self:GetTabs(blueprint))

    for _, section in ipairs(self:GetSections(blueprint)) do
        visitTabs(self:GetTabs(section))
    end
end

---@param blueprint Blueprint
---@param callback fun(section: BlueprintSection)
function BlueprintShape:ForEachSection(blueprint, callback)
    local function visitElement(element)
        for _, section in ipairs(self:GetSections(element)) do
            callback(section)
            visitElement(section)
        end

        for _, tab in ipairs(self:GetTabs(element)) do
            visitElement(tab)
        end
    end

    visitElement(blueprint)
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@return BlueprintCacheIndex
function BlueprintShape:_BuildIndex(blueprint)
    local index = {
        byId = {},
        entries = {},
        pathById = {},
        hasAnySettings = false,
    }

    local function visitElement(element, path)
        for _, setting in ipairs(self:GetSettings(element)) do
            local settingId = getElementId(setting)
            local settingPath = copyPath(path)
            if settingId then
                index.byId[settingId] = setting
                index.pathById[settingId] = settingPath
            end
            table.insert(index.entries, {
                id = settingId,
                setting = setting,
                path = settingPath,
            })
            index.hasAnySettings = true
        end

        for _, section in ipairs(self:GetSections(element)) do
            visitElement(section, appendPath(path, getElementId(section)))
        end

        for _, tab in ipairs(self:GetTabs(element)) do
            visitElement(tab, appendPath(path, getElementId(tab)))
        end
    end

    visitElement(blueprint, {})
    return index
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@return BlueprintCacheIndex
function BlueprintShape:GetIndex(blueprint)
    return BlueprintCache:GetOrBuild(blueprint, function(root)
        return self:_BuildIndex(root)
    end)
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@param callback fun(setting: BlueprintSetting, path: string[])
function BlueprintShape:ForEachSetting(blueprint, callback)
    local index = self:GetIndex(blueprint)
    for _, entry in ipairs(index.entries) do
        callback(entry.setting, entry.path)
    end
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@return table<string, BlueprintSetting>
function BlueprintShape:GetAllSettings(blueprint)
    local settings = {}
    local index = self:GetIndex(blueprint)

    for id, setting in pairs(index.byId) do
        settings[id] = setting
    end

    return settings
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@return BlueprintSetting[]
function BlueprintShape:GetAllSettingsOrdered(blueprint)
    local settings = {}
    local index = self:GetIndex(blueprint)

    for _, entry in ipairs(index.entries) do
        table.insert(settings, entry.setting)
    end

    return settings
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@return boolean
function BlueprintShape:HasAnySettings(blueprint)
    return self:GetIndex(blueprint).hasAnySettings
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@param settingId string
---@return BlueprintSetting|nil
function BlueprintShape:GetSettingById(blueprint, settingId)
    return self:GetIndex(blueprint).byId[settingId]
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@param settingId string
---@return boolean
function BlueprintShape:IsSettingId(blueprint, settingId)
    return self:GetIndex(blueprint).byId[settingId] ~= nil
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@param settingId string
---@return string[]|nil
function BlueprintShape:GetPathForSetting(blueprint, settingId)
    local path = self:GetIndex(blueprint).pathById[settingId]
    if not path then
        return nil
    end

    return copyPath(path)
end

---@param blueprint Blueprint|BlueprintTab|BlueprintSection
---@param settingId string
---@return any
function BlueprintShape:RetrieveDefaultValueForSetting(blueprint, settingId)
    local setting = self:GetSettingById(blueprint, settingId)

    if not setting then
        MCMWarn(1, "Setting with ID %s not found in blueprint. Returning nil as default value.", settingId)
        return nil
    end

    return setting:GetDefault()
end

function BlueprintShape:InvalidateCache()
    BlueprintCache:InvalidateAll()
end

---@param output table
---@param path string[]
---@param key string
---@param value any
function BlueprintShape:SetNestedSettingValue(output, path, key, value)
    local target = output

    for _, pathKey in ipairs(path or {}) do
        if type(target[pathKey]) ~= "table" then
            target[pathKey] = {}
        end
        target = target[pathKey]
    end

    target[key] = value
end

return BlueprintShape
