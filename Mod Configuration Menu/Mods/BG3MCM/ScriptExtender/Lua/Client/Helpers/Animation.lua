Animation = {}

-- Linear interpolation
function Animation.Lerp(a, b, t)
    return a + (b - a) * t
end

-- Ease Out Quad (starts fast, slows down at the end)
function Animation.EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

return Animation
