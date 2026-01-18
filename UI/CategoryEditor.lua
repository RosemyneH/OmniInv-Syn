-- =============================================================================
-- OmniInventory Category Editor
-- =============================================================================
-- Purpose: Visual editor for managing item categorization rules.
-- Features: Category list, rule list inside categories, rule add/edit UI.
-- =============================================================================

local addonName, Omni = ...

Omni.CategoryEditor = {}
local Editor = Omni.CategoryEditor
local editorFrame = nil

-- =============================================================================
-- Constants & Helpers
-- =============================================================================

local FIELD_OPTIONS = {
    { text = "Item Name", value = "name" },
    { text = "Item Type", value = "itemType" },
    { text = "Sub Type", value = "itemSubType" },
    { text = "Item ID", value = "itemID" },
    { text = "Item Level", value = "iLvl" },
    { text = "Quality", value = "quality" },
    { text = "Equipment Slot", value = "equipSlot" },
    { text = "Tooltip Text", value = "tooltip" },
}

local OPERATOR_OPTIONS = {
    { text = "Equals", value = "equals" },
    { text = "Not Equals", value = "not_equals" },
    { text = "Contains", value = "contains" },
    { text = "Starts With", value = "starts_with" },
    { text = "Greater Than", value = "greater_than" },
    { text = "Less Than", value = "less_than" },
    { text = "In List", value = "in_list" },
}

