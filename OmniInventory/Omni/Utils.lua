-- =============================================================================
-- OmniInventory Utilities
-- =============================================================================

local addonName, Omni = ...

Omni.Utils = {}
local Utils = Omni.Utils

-- =============================================================================
-- String Utilities
-- =============================================================================

--- Parse itemID from an item link
---@param link string
---@return number|nil itemID
function Utils:ParseItemID(link)
    if not link then return nil end
    return tonumber(string.match(link, "item:(%d+)"))
end

--- Get quality color for an item
---@param quality number
---@return number r, number g, number b
function Utils:GetQualityColor(quality)
    if not quality or quality < 0 then
        return 0.62, 0.62, 0.62  -- Grey
    end
    local r, g, b = GetItemQualityColor(quality)
    return r or 1, g or 1, b or 1
end

--- Format money as gold/silver/copper
---@param copper number
---@return string formatted
function Utils:FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    local formattedGold = tostring(gold):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

    if gold > 0 then
        return string.format("%sg %ds %dc", formattedGold, silver, cop)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, cop)
    else
        return string.format("%dc", cop)
    end
end

-- =============================================================================
-- Frame Utilities
-- =============================================================================

--- Create a simple backdrop for a frame
---@param frame table
---@param r number|nil
---@param g number|nil
---@param b number|nil
---@param a number|nil
function Utils:CreateBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, a or 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

--- Create a flat button with text
---@param parent table
---@param text string
---@param width number
---@param height number
---@param onClick function
---@return table button
function Utils:CreateFlatButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    Utils:CreateBackdrop(btn, 0.15, 0.15, 0.15, 1)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.25, 1)
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 1)
    end)

    btn:SetScript("OnClick", onClick)

    return btn
end

--- Create a close button
---@param parent table
---@return table button
function Utils:CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)

    btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    btn:GetNormalTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)

    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    btn:GetHighlightTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)

    btn:SetScript("OnClick", function()
        parent:Hide()
    end)

    return btn
end

-- =============================================================================
-- Table Utilities
-- =============================================================================

--- Deep copy a table
---@param orig table
---@return table copy
function Utils:DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in next, orig, nil do
            copy[Utils:DeepCopy(k)] = Utils:DeepCopy(v)
        end
        setmetatable(copy, Utils:DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

--- Merge two tables (second overwrites first)
---@param t1 table
---@param t2 table
---@return table merged
function Utils:MergeTables(t1, t2)
    local result = Utils:DeepCopy(t1)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = Utils:MergeTables(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

print("|cFF00FF00OmniInventory|r: Utilities loaded")
