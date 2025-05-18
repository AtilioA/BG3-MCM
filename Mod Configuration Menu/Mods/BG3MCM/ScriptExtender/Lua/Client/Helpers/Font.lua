Font = {}

FONT_SIZE_OPTIONS = {
    "Tiny",
    "Small",
    "Medium",
    "Default",
    "Large",
    "Big"
}

function Font.GetFontSizeOptions()
    return FONT_SIZE_OPTIONS
end

function Font.IsValidFontSize(fontSize)
    if fontSize == nil then
        return false
    end

    return table.contains(FONT_SIZE_OPTIONS, fontSize)
end

function Font.GetBiggerFontSize(fontSize, steps)
    if not Font.IsValidFontSize(fontSize) then
        return nil
    end

    steps = steps or 1
    local currentIndex = table.indexOf(FONT_SIZE_OPTIONS, fontSize)
    local targetIndex = math.min(currentIndex + steps, #FONT_SIZE_OPTIONS)

    return FONT_SIZE_OPTIONS[targetIndex]
end

function Font.GetSmallerFontSize(fontSize, steps)
    if not Font.IsValidFontSize(fontSize) then
        return nil
    end

    steps = steps or 1
    local currentIndex = table.indexOf(FONT_SIZE_OPTIONS, fontSize)
    local targetIndex = math.max(currentIndex - steps, 1)

    return FONT_SIZE_OPTIONS[targetIndex]
end
