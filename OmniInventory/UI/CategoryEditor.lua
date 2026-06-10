local addonName, Omni = ...

Omni.CategoryEditor = {}
local Editor = Omni.CategoryEditor

local editorFrame = nil
local rows = {}
local ruleRows = {}

local function TrimCategoryName(name)
    name = tostring(name or "")
    return (string.gsub(name, "^%s*(.-)%s*$", "%1"))
end

local function RefreshInventory(reason)
    if Omni.Frame and Omni.Frame.InvalidateRenderCaches then
        Omni.Frame:InvalidateRenderCaches()
    end
    if Omni.Frame and Omni.Frame.IsShown and Omni.Frame:IsShown() and Omni.Frame.UpdateLayout then
        Omni.Frame:UpdateLayout(nil, { forceFull = true, reason = reason or "category_edit" })
    end
    if Omni.Settings and Omni.Settings.RefreshCategoryOrderControls then
        Omni.Settings:RefreshCategoryOrderControls()
    end
end

local function GetOverrideCategory(itemID)
    if not itemID or not OmniInventoryDB or not OmniInventoryDB.categoryOverrides then
        return nil
    end
    return OmniInventoryDB.categoryOverrides[itemID]
end

local function GetItemName(itemInfo)
    if not itemInfo then return "Unknown Item" end
    if itemInfo.hyperlink then
        local name = GetItemInfo(itemInfo.hyperlink)
        if name then return name end
    end
    return "Item " .. tostring(itemInfo.itemID or "?")
end

local function GetItemNameByID(itemID, itemLookup)
    local itemInfo = itemLookup and itemLookup[itemID]
    if itemInfo and itemInfo.__displayName then
        return itemInfo.__displayName
    end
    local lookupID = tonumber(itemID) or itemID
    local name = GetItemInfo(lookupID)
    return name or ("Item " .. tostring(itemID or "?"))
end

