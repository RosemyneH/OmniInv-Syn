local addonName, NS = ...

NS.Config = {}

local defaults = {
    scale = 1.0,
    opacity = 1.0,
    sortOnUpdate = true,
    columnCount = 5,
    itemSize = 37,
    padding = 5,
    showTooltips = true,
    enableSearch = true,
    collapsedSections = {},  -- Track which category sections are collapsed
}

function NS.Config:Init()
    ZenBagsDB = ZenBagsDB or {}
    
    -- Merge defaults
    for k, v in pairs(defaults) do
        if ZenBagsDB[k] == nil then
            ZenBagsDB[k] = v
        end
    end
end

function NS.Config:Get(key)
    return ZenBagsDB[key] or defaults[key]
end

function NS.Config:Set(key, value)
    ZenBagsDB[key] = value
end

function NS.Config:IsSectionCollapsed(categoryName)
    if not ZenBagsDB.collapsedSections then
        ZenBagsDB.collapsedSections = {}
    end
    return ZenBagsDB.collapsedSections[categoryName] == true
end

function NS.Config:ToggleSectionCollapsed(categoryName)
    if not ZenBagsDB.collapsedSections then
        ZenBagsDB.collapsedSections = {}
    end
    
    if ZenBagsDB.collapsedSections[categoryName] then
        ZenBagsDB.collapsedSections[categoryName] = nil
    else
        ZenBagsDB.collapsedSections[categoryName] = true
    end
end

function NS.Config:GetDefaults()
    return defaults
end
