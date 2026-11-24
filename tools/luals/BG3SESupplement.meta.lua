---@meta

-- Verified BG3SE runtime API gaps still missing from upstream ExtIdeHelpers.lua.

---@alias GUIDSTRING string

---@class Ext_Utils
---@field MonotonicTime fun(): int64

---@class NoesisCustomEvent
---@field SetHandler fun(self: NoesisCustomEvent, handler: fun(...))

---@class NoesisBaseComponent
---@field Name string
---@field DataContext NoesisBaseComponent?
---@field CustomEvent NoesisCustomEvent

---@class Ext
---@field RegisterModEvent fun(modDirectory: string, channel: string)
---@field _Internal { EventManager: { NetListeners: table<string, function[]> } }

---@class Ext_ClientNet
---@field CreateChannel fun(moduleUUID: string, name: string): NetChannel

---@class Ext_ServerNet
---@field CreateChannel fun(moduleUUID: string, name: string): NetChannel

-- ExtIdeHelpers types AddSlider and AddDrag as returning ExtuiSlider and ExtuiDrag, which it never defines; the runtime types are SliderScalar and DragScalar.
---@alias ExtuiSlider ExtuiSliderScalar
---@alias ExtuiDrag ExtuiDragScalar
