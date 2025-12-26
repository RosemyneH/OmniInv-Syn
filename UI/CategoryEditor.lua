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
-- Creation
-- =============================================================================

function Editor:CreateFrame()
    if editorFrame then return editorFrame end

    editorFrame = CreateFrame("Frame", "OmniCategoryEditor", UIParent)
    editorFrame:SetSize(600, 450)
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

    -- Left Sidebar (Categories)
    local sidebar = CreateFrame("Frame", nil, editorFrame)
    sidebar:SetPoint("TOPLEFT", 16, -40)
    sidebar:SetPoint("BOTTOMLEFT", 16, 16)
    sidebar:SetWidth(150)

    sidebar.bg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebar.bg:SetAllPoints()
    sidebar.bg:SetTexture(0, 0, 0, 0.3)

    self:CreateCategoryList(sidebar)
    self.sidebar = sidebar

    -- Right Content (Rules)
    local content = CreateFrame("Frame", nil, editorFrame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    content:SetPoint("BOTTOMRIGHT", -16, 16)

    content.bg = content:CreateTexture(nil, "BACKGROUND")
    content.bg:SetAllPoints()
    content.bg:SetTexture(0, 0, 0, 0.1)

    self:CreateRuleEditor(content)
    self.content = content

    editorFrame:Hide()
    return editorFrame
end

function Editor:CreateCategoryList(parent)
    -- Add Category Button
    local addBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addBtn:SetSize(140, 24)
    addBtn:SetPoint("TOP", 0, -5)
    addBtn:SetText("New Category")
    addBtn:SetScript("OnClick", function()
         StaticPopupDialogs["OMNI_NEW_CATEGORY"] = {
            text = "Enter new category name:",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = true,
            OnAccept = function(self)
                local name = self.editBox:GetText()
                if name and name ~= "" then
                    -- Create dummy rule for category
                    local rule = {
                        name = name .. " Rule",
                        category = name,
                        priority = 50,
                        enabled = true,
                        conditions = { { field = "name", operator = "contains", value = "Example" } }
                    }
                    Omni.Rules:AddRule(rule)
                    Editor:Refresh()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("OMNI_NEW_CATEGORY")
    end)

    -- List container
    local list = CreateFrame("ScrollFrame", "OmniCategoryList", parent, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 0, -35)
    list:SetPoint("BOTTOMRIGHT", -25, 5)

    local child = CreateFrame("Frame")
    child:SetSize(125, 1000) -- Taller for scroll
    list:SetScrollChild(child)
    self.categoryListChild = child
end

function Editor:CreateRuleEditor(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Rules")
    self.ruleTitle = title

    -- Add Rule Button
    local addBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addBtn:SetSize(100, 24)
    addBtn:SetPoint("TOPRIGHT", -10, -10)
    addBtn:SetText("Add Rule")
    addBtn:SetScript("OnClick", function()
        if not self.selectedCategory then return end

        local rule = {
            name = "New Rule",
            category = self.selectedCategory,
            priority = 50,
            enabled = true,
            conditions = { { field = "itemType", operator = "equals", value = "Quest" } }
        }
        Omni.Rules:AddRule(rule)
        Editor:Refresh()
    end)

    -- Rule List
    local list = CreateFrame("ScrollFrame", "OmniRuleList", parent, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 10, -40)
    list:SetPoint("BOTTOMRIGHT", -30, 40)

    local child = CreateFrame("Frame")
    child:SetSize(380, 1000)
    list:SetScrollChild(child)
    self.ruleListChild = child
end

-- =============================================================================
-- Actions
-- =============================================================================

function Editor:Toggle()
    if not editorFrame then
        self:CreateFrame()
    end

    if editorFrame:IsShown() then
        editorFrame:Hide()
    else
        self:Refresh()
        editorFrame:Show()
    end
end

function Editor:Refresh()
    if not editorFrame then return end

    self:RefreshCategoryList()
    self:RefreshRuleList()
end

function Editor:RefreshCategoryList()
    -- Clear existing
    local child = self.categoryListChild
    if not child.buttons then child.buttons = {} end

    for _, btn in pairs(child.buttons) do btn:Hide() end

    -- Get categories from rules
    local rules = Omni.Rules:GetAllRules()
    local categories = {}
    for _, rule in ipairs(rules) do
        if rule.category then
            categories[rule.category] = true
        end
    end

    local sortedCats = {}
    for cat in pairs(categories) do table.insert(sortedCats, cat) end
    table.sort(sortedCats)

    -- Create buttons
    for i, cat in ipairs(sortedCats) do
        local btn = child.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, child, "OptionsButtonTemplate")
            btn:SetSize(125, 20)
            btn:SetScript("OnClick", function(self)
                Editor:SelectCategory(self.category)
            end)
            child.buttons[i] = btn
        end

        btn:SetPoint("TOPLEFT", 0, -((i-1)*20))
        btn:SetText(cat)
        btn.category = cat
        btn:Show()

        -- Highlight selected
        if cat == self.selectedCategory then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    -- Auto select first
    if not self.selectedCategory and sortedCats[1] then
        self:SelectCategory(sortedCats[1])
    end
end

function Editor:SelectCategory(cat)
    self.selectedCategory = cat
    self:Refresh()
end

function Editor:RefreshRuleList()
    -- Clear existing
    local child = self.ruleListChild
    if not child.frames then child.frames = {} end

    for _, f in pairs(child.frames) do f:Hide() end

    if not self.selectedCategory then
        self.ruleTitle:SetText("Select a Category")
        return
    end

    self.ruleTitle:SetText("Rules: " .. self.selectedCategory)

    -- Filter rules
    local allRules = Omni.Rules:GetAllRules()
    local catRules = {}
    for _, rule in ipairs(allRules) do
        if rule.category == self.selectedCategory then
            table.insert(catRules, rule)
        end
    end

    -- Create rule rows
    for i, rule in ipairs(catRules) do
        local frame = child.frames[i]
        if not frame then
            frame = CreateFrame("Frame", nil, child)
            frame:SetSize(380, 50)
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            frame:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
            frame:SetBackdropBorderColor(0, 0, 0, 1)

            frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.name:SetPoint("TOPLEFT", 10, -5)

            frame.desc = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            frame.desc:SetPoint("TOPLEFT", 10, -25)

            local delBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            delBtn:SetSize(60, 20)
            delBtn:SetPoint("RIGHT", -5, 0)
            delBtn:SetText("Delete")
            frame.delBtn = delBtn

            child.frames[i] = frame
        end

        frame:SetPoint("TOPLEFT", 0, -((i-1)*55))
        frame.name:SetText(rule.name or "Unnamed Rule")

        local desc = "Priority: " .. (rule.priority or 50)
        if rule.conditions and rule.conditions[1] then
            desc = desc .. " | " .. rule.conditions[1].field .. " " .. rule.conditions[1].operator .. " " .. tostring(rule.conditions[1].value)
        end
        frame.desc:SetText(desc)

        frame.delBtn:SetScript("OnClick", function()
            Omni.Rules:RemoveRule(rule.id)
            Editor:Refresh()
        end)

        frame:Show()
    end
end

function Editor:Init()
    -- Initialized
end

print("|cFF00FF00OmniInventory|r: Category Editor loaded")
