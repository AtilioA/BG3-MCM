--[[
    This code snippet is from Volition Cabinet. Note that Volition Cabinet is a fork from Focus' Focus Core, and most of this code in particular has been modified very little from the original, and I thank Focus for his work on this.

    MIT License

    Copyright (c) 2024 Volitio

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

---@class Printer: MetaClass
---@field Authorship string
---@field Prefix string
---@field Machine "S"|"C"
---@field Beautify boolean
---@field StringifyInternalTypes boolean
---@field IterateUserdata boolean
---@field AvoidRecursion boolean
---@field LimitArrayElements integer
---@field LimitDepth integer
---@field FontColor vec3
---@field BackgroundColor vec3
---@field ApplyColor boolean
---@field DebugLevel integer
Printer = _Class:Create("Printer", nil, {
    Authorship = "Volitio's",
    Prefix = "Printer",
    Machine = Ext.IsServer() and "S" or "C",
    Beautify = true,
    StringifyInternalTypes = true,
    IterateUserdata = true,
    AvoidRecursion = true,
    LimitArrayElements = 3,
    LimitDepth = 1,
    FontColor = { 192, 192, 192 },
    BackgroundColor = { 12, 12, 12 },
    ApplyColor = false,
    DebugLevel = 0,
})

---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
function Printer:SetFontColor(r, g, b)
    self.FontColor = { r or 0, g or 0, b or 0 }
    --self:Print("Changed Font Color to %s %s %s", r, g, b)
end

---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
function Printer:SetBackgroundColor(r, g, b)
    self.BackgroundColor = { r or 0, g or 0, b or 0 }
    --self:Print("Changed Background Color to %s %s %s", r, g, b)
end

---@param text string
---@param fontColor? vec3 Override the current font color
---@param backgroundColor? vec3 Override the current background color
---@return string
function Printer:Colorize(text, fontColor, backgroundColor)
    local fr, fg, fb = table.unpack(fontColor or self.FontColor)
    local br, bg, bb = table.unpack(backgroundColor or self.BackgroundColor)
    return string.format("\x1b[38;2;%s;%s;%s;48;2;%s;%s;%sm%s", fr, fg, fb, br, bg, bb, text)
end

function Printer:ToggleApplyColor()
    self.ApplyColor = not self.ApplyColor
    self:Print(0, "Applying Color: %s", self.ApplyColor)
end

---@vararg any
function Printer:Print(debugLevel, ...)
    if self.DebugLevel >= (debugLevel and tonumber(debugLevel) or 0) then
        local s
        if self.DebugLevel > 0 then
            s = string.format("[%s][D%s][%s]: ", self.Prefix, debugLevel, self.Machine)
        else
            s = string.format("[%s][%s]: ", self.Prefix, self.Machine)
        end

        if self.ApplyColor then
            s = self:Colorize(s)
        end

        local f
        if #{ ... } <= 1 then
            f = tostring(...)
        else
            f = string.format(...)
        end

        Ext.Utils.Print(s .. f)
    end
end

function Printer:PrintTest(debugLevel, ...)
    if self.DebugLevel >= (debugLevel and tonumber(debugLevel) or 0) then
        local s
        if self.DebugLevel > 1 then
            s = string.format("[%s][%s%s][%s]: ", self.Prefix, "TEST-", debugLevel, self.Machine)
        else
            s = string.format("[%s][%s%s][%s]: ", self.Prefix, "TEST-", debugLevel, self.Machine)
        end

        if self.ApplyColor then
            s = self:Colorize(s)
        end

        local f
        if #{ ... } <= 1 then
            f = tostring(...)
        else
            f = string.format(...)
        end

        Ext.Utils.Print(s .. f)
    end
end

function Printer:PrintWarning(debugLevel, ...)
    if self.DebugLevel >= (debugLevel and tonumber(debugLevel) or 0) then
        local s
        if self.DebugLevel > 1 then
            s = string.format("[%s][%s][%s]: ", self.Prefix, "WARN", self.Machine)
        else
            s = string.format("[%s][%s][%s]: ", self.Prefix, "WARN", self.Machine)
        end

        if self.ApplyColor then
            s = self:Colorize(s)
        end

        local f
        if #{ ... } <= 1 then
            f = tostring(...)
        else
            f = string.format(...)
        end

        Ext.Utils.PrintWarning(s .. f)
    end
end

function Printer:PrintDeprecation(debugLevel, ...)
    if self.DebugLevel >= (debugLevel and tonumber(debugLevel) or 0) then
        local s
        if self.DebugLevel > 1 then
            s = string.format("[%s][%s][%s]: ", self.Prefix, "DEPRECATION", self.Machine)
        else
            s = string.format("[%s][%s][%s]: ", self.Prefix, "DEPRECATION", self.Machine)
        end

        if self.ApplyColor then
            s = self:Colorize(s)
        end

        local f
        if #{ ... } <= 1 then
            f = tostring(...)
        else
            f = string.format(...)
        end

        Ext.Utils.PrintWarning(s .. f)
    end
end

function Printer:PrintDebug(debugLevel, ...)
    if self.DebugLevel >= (debugLevel and tonumber(debugLevel) or 0) then
        local s
        if self.DebugLevel > 1 then
            s = string.format("[%s][%s%s][%s]: ", self.Prefix, "DEBUG-", debugLevel, self.Machine)
        else
            s = string.format("[%s][%s%s][%s]: ", self.Prefix, "DEBUG-", debugLevel, self.Machine)
        end

        if self.ApplyColor then
            s = self:Colorize(s)
        end

        local f
        if #{ ... } <= 1 then
            f = tostring(...)
        else
            f = string.format(...)
        end

        Ext.Utils.Print(s .. f)
    end
end

function Printer:Dump(info, useOptions, includeTime)
    if self.DebugLevel > 0 then
        local s = string.format("[%s][%s][%s]: ", self.Prefix, "DUMP", self.Machine)

        if self.ApplyColor then
            s = self:Colorize(s)
        end

        if includeTime == true then
            s = string.format("%s: ", s)
        end

        s = s .. " "

        local infoString
        if useOptions == true then
            infoString = Ext.Json.Stringify(info, {
                Beautify = self.Beautify,
                StringifyInternalTypes = self.StringifyInternalTypes,
                IterateUserdata = self.IterateUserdata,
                AvoidRecursion = self.AvoidRecursion,
                LimitArrayElements = self.LimitArrayElements,
                LimitDepth = self.LimitDepth,
                MaxDepth = 64
            })
        else
            infoString = Ext.DumpExport(info)
        end
        Ext.Utils.Print(s, infoString)
    end
end

---@param array table
---@param arrayName? string
function Printer:DumpArray(array, arrayName)
    if self.DebugLevel > 0 then
        local name = arrayName or "array"
        for i = 1, #array do
            self:Print(0, "%s[%s]: %s", name, i, array[i])
        end
    end
end

--- VC printers

VCPrinter = Printer:New { Prefix = "VolitionCabinet", ApplyColor = true }
function VCPrint(...)
    VCPrinter:SetFontColor(0, 255, 255)
    VCPrinter:Print(...)
end

function VCTest(...)
    VCPrinter:SetFontColor(100, 200, 150)
    VCPrinter:PrintTest(...)
end

function VCDebug(...)
    VCPrinter:SetFontColor(200, 200, 0)
    VCPrinter:PrintDebug(...)
end

function VCWarn(...)
    VCPrinter:SetFontColor(200, 100, 50)
    VCPrinter:PrintWarning(...)
end

function VCDump(...)
    VCPrinter:SetFontColor(190, 150, 225)
    VCPrinter:Dump(...)
end

function VCDumpArray(...) VCPrinter:DumpArray(...) end
