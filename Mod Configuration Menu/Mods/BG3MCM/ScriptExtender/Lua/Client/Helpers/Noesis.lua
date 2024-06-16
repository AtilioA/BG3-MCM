Noesis = {}

--- Thanks Norbyte for this!
function Noesis:findNoesisElementByName(element, name)
    if not element then
        return nil
    end

    if element:GetProperty("Name") == name then
        return element
    end

    for i = 1, element.VisualChildrenCount do
        local foundElement = self:findNoesisElementByName(element:VisualChild(i), name)
        if foundElement then
            return foundElement
        end
    end

    return nil
end

function Noesis:FindMCMGameMenuButton()
    local target = self:findNoesisElementByName(Ext.UI.GetRoot(), "MCMButton")
    if target then
        MCMDebug(3, target.Type .. " (" .. (target:GetProperty("Name") or "") .. ")")
        return target
    else
        MCMDebug(1, "MCMButton not found")
    end
end