local function CreateDropdown(parent, width, options)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, opt in ipairs(options) do
            info.text = opt.text
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dropdown, opt.value)
                UIDropDownMenu_SetText(dropdown, opt.text)
                if dropdown.OnValueChanged then dropdown.OnValueChanged(opt.value) end
            end
            info.checked = (dropdown.selectedValue == opt.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return dropdown
end

-- =============================================================================
-- Creation
-- =============================================================================

function Editor:CreateFrame()
    if editorFrame then return editorFrame end

    editorFrame = CreateFrame("Frame", "OmniCategoryEditor", UIParent)
    editorFrame:SetSize(700, 500)
    editorFrame:SetPoint("CENTER")
    editorFrame:SetFrameStrata("DIALOG")
    editorFrame:EnableMouse(true)
    editorFrame:SetMovable(true)
    editorFrame:SetClampedToScreen(true)

    -- Backdrop
    editorFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Draggable header
    editorFrame:RegisterForDrag("LeftButton")
    editorFrame:SetScript("OnDragStart", editorFrame.StartMoving)
    editorFrame:SetScript("OnDragStop", editorFrame.StopMovingOrSizing)

    -- Title
    local title = editorFrame:CreateTexture(nil, "ARTWORK")
    title:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    title:SetSize(300, 64)
    title:SetPoint("TOP", 0, 12)

    local titleText = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", title, "TOP", 0, -14)
    titleText:SetText("Category Editor")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, editorFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- 1. Left Sidebar (Categories)
    local sidebar = CreateFrame("Frame", nil, editorFrame)
    sidebar:SetPoint("TOPLEFT", 16, -40)
    sidebar:SetPoint("BOTTOMLEFT", 16, 16)
    sidebar:SetWidth(150)
    sidebar.bg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebar.bg:SetAllPoints()
    sidebar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    sidebar.bg:SetVertexColor(0, 0, 0, 0.3)

    self:CreateCategoryList(sidebar)
    self.sidebar = sidebar

    -- 2. Middle Panel (Rule List for Category)
    local midPanel = CreateFrame("Frame", nil, editorFrame)
    midPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    midPanel:SetPoint("BOTTOM", 0, 16)
    midPanel:SetWidth(200)
    midPanel.bg = midPanel:CreateTexture(nil, "BACKGROUND")
    midPanel.bg:SetAllPoints()
    midPanel.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    midPanel.bg:SetVertexColor(0, 0, 0, 0.1)

    self:CreateRuleList(midPanel)
    self.midPanel = midPanel

    -- 3. Right Panel (Rule Editor)
    local rightPanel = CreateFrame("Frame", nil, editorFrame)
    rightPanel:SetPoint("TOPLEFT", midPanel, "TOPRIGHT", 10, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", -16, 16)
    rightPanel.bg = rightPanel:CreateTexture(nil, "BACKGROUND")
    rightPanel.bg:SetAllPoints()
    rightPanel.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    rightPanel.bg:SetVertexColor(0, 0, 0, 0.2)

    self:CreateRuleDetails(rightPanel)
    self.rightPanel = rightPanel

    editorFrame:Hide()
    return editorFrame
end

function Editor:CreateCategoryList(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 5, -5)
    title:SetText("Categories")

    local addBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addBtn:SetSize(20, 20)
    addBtn:SetPoint("TOPRIGHT", -5, -5)
    addBtn:SetText("+")
    addBtn:SetScript("OnClick", function()
        StaticPopupDialogs["OMNI_NEW_CATEGORY"] = {
            text = "Enter new category name:",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = true,
            OnAccept = function(self)
                local name = self.editBox:GetText()
                if name and name ~= "" then
                    self:GetParent():Hide()
                    -- Create a placeholder rule to establish the category
                    Omni.Rules:AddRule({
                        name = "New Rule",
                        category = name,
                        enabled = true,
                        priority = 50,
                        conditions = {}
                    })
                    Editor:RefreshCategoryList()
                    Editor:SelectCategory(name)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("OMNI_NEW_CATEGORY")
    end)

    local list = CreateFrame("ScrollFrame", "OmniCategoryListScroll", parent, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 0, -30)
    list:SetPoint("BOTTOMRIGHT", -25, 5)

    local child = CreateFrame("Frame")
    child:SetSize(125, 1000)
    list:SetScrollChild(child)
    self.categoryListChild = child
end

function Editor:CreateRuleList(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 5, -5)
    title:SetText("Rules")
    self.ruleListTitle = title

    local addBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addBtn:SetSize(20, 20)
    addBtn:SetPoint("TOPRIGHT", -5, -5)
    addBtn:SetText("+")
    addBtn:SetScript("OnClick", function()
        if not self.selectedCategory then return end
        Omni.Rules:AddRule({
            name = "New Rule",
            category = self.selectedCategory,
            enabled = true,
            priority = 50,
            conditions = {}
        })
        Editor:RefreshRuleList()
    end)

    local list = CreateFrame("ScrollFrame", "OmniRuleListScroll", parent, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 0, -30)
    list:SetPoint("BOTTOMRIGHT", -25, 5)

    local child = CreateFrame("Frame")
    child:SetSize(175, 1000)
    list:SetScrollChild(child)
    self.ruleListChild = child
end

function Editor:CreateRuleDetails(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 5, -5)
    title:SetText("Rule Details")

    -- Name Input
    local nameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 10, -30)
    nameLabel:SetText("Name:")

    local nameEdit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    nameEdit:SetSize(200, 24)
    nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    nameEdit:SetScript("OnEditFocusLost", function(self)
        if Editor.selectedRule then
            Omni.Rules:UpdateRule(Editor.selectedRule.id, { name = self:GetText() })
            Editor:RefreshRuleList() -- To update name in list
        end
    end)
    self.ruleNameEdit = nameEdit

    -- Priority Input
    local priLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priLabel:SetPoint("TOPLEFT", 10, -60)
    priLabel:SetText("Priority:")

    local priEdit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    priEdit:SetSize(50, 24)
    priEdit:SetPoint("LEFT", priLabel, "RIGHT", 10, 0)
    priEdit:SetNumeric(true)
    priEdit:SetAutoFocus(false)
    priEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    priEdit:SetScript("OnEditFocusLost", function(self)
        if Editor.selectedRule then
            Omni.Rules:UpdateRule(Editor.selectedRule.id, { priority = tonumber(self:GetText()) or 50 })
        end
    end)
    self.rulePriEdit = priEdit

    -- Conditions List
    local condLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    condLabel:SetPoint("TOPLEFT", 10, -90)
    condLabel:SetText("Conditions:")

    local addConditionBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addConditionBtn:SetSize(80, 20)
    addConditionBtn:SetPoint("LEFT", condLabel, "RIGHT", 10, 0)
    addConditionBtn:SetText("Add")
    addConditionBtn:SetScript("OnClick", function()
        if Editor.selectedRule then
            local rule = Editor.selectedRule
            rule.conditions = rule.conditions or {}
            table.insert(rule.conditions, { field = "name", operator = "contains", value = "" })
            Omni.Rules:UpdateRule(rule.id, { conditions = rule.conditions })
            Editor:RefreshRuleDetails()
        end
    end)

    local condScroll = CreateFrame("ScrollFrame", "OmniConditionScroll", parent, "UIPanelScrollFrameTemplate")
    condScroll:SetPoint("TOPLEFT", 10, -115)
    condScroll:SetPoint("BOTTOMRIGHT", -25, 40)

    local condChild = CreateFrame("Frame")
    condChild:SetSize(250, 500)
    condScroll:SetScrollChild(condChild)
    self.conditionChild = condChild

    -- Delete Button
    local delBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    delBtn:SetSize(100, 24)
    delBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    delBtn:SetText("Delete Rule")
    delBtn:SetScript("OnClick", function()
        if Editor.selectedRule then
            Omni.Rules:RemoveRule(Editor.selectedRule.id)
            Editor.selectedRule = nil
            Editor:RefreshRuleList()
            Editor:RefreshRuleDetails()
        end
    end)
end

-- =============================================================================
-- Actions & Updates
-- =============================================================================

function Editor:Toggle()
    if not editorFrame then self:CreateFrame() end
    if editorFrame:IsShown() then editorFrame:Hide() else self:Refresh() editorFrame:Show() end
end

function Editor:Refresh()
    if not editorFrame then return end
    self:RefreshCategoryList()
    self:RefreshRuleList()
    self:RefreshRuleDetails()
end

function Editor:SelectCategory(cat)
    self.selectedCategory = cat
    self.selectedRule = nil
    self:RefreshRuleList()
    self:RefreshRuleDetails()
end

function Editor:SelectRule(rule)
    self.selectedRule = rule
    self:RefreshRuleDetails()
end

function Editor:RefreshCategoryList()
    -- Get unique categories
    local categories = {}
    for _, rule in ipairs(Omni.Rules:GetAllRules()) do
        if rule.category then categories[rule.category] = true end
    end

    local sorted = {}
    for cat in pairs(categories) do table.insert(sorted, cat) end
    table.sort(sorted)

    local child = self.categoryListChild
    if not child.buttons then child.buttons = {} end

    for _, btn in pairs(child.buttons) do btn:Hide() end

    for i, cat in ipairs(sorted) do
        local btn = child.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, child, "OptionsButtonTemplate")
            btn:SetSize(130, 20)
            btn:SetScript("OnClick", function(self) Editor:SelectCategory(self.cat) end)
            child.buttons[i] = btn
        end

        btn:SetPoint("TOPLEFT", 0, -((i-1)*20))
        btn.cat = cat
        btn:SetText(cat)
        btn:Show()

        if cat == self.selectedCategory then btn:LockHighlight() else btn:UnlockHighlight() end
    end
end

function Editor:RefreshRuleList()
    local child = self.ruleListChild
    if not child.buttons then child.buttons = {} end
    for _, btn in pairs(child.buttons) do btn:Hide() end

    if not self.selectedCategory then return end

    local rules = {}
    for _, rule in ipairs(Omni.Rules:GetAllRules()) do
        if rule.category == self.selectedCategory then table.insert(rules, rule) end
    end
    table.sort(rules, function(a,b) return (a.priority or 0) > (b.priority or 0) end)

    for i, rule in ipairs(rules) do
        local btn = child.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, child, "OptionsButtonTemplate")
            btn:SetSize(180, 20)
            btn:SetScript("OnClick", function(self) Editor:SelectRule(self.rule) end)
            child.buttons[i] = btn
        end

        btn:SetPoint("TOPLEFT", 0, -((i-1)*20))
        btn.rule = rule
        btn:SetText(rule.name)
        btn:Show()

        if self.selectedRule and self.selectedRule.id == rule.id then btn:LockHighlight() else btn:UnlockHighlight() end
    end
