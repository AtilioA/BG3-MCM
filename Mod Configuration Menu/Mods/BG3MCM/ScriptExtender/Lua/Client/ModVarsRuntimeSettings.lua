ModVarsRuntimeSettings = {}

local function TitleCase(str)
    -- Convert snake_case or camelCase to Title Case, preserving acronyms
    local result = ""
    local lastChar = " "
    local inAcronym = false

    for i = 1, #str do
        local c = str:sub(i,i)
        local nextChar = str:sub(i+1,i+1)

        if c == "_" then
            result = result .. " "
            lastChar = " "
            inAcronym = false
        elseif lastChar == " " then
            result = result .. c:upper()
            inAcronym = c:upper() == c
        elseif c:upper() == c then
            if not inAcronym and lastChar:upper() ~= lastChar then
                result = result .. " " .. c
            else
                result = result .. c
            end
            inAcronym = nextChar ~= "" and nextChar:upper() == nextChar
        else
            result = result .. c
            inAcronym = false
        end

        lastChar = c
    end

    return result
end

local function RenderModVars(contentGroup, modUUID, vars, path)
    if type(vars) ~= "table" then return end
    path = path or ""

    for key, value in pairs(vars) do
        local keyPath = path == "" and key or (path .. "." .. key)
        local label = TitleCase(key)

        if type(value) == "table" then
            -- Create collapsible group for nested tables
            local group = contentGroup:AddCollapsingHeader(label)
            RenderModVars(group, modUUID, value, keyPath)
        else
            local widget
            if type(value) == "boolean" then
                widget = contentGroup:AddCheckbox(label, value)
                widget.OnChange = function(v)
                    vars = Ext.Vars.GetModVariables(modUUID)
                    _D(string.format("Checkbox changed: %s -> %s", keyPath, v.Checked))
                    for k in keyPath:gmatch("[^%.]+") do
                        vars = vars[k]
                    end
                    vars = v.Checked
                    _DS(vars)
                end
            elseif type(value) == "number" then
                widget = contentGroup:AddInputInt(label, value)
                widget.OnChange = function(v)
                    vars = Ext.Vars.GetModVariables(modUUID)

                    for k in keyPath:gmatch("[^%.]+") do
                        vars = vars[k]
                    end
                    vars = v.Value[1]
                    _DS(vars)
                end
            elseif type(value) == "string" then
                widget = contentGroup:AddInputText(label, value)
                widget.OnChange = function(v)
                    vars = Ext.Vars.GetModVariables(modUUID)
                    _D(string.format("Checkbox changed: %s -> %s", key, v.Text))
                    for k in keyPath:gmatch("[^%.]+") do
                        vars = vars[k]
                    end
                    vars = v.Text
                    _DS(vars)
                end
            end
        end
    end
end

function ModVarsRuntimeSettings.CreateModVarsPage()
    local modVarsUUID = "MCM_MOD_VARS"

    -- Create a dedicated "Mod Variables" menu section via DualPane
    DualPane.leftPane:AddMenuSeparator("Mod Variables")

    -- For each mod in the load order
    for _, modUUID in ipairs(Ext.Mod.GetLoadOrder()) do
        local modInfo = Ext.Mod.GetMod(modUUID)
        local modName = modInfo.Info.Name
        local modButtonUUID = "MOD_VARS_" .. modUUID

        -- 'Convert' C++ object to Lua table
        local vars = {}
        local rawVars = Ext.Vars.GetModVariables(modUUID)
        if rawVars then
            for k, v in pairs(rawVars) do
                vars[k] = v
            end
        end

        if next(vars) ~= nil then
            -- Create a button for this mod
            DualPane.leftPane:CreateMenuButton(modName, nil, modButtonUUID)

            -- Create content group for this mod's variables
            local modGroup = DualPane.contentScrollWindow:AddGroup(modButtonUUID)
            DualPane.rightPane.contentGroups[modButtonUUID] = modGroup

            -- Render the mod's variables recursively
            _D(vars)
            RenderModVars(modGroup, modUUID, vars)
        end
    end
end

-- Create ModVars pages when UI is ready
MCMClientState.UIReady:Subscribe(function(ready)
    if ready then
        ModVarsRuntimeSettings.CreateModVarsPage()
    end
end)
