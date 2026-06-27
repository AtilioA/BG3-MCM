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

---@param blueprint Blueprint
---@param callback fun(setting: BlueprintSetting, path: string[])
function BlueprintShape:ForEachSetting(blueprint, callback)
    local function visitElement(element, path)
        for _, setting in ipairs(self:GetSettings(element)) do
            callback(setting, path)
        end

        for _, section in ipairs(self:GetSections(element)) do
            visitElement(section, appendPath(path, section:GetId()))
        end

        for _, tab in ipairs(self:GetTabs(element)) do
            visitElement(tab, appendPath(path, tab:GetId()))
        end
    end

    visitElement(blueprint, {})
end

---@param blueprint Blueprint
---@return table<string, BlueprintSetting>
function BlueprintShape:GetAllSettings(blueprint)
    local allSettings = {}

    self:ForEachSetting(blueprint, function(setting)
        allSettings[setting:GetId()] = setting
    end)

    return allSettings
end

---@param blueprint Blueprint
---@return BlueprintSetting[]
function BlueprintShape:GetAllSettingsOrdered(blueprint)
    local settings = {}

    self:ForEachSetting(blueprint, function(setting)
        table.insert(settings, setting)
    end)

    return settings
end

---@param blueprint Blueprint
---@return boolean
function BlueprintShape:HasAnySettings(blueprint)
    local hasSettings = false

    self:ForEachSetting(blueprint, function()
        hasSettings = true
    end)

    return hasSettings
end

---@param blueprint Blueprint
---@param settingId string
---@return any
function BlueprintShape:RetrieveDefaultValueForSetting(blueprint, settingId)
    local settings = self:GetAllSettings(blueprint)

    if not settings[settingId] then
        MCMWarn(1, "Setting with ID %s not found in blueprint. Returning nil as default value.", settingId)
        return nil
    end

    return settings[settingId]:GetDefault()
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
