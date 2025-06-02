--- Handles collection and processing of native game keybindings

-- Device type constants
local DEVICE_TYPE = {
    UNASSIGNED = -1,
    MOUSE = 1,
    KEYBOARD_MIN = 0,
    KEYBOARD_MAX = 256,
    CONTROLLER_MIN = 257 -- First controller ID
}

---@alias NativeKeybindingsResult {Public: NativeKeybinding[], Internal: NativeKeybinding[]}

---@class NativeKeybindings

---@class InputManager
---@field InputScheme InputScheme
---@field InputDefinitions InputDefinition[]

---@class InputScheme
---@field InputBindings table<string, InputBinding>

---@class InputBinding
---@field EventID string
---@field Modifiers string[]

---@class InputDefinition
---@field EventID string
---@field EventName string
---@field CategoryName string
---@field EventDesc {Get: fun(): string}
---@field Type table

local NativeKeybindings = {}
local _initialized = false
---@type InputManager|nil
local _inputManager = nil

---@class NativeKeybinding
---@field CategoryName string
---@field EventName string
---@field Description string
---@field Bindings NativeKeybindingBinding[]
---@field Type table

---@class NativeKeybindingBinding
---@field InputId string
---@field Modifiers string[]

--- Initialize the NativeKeybindings module
---@return boolean success True if initialization was successful
function NativeKeybindings.Initialize()
    if _initialized then return true end

    local success, inputManager = pcall(function()
        return Ext.Input.GetInputManager()
    end)

    if not success or not inputManager then
        MCMDebug(1, "Failed to get InputManager in NativeKeybindings.Initialize")
        return false
    end

    _inputManager = inputManager
    _initialized = true
    return true
end

--- Get all native keybindings in a structured format, separated into public and internal keybindings
---@return NativeKeybindingsResult
function NativeKeybindings.GetAll()
    if not _initialized and not NativeKeybindings.Initialize() then
        return { Public = {}, Internal = {} }
    end

    local result = {
        Public = {},
        Internal = {}
    }

    local inputScheme = _inputManager and _inputManager.InputScheme

    if not inputScheme or not inputScheme.InputBindings then
        MCMDebug(1, "InputScheme or InputBindings not available in NativeKeybindings.GetAll")
        return result
    end

    if not _inputManager.InputDefinitions then
        MCMDebug(1, "InputDefinitions not available in NativeKeybindings.GetAll")
        return result
    end

    -- Create a lookup for all bindings
    local allBindings = {}
    local inputBindings = inputScheme.InputBindings[1]
    if inputBindings then
        for eventId, bindings in pairs(inputBindings) do
            -- Convert eventId to number if it's a string
            local numericEventId = tonumber(eventId)
            if numericEventId then
                allBindings[numericEventId] = {}
                for _, binding in ipairs(bindings) do
                    if binding and binding.InputId and binding.InputId ~= "" then
                        table.insert(allBindings[numericEventId], {
                            DeviceId = binding.DeviceId,
                            InputId = binding.InputId,
                            Modifiers = binding.Modifiers or {}
                        })
                    end
                end
            end
        end
    end

    -- Process all input definitions
    for _, def in ipairs(_inputManager.InputDefinitions or {}) do
        local eventId = def.EventID
        -- Ensure we're using the same type for lookup (number)
        local numericEventId = tonumber(eventId) or eventId
        local bindings = allBindings[numericEventId] or {}
        local description = ""
        -- Safely get the description
        if def.EventDesc and type(def.EventDesc.Get) == "function" then
            local success, desc = pcall(def.EventDesc.Get, def.EventDesc)
            if success and type(desc) == "string" then
                description = desc
            end
        end

        local keybinding = {
            CategoryName = def.CategoryName or "",
            EventName = def.EventName or "",
            Description = description,
            Bindings = {},
            Type = def.Type or {}
        }

        -- Add all bindings for this event, tagging them by device type
        for _, binding in ipairs(bindings) do
            local inputType = NativeKeybindings.GetInputTypeForDevice(binding.DeviceId)
            table.insert(keybinding.Bindings, {
                DeviceId = binding.DeviceId,
                InputId = binding.InputId,
                Modifiers = binding.Modifiers,
                InputType = inputType
            })
        end

        -- Determine if this is an internal keybinding
        local isInternal = description:lower():match("%-%s*internal%s*$")

        -- Add to the appropriate result table
        if isInternal then
            table.insert(result.Internal, keybinding)
        else
            table.insert(result.Public, keybinding)
        end
    end

    return result
end

--- Gets the input type string for a given device ID
---@param deviceId integer The device ID to check
---@return string The input type as a string ("Keyboard", "Mouse", "Controller", "Unassigned", or "Unknown")
function NativeKeybindings.GetInputTypeForDevice(deviceId)
    if deviceId == nil then
        return "Unknown"
    end

    if deviceId == DEVICE_TYPE.UNASSIGNED then
        return "Unassigned"
    elseif deviceId == DEVICE_TYPE.MOUSE then
        return "Mouse"
    elseif deviceId >= DEVICE_TYPE.KEYBOARD_MIN and deviceId <= DEVICE_TYPE.KEYBOARD_MAX then
        return "Keyboard"
    elseif deviceId >= DEVICE_TYPE.CONTROLLER_MIN then
        return "Controller"
    end

    return "Unknown"
end

--- Get only keybindings that have at least one binding
---@param keybindings NativeKeybindingsResult
---@return NativeKeybindingsResult
function NativeKeybindings.GetBoundKeybindings(keybindings)
    local result = {
        Public = {},
        Internal = {}
    }

    local function hasBindings(kb)
        return kb and kb.Bindings and #kb.Bindings > 0
    end

    -- Filter public keybindings
    for _, kb in ipairs(keybindings.Public or {}) do
        if hasBindings(kb) then
            table.insert(result.Public, kb)
        end
    end

    -- Filter internal keybindings
    for _, kb in ipairs(keybindings.Internal or {}) do
        if hasBindings(kb) then
            table.insert(result.Internal, kb)
        end
    end

    return result
end

--- Get native keybindings grouped by category, with public and internal keybindings separated
---@return NativeKeybindingsResult
function NativeKeybindings.GetByCategory()
    local keybindings = NativeKeybindings.GetAll()

    local function groupByCategory(kbList)
        local byCategory = {}
        for _, kb in ipairs(kbList) do
            local category = kb.CategoryName or "Uncategorized"
            if not byCategory[category] then
                byCategory[category] = {}
            end
            table.insert(byCategory[category], kb)
        end
        return byCategory
    end

    local result = {
        Public = groupByCategory(keybindings.Public or {}),
        Internal = groupByCategory(keybindings.Internal or {})
    }

    -- Filter out empty categories
    local function filterEmptyCategories(categories)
        local filtered = {}
        for category, bindings in pairs(categories) do
            if #bindings > 0 then
                filtered[category] = bindings
            end
        end
        return filtered
    end

    return {
        Public = filterEmptyCategories(result.Public),
        Internal = filterEmptyCategories(result.Internal)
    }
end

return NativeKeybindings
