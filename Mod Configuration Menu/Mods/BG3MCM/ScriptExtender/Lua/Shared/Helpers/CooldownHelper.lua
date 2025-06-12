---@class CooldownHelper
CooldownHelper = {}

---Start a countdown-based cooldown on an IMGUI element.
---@param element ExtuiStyledRenderable The IMGUI object (button, window, etc.)
---@param duration number Duration in seconds
---@param onTick function(element:any, remainingSec:number):boolean Called every second; return true to stop early
---@param onComplete function(element:any) Called when cooldown completes
function CooldownHelper:StartCooldown(element, duration, onTick, onComplete)
    if not duration or duration <= 0 then
        if onComplete then onComplete(element) end
        return
    end
    local remaining = math.floor(duration)
    -- initial tick
    onTick(element, remaining)
    local function tick()
        remaining = remaining - 1
        if onTick(element, remaining) then
            return true
        elseif remaining <= 0 then
            if onComplete then onComplete(element) end
            return true
        end
        return false
    end
    VCTimer:CallWithInterval(tick, 1000, duration * 1000)
end

return CooldownHelper
