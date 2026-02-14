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
---@field DeviceId? integer
---@field InputType string
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

    local inputScheme = Ext.Input.GetInputManager().InputScheme

    -- TODO: use RawToBinding to complement since InputBindings seems incomplete
    if not inputScheme or not inputScheme.InputBindings then
        MCMDebug(1, "InputScheme or InputBindings not available in NativeKeybindings.GetAll")
        return result
    end

    if not Ext.Input.GetInputManager().InputDefinitions then
        MCMDebug(1, "InputDefinitions not available in NativeKeybindings.GetAll")
        return result
    end

    --- Processes a single binding and validates it
    ---@param binding table The binding to process
    ---@return table|nil The processed binding or nil if invalid
    local function processBinding(binding)
        if not binding or not binding.InputId or binding.InputId == "" then
            return nil
        end

        return {
            DeviceId = binding.DeviceId,
            InputId = binding.InputId,
            Modifiers = binding.Modifiers or {}
        }
    end

    --- Safely gets the description from an input definition
    ---@param def InputDefinition
    ---@return string
    local function getDefinitionDescription(def)
        if not def.EventDesc or type(def.EventDesc.Get) ~= "function" then
            return ""
        end

        local success, desc = pcall(def.EventDesc.Get, def.EventDesc)
        return success and type(desc) == "string" and desc or ""
    end

    -- Get the input bindings
    local inputBindings = inputScheme.InputBindings[1]
    if not inputBindings then
        MCMDebug(1, "No input bindings found in NativeKeybindings.GetAll")
        return result
    end

    --- Extract bindings for a given input definition
    ---@param def InputDefinition
    ---@return NativeKeybindingBinding[]
    local function extractBindings(def)
        local eventId = tostring(def.EventID)
        local eventBindings = inputBindings[eventId] or {}
        local bindings = {}
        for _, binding in ipairs(eventBindings) do
            local processed = processBinding(binding)
            if processed then
                table.insert(bindings, processed)
            end
        end
        return bindings
    end

    -- Process all input definitions
    for _, def in ipairs(Ext.Input.GetInputManager().InputDefinitions or {}) do
        local bindings = extractBindings(def)

        local description = getDefinitionDescription(def)

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

    NativeKeybindings.SortKeybindings(result.Public)
    NativeKeybindings.SortKeybindings(result.Internal)

    return result
end

--- Sort helper
function NativeKeybindings.SortKeybindings(list)
    table.sort(list, function(a, b)
        local catA = a.CategoryName or ""
        local catB = b.CategoryName or ""
        if catA == catB then
            local eventA = a.EventName or ""
            local eventB = b.EventName or ""
            return VCString.NaturalOrderCompare(eventA, eventB)
        else
            return VCString.NaturalOrderCompare(catA, catB)
        end
    end)
end

--- Gets the input type string for a given device ID
---@param deviceId integer The device ID to check
---@return string - The input type as a string ("Keyboard", "Mouse", "Controller", "Unassigned", or "Unknown")
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
            -- LOCA TODO
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

--- Get keybindings filtered by device type, with public and internal keybindings separated
---@param deviceType string|nil The device type to filter by ("Keyboard", "Mouse", "Controller", "Unassigned", or "Unknown").
---@return {Public: NativeKeybinding[], Internal: NativeKeybinding[]}
function NativeKeybindings.GetByDeviceType(deviceType)
    local allKeybindings = NativeKeybindings.GetAll()
    local result = {
        Public = {},
        Internal = {}
    }

    local function matchesDeviceType(binding, targetType)
        local bindingType = binding.InputType
        return bindingType == targetType or
            (targetType == "Unassigned" and bindingType == "Unknown")
    end

    -- Process all keybindings
    for _, kb in ipairs(allKeybindings.Public) do
        local filtered = {
            CategoryName = kb.CategoryName,
            EventName = kb.EventName,
            Description = kb.Description,
            Type = kb.Type,
            Bindings = {}
        }

        for _, binding in ipairs(kb.Bindings) do
            if not deviceType or matchesDeviceType(binding, deviceType) then
                table.insert(filtered.Bindings, binding)
            end
        end

        if #filtered.Bindings > 0 then
            table.insert(result.Public, filtered)
        end
    end

    for _, kb in ipairs(allKeybindings.Internal) do
        local filtered = {
            CategoryName = kb.CategoryName,
            EventName = kb.EventName,
            Description = kb.Description,
            Type = kb.Type,
            Bindings = {}
        }

        for _, binding in ipairs(kb.Bindings) do
            if not deviceType or matchesDeviceType(binding, deviceType) then
                table.insert(filtered.Bindings, binding)
            end
        end

        if #filtered.Bindings > 0 then
            table.insert(result.Internal, filtered)
        end
    end

    return result
end

return NativeKeybindings
