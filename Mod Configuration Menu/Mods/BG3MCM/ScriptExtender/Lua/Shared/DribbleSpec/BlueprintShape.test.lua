D.describe("BlueprintShape isolated traversal", { tags = { "blueprint-shape", "unit" } }, function()
    D.beforeEach(function(ctx)
        ctx.stub(BlueprintCache, "GetOrBuild", function(_, root, build) return build(root) end)
    end)

    D.test("indexes settings in order with container paths", function()
        local first, second, anonymous = { Id = "root" }, { Id = "nested" }, {}
        local root = { Settings = { first }, Sections = {
            { SectionId = "section", Tabs = { { TabId = "tab", Settings = { second, anonymous } } } },
        } }
        local ordered = BlueprintShape:GetAllSettingsOrdered(root)
        D.expect(#ordered).toBe(3)
        D.expect(ordered[1]).toBe(first)
        D.expect(ordered[2]).toBe(second)
        D.expect(ordered[3]).toBe(anonymous)
        D.expect(BlueprintShape:HasAnySettings(root)).toBe(true)
        D.expect(BlueprintShape:IsSettingId(root, "nested")).toBe(true)
        D.expect(BlueprintShape:IsSettingId(root, "missing")).toBe(false)
        D.expect(BlueprintShape:GetSettingById(root, "nested")).toBe(second)
        local path = BlueprintShape:GetPathForSetting(root, "nested")
        D.expect(#path).toBe(2)
        D.expect(path[1]).toBe("section")
        D.expect(path[2]).toBe("tab")
        D.expect(BlueprintShape:GetPathForSetting(root, "missing")).toBe(nil)
        local all = BlueprintShape:GetAllSettings(root)
        D.expect(all.root).toBe(first)
        D.expect(all.nested).toBe(second)
    end)

    D.test("traverses sections and tabs and handles empty containers", function()
        local section = { SectionId = "s" }
        local nested = { TabId = "inner", Sections = { section } }
        local tab = { TabId = "outer", Tabs = { nested } }
        local root = { Tabs = { tab } }
        local tabs, sections, elements = {}, {}, {}
        BlueprintShape:ForEachTab(root, function(value) table.insert(tabs, value) end)
        BlueprintShape:ForEachSection(root, function(value) table.insert(sections, value) end)
        BlueprintShape:ForEachElement(root, function(_, kind) table.insert(elements, kind) end)
        D.expect(#tabs).toBe(2)
        D.expect(tabs[2]).toBe(nested)
        D.expect(#sections).toBe(1)
        D.expect(sections[1]).toBe(section)
        D.expect(#elements).toBe(4)
        D.expect(elements[1]).toBe("blueprint")
        D.expect(elements[4]).toBe("section")
        D.expect(BlueprintShape:HasAnySettings(root)).toBe(false)
    end)

    D.test("uses accessors and preserves siblings when writing values", function()
        local setting = { GetId = function() return "choice" end, GetDefault = function() return false end }
        local root = { GetSettings = function() return { setting } end }
        D.expect(BlueprintShape:RetrieveDefaultValueForSetting(root, "choice")).toBe(false)
        D.expect(BlueprintShape:GetSettingById(root, "choice")).toBe(setting)
        local output = { a = { sibling = 7 } }
        BlueprintShape:SetNestedSettingValue(output, { "a", "b" }, "choice", false)
        D.expect(output.a.sibling).toBe(7)
        D.expect(output.a.b.choice).toBe(false)
    end)
    D.test("handles absent elements and accessor results", function()
        D.expect(#BlueprintShape:GetTabs(nil)).toBe(0)
        D.expect(#BlueprintShape:GetSections(nil)).toBe(0)
        D.expect(#BlueprintShape:GetSettings(nil)).toBe(0)
        local tab, section = {}, {}
        local root = { GetTabs = function() return { tab } end, GetSections = function() return { section } end }
        D.expect(BlueprintShape:GetTabs(root)[1]).toBe(tab)
        D.expect(BlueprintShape:GetSections(root)[1]).toBe(section)
        D.expect(#BlueprintShape:GetTabs({ GetTabs = function() return nil end })).toBe(0)
        D.expect(#BlueprintShape:GetSections({ GetSections = function() return nil end })).toBe(0)
        D.expect(BlueprintShape:RetrieveDefaultValueForSetting({}, "missing")).toBe(nil)
    end)

    D.test("visits tabs in sections and sections in sections", function()
        local setting = { Id = "leaf" }
        local leaf = { SectionId = "leaf-section", Settings = { setting } }
        local innerTab = { TabId = "inner" }
        local root = { Sections = { { SectionId = "", Sections = { leaf }, Tabs = { innerTab } } } }
        local tabs, sections, settings, kinds = {}, {}, {}, {}
        BlueprintShape:ForEachTab(root, function(v) table.insert(tabs, v) end)
        BlueprintShape:ForEachSection(root, function(v) table.insert(sections, v) end)
        BlueprintShape:ForEachSetting(root, function(v) table.insert(settings, v) end)
        BlueprintShape:ForEachElement(root, function(_, kind) table.insert(kinds, kind) end)
        D.expect(#tabs).toBe(1)
        D.expect(tabs[1]).toBe(innerTab)
        D.expect(#sections).toBe(2)
        D.expect(sections[2]).toBe(leaf)
        D.expect(settings[1]).toBe(setting)
        D.expect(kinds[4]).toBe("setting")
        local path = BlueprintShape:GetPathForSetting(root, "leaf")
        D.expect(#path).toBe(1)
        D.expect(path[1]).toBe("leaf-section")
    end)
    D.test("visits tabs inside a tab section and delegates invalidation", function(ctx)
        local nested = { TabId = "nested" }
        local root = { Tabs = { { Sections = { { Tabs = { nested } } } } } }
        local tabs = {}
        BlueprintShape:ForEachTab(root, function(tab) table.insert(tabs, tab) end)
        D.expect(#tabs).toBe(2)
        D.expect(tabs[2]).toBe(nested)
        local calls = 0
        ctx.stub(BlueprintCache, "InvalidateAll", function() calls = calls + 1 end)
        BlueprintShape:InvalidateCache()
        D.expect(calls).toBe(1)
    end)
end)
