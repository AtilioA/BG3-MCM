RequireFiles("Client/", {
    "Components/_Init",
    "Helpers/_Init",
    "IMGUILayer",
    "IMGUIAPI",
    "SubscribedEvents",
})

IMGUILayer.CreateMainIMGUIWindow()

-- Insert a new tab now that the MCM is ready (JUST A DEMONSTRATION)
if Config:getCfg().DEBUG.level > 1 then
    IMGUIAPI:InsertModMenuTab(ModuleUUID, "Inserted tab", function(tabHeader)
        local myCustomWidget = tabHeader:AddButton("My Custom Widget")
        myCustomWidget.OnClick = function()
            _D("My custom widget was clicked!")
        end
    end)
end
