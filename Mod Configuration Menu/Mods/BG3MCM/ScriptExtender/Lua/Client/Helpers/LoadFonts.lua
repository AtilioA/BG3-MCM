local fontPath = "Mods/BG3MCM/Assets/Fonts/"

for k, s in pairs(Font.FONT_SIZE_OPTIONS) do
    Ext.IMGUI.LoadFont("OpenDyslexic" .. k, fontPath .. "OpenDyslexic/OpenDyslexic.ttf", s)
    Ext.IMGUI.LoadFont("Inter-Regular" .. k, fontPath .. "Inter/Inter-Regular.ttf", s)
end
