-- Command registry, used to register and execute commands
CommandRegistry = {}
CommandRegistry.__index = CommandRegistry

function CommandRegistry:new()
    local registry = setmetatable({}, self)
    registry.commands = {}
    return registry
end

function CommandRegistry:register(channel, command)
    self.commands[channel] = command
end

function CommandRegistry:execute(channel, payload, peerId)
    if self.commands[channel] then
        self.commands[channel]:execute(channel, payload, peerId)
    end
end

return CommandRegistry