local function BuildUniqueBagItems(categoryName)
    local source = OmniC_Container and OmniC_Container.GetAllBagItems and OmniC_Container.GetAllBagItems() or {}
    local items = {}
    local seen = {}

    for _, itemInfo in ipairs(source) do
        local itemID = itemInfo.itemID
        if itemID and not seen[itemID] then
            seen[itemID] = true
            if Omni.Categorizer then
                if Omni.Categorizer.GetAutomaticCategory then
                    itemInfo.__automaticCategory = Omni.Categorizer:GetAutomaticCategory(itemInfo)
                end
                itemInfo.category = Omni.Categorizer:GetCategory(itemInfo)
            end
            itemInfo.__displayName = GetItemName(itemInfo)
            items[#items + 1] = itemInfo
        end
    end

    table.sort(items, function(a, b)
        local aInCategory = a.category == categoryName
        local bInCategory = b.category == categoryName
        if aInCategory ~= bInCategory then
            return aInCategory
        end
        return tostring(a.__displayName or "") < tostring(b.__displayName or "")
    end)
    return items
end

local function BuildCategoryRules(categoryName, items, isUserCategory)
    local rules = {}
    local itemLookup = {}
    local seenManual = {}

    for _, itemInfo in ipairs(items or {}) do
        if itemInfo.itemID then
            itemLookup[itemInfo.itemID] = itemInfo
        end
    end

    if Omni.Categorizer and Omni.Categorizer.GetCategoryRuleDescriptions then
        for _, description in ipairs(Omni.Categorizer:GetCategoryRuleDescriptions(categoryName) or {}) do
            rules[#rules + 1] = {
                type = "Built-in",
                detail = description,
            }
        end
    end

    for _, itemInfo in ipairs(items or {}) do
        local itemID = itemInfo.itemID
        local override = GetOverrideCategory(itemID)
        if itemID and override then
            if override == categoryName then
                rules[#rules + 1] = {
                    type = "Include",
                    detail = GetItemNameByID(itemID, itemLookup),
                    itemID = itemID,
                }
                seenManual[itemID] = true
            elseif itemInfo.__automaticCategory == categoryName then
                rules[#rules + 1] = {
                    type = "Exclude",
                    detail = GetItemNameByID(itemID, itemLookup) .. " -> " .. override,
                    itemID = itemID,
                }
                seenManual[itemID] = true
            end
        end
    end

    if OmniInventoryDB and OmniInventoryDB.categoryOverrides then
        for itemID, override in pairs(OmniInventoryDB.categoryOverrides) do
            if override == categoryName and not seenManual[itemID] then
                rules[#rules + 1] = {
                    type = "Include",
                    detail = GetItemNameByID(itemID, itemLookup),
                    itemID = itemID,
                }
            end
        end
    end

    if #rules == 0 then
        rules[1] = {
            type = "Info",
            detail = isUserCategory and "Add items below to create exact item rules."
                or "No visible rules for this category.",
        }
    end

    return rules
end

local function EnsureStaticPopups()
    StaticPopupDialogs["OMNI_NEW_USER_CATEGORY"] = StaticPopupDialogs["OMNI_NEW_USER_CATEGORY"] or {
        text = "New category name:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(self)
            local name = TrimCategoryName(self.editBox:GetText())
            if name ~= "" and Omni.Categorizer and Omni.Categorizer.CreateUserCategory then
                local created = Omni.Categorizer:CreateUserCategory(name)
                if created then
                    RefreshInventory("category_create")
                    Editor:Open(created)
                end
            end
        end,
    }
end

function Editor:PromptNewCategory()
    EnsureStaticPopups()
    StaticPopup_Show("OMNI_NEW_USER_CATEGORY")
end

function Editor:CreateFrame()
    if editorFrame then return editorFrame end

    editorFrame = CreateFrame("Frame", "OmniCategoryEditor", UIParent)
    editorFrame:SetSize(620, 560)
    editorFrame:SetPoint("CENTER")
    editorFrame:SetFrameStrata("DIALOG")
    editorFrame:EnableMouse(true)
    editorFrame:SetMovable(true)
    editorFrame:SetClampedToScreen(true)
    editorFrame:RegisterForDrag("LeftButton")
    editorFrame:SetScript("OnDragStart", editorFrame.StartMoving)
    editorFrame:SetScript("OnDragStop", editorFrame.StopMovingOrSizing)
    editorFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = editorFrame:CreateTexture(nil, "ARTWORK")
    title:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    title:SetSize(320, 64)
    title:SetPoint("TOP", 0, 12)

    editorFrame.titleText = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editorFrame.titleText:SetPoint("TOP", title, "TOP", 0, -14)
    editorFrame.titleText:SetText("Category Editor")

    local closeBtn = CreateFrame("Button", nil, editorFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local nameLabel = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 24, -42)
    nameLabel:SetText("Category:")

    editorFrame.nameEdit = CreateFrame("EditBox", nil, editorFrame, "InputBoxTemplate")
    editorFrame.nameEdit:SetSize(170, 22)
    editorFrame.nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    editorFrame.nameEdit:SetAutoFocus(false)
    editorFrame.nameEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    editorFrame.nameEdit:SetScript("OnEditFocusLost", function(self)
        if not Editor.selectedCategory or not Omni.Categorizer or not Omni.Categorizer.RenameUserCategory then
            return
        end
        local newName = TrimCategoryName(self:GetText())
        if newName == "" or newName == Editor.selectedCategory then
            self:SetText(Editor.selectedCategory)
            return
        end
        if Omni.Categorizer:RenameUserCategory(Editor.selectedCategory, newName) then
            Editor.selectedCategory = newName
            RefreshInventory("category_rename")
            Editor:Refresh()
        else
            self:SetText(Editor.selectedCategory)
            print("|cFFFF4040OmniInventory|r: Category name is already used.")
        end
    end)

    editorFrame.newBtn = CreateFrame("Button", nil, editorFrame, "UIPanelButtonTemplate")
    editorFrame.newBtn:SetSize(92, 22)
    editorFrame.newBtn:SetPoint("LEFT", editorFrame.nameEdit, "RIGHT", 12, 0)
    editorFrame.newBtn:SetText("New")
    editorFrame.newBtn:SetScript("OnClick", function() Editor:PromptNewCategory() end)

    editorFrame.deleteBtn = CreateFrame("Button", nil, editorFrame, "UIPanelButtonTemplate")
    editorFrame.deleteBtn:SetSize(92, 22)
    editorFrame.deleteBtn:SetPoint("LEFT", editorFrame.newBtn, "RIGHT", 6, 0)
    editorFrame.deleteBtn:SetText("Delete")
    editorFrame.deleteBtn:SetScript("OnClick", function()
        if Editor.selectedCategory and Omni.Categorizer and Omni.Categorizer.DeleteUserCategory
                and Omni.Categorizer:DeleteUserCategory(Editor.selectedCategory) then
            Editor.selectedCategory = nil
            RefreshInventory("category_delete")
            editorFrame:Hide()
        end
    end)

    editorFrame.hint = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editorFrame.hint:SetPoint("TOPLEFT", 24, -72)
    editorFrame.hint:SetPoint("RIGHT", -24, 0)
    editorFrame.hint:SetJustifyH("LEFT")
    editorFrame.hint:SetText("Rules are saved as exact item overrides. Add or remove current bag items below.")

    editorFrame.rulesLabel = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editorFrame.rulesLabel:SetPoint("TOPLEFT", 24, -102)
    editorFrame.rulesLabel:SetText("Category Rules")

    local ruleScroll = CreateFrame("ScrollFrame", "OmniCategoryEditorRuleScroll", editorFrame, "UIPanelScrollFrameTemplate")
    ruleScroll:SetPoint("TOPLEFT", 24, -122)
    ruleScroll:SetSize(544, 104)

    local ruleChild = CreateFrame("Frame", nil, ruleScroll)
    ruleChild:SetSize(520, 1)
    ruleScroll:SetScrollChild(ruleChild)
    editorFrame.ruleChild = ruleChild

    editorFrame.itemsLabel = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editorFrame.itemsLabel:SetPoint("TOPLEFT", 24, -242)
    editorFrame.itemsLabel:SetText("Current Bag Items")

    local scroll = CreateFrame("ScrollFrame", "OmniCategoryEditorItemScroll", editorFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -262)
    scroll:SetPoint("BOTTOMRIGHT", -46, 24)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(520, 1)
    scroll:SetScrollChild(child)
    editorFrame.itemChild = child

    editorFrame:Hide()
    return editorFrame
end

function Editor:Open(categoryName)
    if not editorFrame then self:CreateFrame() end
    self.selectedCategory = TrimCategoryName(categoryName)
    self:Refresh()
    editorFrame:Show()
end

function Editor:Toggle(categoryName)
    if not editorFrame then self:CreateFrame() end
    if editorFrame:IsShown() and (not categoryName or categoryName == self.selectedCategory) then
        editorFrame:Hide()
        return
    end
    self:Open(categoryName or self.selectedCategory or "Miscellaneous")
end

function Editor:Refresh()
    if not editorFrame then return end

    local category = self.selectedCategory or "Miscellaneous"
    local isUserCategory = Omni.Categorizer and Omni.Categorizer.IsUserCategory
        and Omni.Categorizer:IsUserCategory(category)

    editorFrame.titleText:SetText("Edit: " .. category)
    editorFrame.nameEdit:SetText(category)
    editorFrame.nameEdit:EnableMouse(isUserCategory == true)
    editorFrame.nameEdit:SetTextColor(isUserCategory and 1 or 0.65, isUserCategory and 1 or 0.65, isUserCategory and 1 or 0.65)
    editorFrame.deleteBtn:EnableMouse(isUserCategory == true)
    editorFrame.deleteBtn:SetAlpha(isUserCategory and 1 or 0.45)
    editorFrame.hint:SetText(isUserCategory
        and "User categories are exact item rules. Add or clear item rules below."
        or "Built-in rules are listed first. Add or remove items below to customize this category.")

    local items = BuildUniqueBagItems(category)
    local rules = BuildCategoryRules(category, items, isUserCategory == true)
    local ruleChild = editorFrame.ruleChild
    local ruleHeight = 32
    local child = editorFrame.itemChild
    local rowHeight = 26

    for _, row in ipairs(ruleRows) do row:Hide() end
    for _, row in ipairs(rows) do row:Hide() end

    for i, ruleInfo in ipairs(rules) do
        local row = ruleRows[i]
        if not row then
            row = CreateFrame("Frame", nil, ruleChild)
            row:SetSize(520, ruleHeight)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")

            row.ruleType = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.ruleType:SetPoint("LEFT", 6, 0)
            row.ruleType:SetWidth(70)
            row.ruleType:SetJustifyH("LEFT")

            row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.detail:SetPoint("LEFT", row.ruleType, "RIGHT", 8, 0)
            row.detail:SetWidth(330)
            row.detail:SetJustifyH("LEFT")

            row.action = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.action:SetSize(78, 20)
            row.action:SetPoint("RIGHT", -4, 0)
            row.action:SetText("Clear")
            row.action:SetScript("OnClick", function(self)
                local info = self:GetParent().ruleInfo
                if not info or not info.itemID or not Omni.Categorizer then return end
                Omni.Categorizer:ClearManualOverride(info.itemID)
                RefreshInventory("category_rule_clear")
                Editor:Refresh()
            end)

            ruleRows[i] = row
        end

        row:SetPoint("TOPLEFT", ruleChild, "TOPLEFT", 0, -((i - 1) * ruleHeight))
        row.ruleInfo = ruleInfo
        row.bg:SetVertexColor((i % 2 == 0) and 0.10 or 0.06, (i % 2 == 0) and 0.10 or 0.06, (i % 2 == 0) and 0.10 or 0.06, 0.85)
        row.ruleType:SetText(ruleInfo.type)
        row.detail:SetText(ruleInfo.detail)
        local canClear = ruleInfo.itemID ~= nil
        row.action:EnableMouse(canClear)
        row.action:SetAlpha(canClear and 1 or 0.35)
        row.action:SetText(canClear and "Clear" or "-")
        row:Show()
    end

    ruleChild:SetHeight(math.max(#rules * ruleHeight, 1))

    for i, itemInfo in ipairs(items) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Frame", nil, child)
            row:SetSize(520, rowHeight)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", 4, 0)

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
            row.name:SetWidth(260)
            row.name:SetJustifyH("LEFT")

            row.current = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.current:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
            row.current:SetWidth(135)
            row.current:SetJustifyH("LEFT")

            row.action = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.action:SetSize(88, 20)
            row.action:SetPoint("RIGHT", -4, 0)
            row.action:SetScript("OnClick", function(self)
                local info = self:GetParent().itemInfo
                if not info or not info.itemID or not Omni.Categorizer then return end

                if info.category == Editor.selectedCategory then
                    local override = GetOverrideCategory(info.itemID)
                    if override == Editor.selectedCategory then
                        Omni.Categorizer:ClearManualOverride(info.itemID)
                    elseif Editor.selectedCategory ~= "Miscellaneous" then
                        Omni.Categorizer:SetManualOverride(info.itemID, "Miscellaneous")
                    end
                else
                    Omni.Categorizer:SetManualOverride(info.itemID, Editor.selectedCategory)
                end

                RefreshInventory("category_membership")
                Editor:Refresh()
            end)

            rows[i] = row
        end

        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row.itemInfo = itemInfo
        row.bg:SetVertexColor((i % 2 == 0) and 0.10 or 0.06, (i % 2 == 0) and 0.10 or 0.06, (i % 2 == 0) and 0.10 or 0.06, 0.85)
        row.icon:SetTexture(itemInfo.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(itemInfo.__displayName)
        row.current:SetText(itemInfo.category or "Miscellaneous")

        local inCategory = itemInfo.category == category
        local override = GetOverrideCategory(itemInfo.itemID)
        local canChange = (not inCategory) or override == category or category ~= "Miscellaneous"
        row.current:SetTextColor(inCategory and 0.25 or 0.75, inCategory and 1 or 0.75, inCategory and 0.35 or 0.75)
        if inCategory then
            if override == category then
                row.action:SetText("Unpin")
            elseif canChange then
                row.action:SetText("Remove")
            else
                row.action:SetText("Auto")
            end
        else
            row.action:SetText("Add")
        end
        row.action:EnableMouse(canChange)
        row.action:SetAlpha(canChange and 1 or 0.45)
        row:Show()
    end

    child:SetHeight(math.max(#items * rowHeight, 1))
end

function Editor:Init()
    EnsureStaticPopups()
end

print("|cFF00FF00OmniInventory|r: Category Editor loaded")
