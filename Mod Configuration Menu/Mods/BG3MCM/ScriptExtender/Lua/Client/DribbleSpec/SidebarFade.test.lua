D.describe("Sidebar fade", { tags = { "sidebar_fade", "client", "unit" } }, function()
    ---@param ctx table DribbleSpec test context
    ---@param opacity number
    ---@return DualPaneController controller
    ---@return table clock
    local function fixture(ctx, opacity)
        local clock = { now = 0, callbacks = {} }
        -- bg3-lint: allow BG3-ENGINE-WRITE -- isolate the shared timer clock for deterministic tests
        ctx.stub(Ext.Timer, "MonotonicTime", function() return clock.now end)
        -- bg3-lint: allow BG3-ENGINE-WRITE -- queue timer callbacks under test control
        ctx.stub(Ext.Timer, "WaitFor", function(_, callback)
            table.insert(clock.callbacks, callback)
        end)
        ctx.stub(MCMAPI, "GetSettingValue", function() return true end)
        local window = { alpha = opacity, Visible = true, writes = 0, StatusFlags = {} }
        function window:GetStyle() return self.alpha end
        function window:SetStyle(_, value) self.alpha = value; self.writes = self.writes + 1 end
        local controller = setmetatable({
            menuScrollChildWindow = window,
            rightPane = { IsCurrentModDetached = function() return false end },
            windowOpacity = opacity,
            isHovered = false,
            userHasInteracted = true,
        }, DualPaneController)
        return controller, clock
    end

    ---@param clock table
    local function runNext(clock)
        local callback = table.remove(clock.callbacks, 1)
        callback()
    end

    D.test("hovered fade does not dim", function(ctx)
        local controller, clock = fixture(ctx, 1)
        controller.isHovered = true
        controller:FadeSidebarOutAlpha(5)
        D.expect(controller.menuScrollChildWindow.alpha).toBe(1)
        D.expect(controller.menuScrollChildWindow.writes).toBe(0)
        D.expect(#clock.callbacks).toBe(0)
    end)

    D.test("new activity invalidates old fade steps", function(ctx)
        local controller, clock = fixture(ctx, 1)
        controller:FadeSidebarOutAlpha(5)
        controller:HoldSidebar("folderName", true)
        local writes = controller.menuScrollChildWindow.writes
        controller.isHovered = false
        clock.now = 2500
        runNext(clock)
        D.expect(controller.menuScrollChildWindow.alpha).toBe(1)
        D.expect(controller.menuScrollChildWindow.writes).toBe(writes)
    end)

    D.test("activity invalidates delayed drag fade after release", function(ctx)
        local controller, clock = fixture(ctx, 1)
        ctx.stub(controller, "ScheduleAutoCollapse", function(self) self:CancelAutoCollapse() end)
        controller:HoldSidebar("drag", true)
        controller:HoldSidebar("drag", false)
        controller:HoldSidebar("folderName", true)
        controller:HoldSidebar("folderName", false)
        local writes = controller.menuScrollChildWindow.writes
        runNext(clock)
        D.expect(controller.menuScrollChildWindow.writes).toBe(writes)
    end)

    ---@param ctx table DribbleSpec test context
    ---@param controller DualPaneController
    ---@return table counts
    local function countCollapseStarts(ctx, controller)
        local counts = { scheduled = 0 }
        ctx.stub(controller, "ScheduleAutoCollapse", function(self)
            self:CancelAutoCollapse()
            counts.scheduled = counts.scheduled + 1
        end)
        return counts
    end

    D.test("blocked hover waits for the pointer to leave the rectangle", function(ctx)
        local controller, clock = fixture(ctx, 0.5)
        local counts = countCollapseStarts(ctx, controller)
        local window = controller.menuScrollChildWindow
        window.StatusFlags = { "Visible", "HoveredRect" }
        controller:_startLeaveCountdown()
        runNext(clock)
        D.expect(counts.scheduled).toBe(0)
        D.expect(window.alpha).toBe(0.5)
        window.StatusFlags = { "Visible" }
        runNext(clock)
        D.expect(counts.scheduled).toBe(1)
    end)

    D.test("hover enter cancels the wait for the pointer to leave", function(ctx)
        local controller, clock = fixture(ctx, 1)
        local counts = countCollapseStarts(ctx, controller)
        controller.menuScrollChildWindow.StatusFlags = { "HoveredRect" }
        controller:_startLeaveCountdown()
        controller:CancelAutoCollapse()
        controller.menuScrollChildWindow.StatusFlags = {}
        runNext(clock)
        D.expect(counts.scheduled).toBe(0)
        D.expect(#clock.callbacks).toBe(0)
    end)

    D.test("a pointer returning under a popup stops the fade at configured opacity", function(ctx)
        local controller, clock = fixture(ctx, 0.5)
        local window = controller.menuScrollChildWindow
        countCollapseStarts(ctx, controller)
        controller:FadeSidebarOutAlpha(5)
        clock.now = 2500
        runNext(clock)
        D.expect(window.alpha < 0.5).toBe(true)
        window.StatusFlags = { "HoveredRect" }
        runNext(clock)
        D.expect(window.alpha).toBe(0.5)
    end)

    D.test("leave fades from current alpha to scaled target", function(ctx)
        local controller, clock = fixture(ctx, 0.5)
        controller.menuScrollChildWindow.alpha = 0.45
        controller:FadeSidebarOutAlpha(5)
        D.expect(controller.menuScrollChildWindow.alpha).toBe(0.45)
        clock.now = 5000
        runNext(clock)
        D.expect(math.abs(controller.menuScrollChildWindow.alpha - 0.165) < 0.000001).toBe(true)
        D.expect(#clock.callbacks).toBe(0)
    end)
end)
