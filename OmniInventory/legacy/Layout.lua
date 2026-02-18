local addonName, NS = ...

NS.Layout = {}
local Layout = NS.Layout

--- Calculate grid positions for items
function Layout:Grid(items, options)
    options = options or {}
    local columns = options.columns or 8
    local itemSize = options.itemSize or 37
    local padding = options.padding or 5

    local positions = {}

    for i, item in ipairs(items) do
        local row = math.floor((i - 1) / columns)
        local col = (i - 1) % columns

        positions[i] = {
            item = item,
            x = col * (itemSize + padding),
            y = -row * (itemSize + padding)
        }
    end

    return positions
end

--- Calculate category-grouped positions
function Layout:Category(items, options)
    options = options or {}
    local columns = options.columns or 8
    local itemSize = options.itemSize or 37
    local padding = options.padding or 5

    -- Group by category
    local groups = {}
    for _, item in ipairs(items) do
        local cat = item.category or "Miscellaneous"
        groups[cat] = groups[cat] or {}
        table.insert(groups[cat], item)
    end

    local positions = {}
    local yOffset = 0

    for category, catItems in pairs(groups) do
        -- Add category header position
        table.insert(positions, {
            isHeader = true,
            category = category,
            x = 0,
            y = yOffset
        })
        yOffset = yOffset - 25 -- Header height

        -- Add items in grid
        for i, item in ipairs(catItems) do
            local row = math.floor((i - 1) / columns)
            local col = (i - 1) % columns

            table.insert(positions, {
                item = item,
                x = col * (itemSize + padding),
                y = yOffset - row * (itemSize + padding)
            })
        end

        local rows = math.ceil(#catItems / columns)
        yOffset = yOffset - (rows * (itemSize + padding)) - 10
    end

    return positions
end

function Layout:Init()
    -- Nothing to init
end
