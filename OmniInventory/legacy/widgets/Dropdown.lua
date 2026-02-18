local addonName, NS = ...
local Frames = NS.Frames

-- =============================================================================
-- Character Dropdown Logic
-- =============================================================================

-- Create the custom dropdown frame if it doesn't exist
function Frames:CreateDropdownFrame()
    if self.dropdownFrame then return self.dropdownFrame end

    -- 1. Full-screen Overlay (to catch clicks outside)
    local overlay = CreateFrame("Button", "ZenBagsDropdownOverlay", UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetAllPoints()
    overlay:EnableMouse(true)
    overlay:SetScript("OnClick", function()
        self.dropdownFrame:Hide()
    end)
    overlay:Hide()

    -- 2. Dropdown Container
    -- Parent to UIParent, NOT overlay, so we can control visibility independently
    local f = CreateFrame("Frame", "ZenBagsCharacterDropdown", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG") -- Same strata as overlay
    f:SetFrameLevel(overlay:GetFrameLevel() + 10) -- Above overlay
    f:SetSize(200, 100) -- Dynamic height
    f:SetPoint("TOPLEFT", self.charButton, "BOTTOMLEFT", 0, -2)

    NS.Utils:CreateBackdrop(f)
    f:SetBackdropColor(0.12, 0.12, 0.12, 1)
    f:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    f.overlay = overlay
    f.buttons = {}

    -- Sync overlay visibility with dropdown
    f:SetScript("OnShow", function() overlay:Show() end)
    f:SetScript("OnHide", function() overlay:Hide() end)

    self.dropdownFrame = f
    return f
end

-- Populate the dropdown list
function Frames:UpdateDropdownList()
    local f = self:CreateDropdownFrame()
    local chars = NS.Data:GetAvailableCharacters()
    local BUTTON_HEIGHT = 24
    local PADDING = 5

    -- Hide existing buttons
    for _, btn in ipairs(f.buttons) do btn:Hide() end

    local yOffset = -PADDING
    local btnIdx = 1

    for _, charData in ipairs(chars) do
        -- Get or Create Button
        local btn = f.buttons[btnIdx]
        if not btn then
            btn = CreateFrame("Button", nil, f)
            btn:SetSize(190, BUTTON_HEIGHT)

            -- Highlight texture
            local hl = btn:CreateTexture(nil, "BACKGROUND")
            hl:SetAllPoints()
            hl:SetTexture(1, 1, 1, 0.1)
            btn:SetHighlightTexture(hl)

            -- Text
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", 20, 0) -- More padding so dot is inside
            btn.text:SetJustifyH("LEFT")

            -- Current Indicator (Green Dot)
            btn.dot = btn:CreateTexture(nil, "OVERLAY")
            btn.dot:SetSize(6, 6)
            btn.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
            btn.dot:SetVertexColor(0, 1, 0)
            btn.dot:SetPoint("RIGHT", btn.text, "LEFT", -5, 0)

            -- Delete Button (Trash Icon)
            local del = CreateFrame("Button", nil, btn)
            del:SetSize(14, 14)
            del:SetPoint("RIGHT", -5, 0)

            local delIcon = del:CreateTexture(nil, "ARTWORK")
            delIcon:SetAllPoints()
            delIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            delIcon:SetVertexColor(0.7, 0.7, 0.7)
            del.icon = delIcon

            del:SetScript("OnEnter", function(self) self.icon:SetVertexColor(1, 0.2, 0.2) end)
            del:SetScript("OnLeave", function(self) self.icon:SetVertexColor(0.7, 0.7, 0.7) end)

            btn.delBtn = del
            f.buttons[btnIdx] = btn
        end

        -- Configure Button
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, yOffset)
        btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, yOffset)
        btn:Show()

        -- Class colors for text
        local classColors = {
            WARRIOR = {0.78, 0.61, 0.43},
            PALADIN = {0.96, 0.55, 0.73},
            HUNTER = {0.67, 0.83, 0.45},
            ROGUE = {1.00, 0.96, 0.41},
            PRIEST = {1.00, 1.00, 1.00},
            DEATHKNIGHT = {0.77, 0.12, 0.23},
            SHAMAN = {0.00, 0.44, 0.87},
            MAGE = {0.25, 0.78, 0.92},
            WARLOCK = {0.53, 0.53, 0.93},
            DRUID = {1.00, 0.49, 0.04},
        }

        -- Use class and gold from Data:GetAvailableCharacters() (already includes Alts data)
        local charClass = charData.class
        local gold = charData.gold or 0

        -- Format gold display
        local goldStr = ""
        if gold > 0 then
            goldStr = string.format(" |cFFFFD700%dg|r", math.floor(gold / 10000))
        end

        -- Text with gold
        btn.text:SetText(charData.name .. goldStr)

        -- Apply class color
        local color = classColors[charClass] or {0.7, 0.7, 0.7}

        if charData.isCurrent then
            btn.dot:Show()
            btn.text:SetTextColor(color[1], color[2], color[3])
            btn.delBtn:Hide() -- Can't delete current
        else
            btn.dot:Hide()
            btn.text:SetTextColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7) -- Dimmer for others
            btn.delBtn:Show()
        end

        -- Click Handler (Select Character)
        btn:SetScript("OnClick", function()
            if charData.isCurrent then
                NS.Data:SetSelectedCharacter(nil)
            else
                NS.Data:SetSelectedCharacter(charData.key)
            end

            self.charButton.text:SetText(charData.name)
            self.searchBox:SetText("")
            self:Update(true)
            f:Hide()
        end)

        -- Delete Handler
        btn.delBtn:SetScript("OnClick", function()
            -- Define StaticPopup if not already defined
            if not StaticPopupDialogs["ZENBAGS_CONFIRM_DELETE_CHAR"] then
                StaticPopupDialogs["ZENBAGS_CONFIRM_DELETE_CHAR"] = {
                    text = "Are you sure you want to delete the cached data for %s?",
                    button1 = "Delete",
                    button2 = "Cancel",
                    OnAccept = function(self, data)
                        NS.Data:DeleteCharacter(data.key)
                        print("|cFFFF0000ZenBags:|r Deleted data for " .. data.name)

                        -- Refresh list immediately
                        if NS.Frames.UpdateDropdownList then
                            NS.Frames:UpdateDropdownList()
                        end

                        -- Reset view if we deleted the viewed character
                        if NS.Data:GetSelectedCharacter() == nil then
                            NS.Frames.charButton.text:SetText(UnitName("player"))
                            NS.Frames:Update(true)
                        end
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
            end

            -- Show Confirmation
            local dialog = StaticPopup_Show("ZENBAGS_CONFIRM_DELETE_CHAR", charData.name)
            if dialog then
                dialog.data = charData
            end
        end)

        yOffset = yOffset - BUTTON_HEIGHT
        btnIdx = btnIdx + 1
    end

    -- Resize Frame
    f:SetHeight(math.abs(yOffset) + PADDING)
end

-- Show character selection dropdown
function Frames:ShowCharacterDropdown()
    local f = self:CreateDropdownFrame()

    if f:IsShown() then
        f:Hide()
    else
        self:UpdateDropdownList()
        f:Show()
    end
end