end

function Editor:RefreshRuleDetails()
    local rule = self.selectedRule

    -- Visibility
    if not rule then
        self.rightPanel:SetAlpha(0.5)
        self.ruleNameEdit:ClearFocus()
        self.ruleNameEdit:EnableMouse(false)
        self.rulePriEdit:EnableMouse(false)
        return
    else
        self.rightPanel:SetAlpha(1.0)
        self.ruleNameEdit:EnableMouse(true)
        self.rulePriEdit:EnableMouse(true)
    end

    self.ruleNameEdit:SetText(rule.name or "")
    self.rulePriEdit:SetText(rule.priority or 50)

    -- Conditions
    local child = self.conditionChild
    if not child.rows then child.rows = {} end
    for _, row in pairs(child.rows) do row:Hide() end

    if rule.conditions then
        for i, cond in ipairs(rule.conditions) do
            local row = child.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, child)
                row:SetSize(250, 50)

                -- Field Dropdown
                row.fieldDD = CreateDropdown(row, 100, FIELD_OPTIONS)
                row.fieldDD:SetPoint("TOPLEFT", -15, 0)
                row.fieldDD.OnValueChanged = function(val)
                    if row.cond then
                        row.cond.field = val
                        Omni.Rules:UpdateRule(Editor.selectedRule.id, { conditions = Editor.selectedRule.conditions })
                    end
                end

                -- Operator Dropdown
                row.opDD = CreateDropdown(row, 100, OPERATOR_OPTIONS)
                row.opDD:SetPoint("LEFT", row.fieldDD, "RIGHT", -25, 0)
                row.opDD.OnValueChanged = function(val)
                     if row.cond then
                        row.cond.operator = val
                        Omni.Rules:UpdateRule(Editor.selectedRule.id, { conditions = Editor.selectedRule.conditions })
                    end
                end

                -- Value Edit
                row.valEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                row.valEdit:SetSize(120, 20)
                row.valEdit:SetPoint("TOPLEFT", 10, -30)
                row.valEdit:SetAutoFocus(false)
                row.valEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                row.valEdit:SetScript("OnEditFocusLost", function(self)
                    if row.cond then
                        row.cond.value = self:GetText()
                        Omni.Rules:UpdateRule(Editor.selectedRule.id, { conditions = Editor.selectedRule.conditions })
                    end
                end)

                -- Remove Button
                row.delBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
                row.delBtn:SetSize(20, 20)
                row.delBtn:SetPoint("LEFT", row.valEdit, "RIGHT", 5, 0)
                row.delBtn:SetScript("OnClick", function()
                    if Editor.selectedRule then
                        table.remove(Editor.selectedRule.conditions, i)
                        Omni.Rules:UpdateRule(Editor.selectedRule.id, { conditions = Editor.selectedRule.conditions })
                        Editor:RefreshRuleDetails()
                    end
                end)

                child.rows[i] = row
            end

            row:SetPoint("TOPLEFT", 0, -((i-1)*55))
            row.cond = cond

            -- Set Values
            UIDropDownMenu_SetSelectedValue(row.fieldDD, cond.field)
            UIDropDownMenu_SetText(row.fieldDD, cond.field) -- Ideally map to text

            UIDropDownMenu_SetSelectedValue(row.opDD, cond.operator)
            UIDropDownMenu_SetText(row.opDD, cond.operator)

            row.valEdit:SetText(cond.value or "")

            row:Show()
        end
    end
end

function Editor:Init()
    -- no-op
end

print("|cFF00FF00OmniInventory|r: Category Editor loaded")
