import "CoreLibs/graphics"
import "CoreLibs/ui"
import "constants.lua"

local pd <const> = playdate
local gfx <const> = playdate.graphics

local polygons = {}
local transforms = {}
local transformedPolygons = {}

local cursorPos = pd.geometry.point.new(200, 120)

local cursor_radius = 5
local movingLastFrame = false
local timeMoving = 0
local currentCursorVelocity = CURSOR_BASE_VELOCITY

local selection = nil
local selectionPoint = nil
local grabbed = nil
local selectedIndex = -1

local initialized = false
local resolvedCollisions = {}


function init()
    initialized = true
    --table.insert(polygons, pd.geometry.polygon.new(10, 10, 25, 25, 30, 5, 10, 10))
    --table.insert(polygons, pd.geometry.polygon.new(110, 110, 125, 125, 130, 105, 110, 110))
    table.insert(polygons, pd.geometry.polygon.new(300, 200, 325, 225, 350, 200, 337.5, 150, 312.5, 150, 300, 200))
    
    --table.insert(polygons, pd.geometry.polygon.new(10, 10, 110, 10, 60, 110, 10, 10))
    -- table.insert(polygons, pd.geometry.polygon.new(200, 200, 250, 200, 225, 250,  200, 200))

    table.insert(polygons, pd.geometry.polygon.new(200, 200, 250, 200, 250, 250, 200, 250, 200, 200))
    table.insert(polygons, pd.geometry.polygon.new(100, 100, 150, 100, 150, 150, 100, 150, 100, 100))
    
    initTransforms()
end


function initTransforms()
    for i, poly in ipairs(polygons) do
        -- find center position
        local center = poly:getBoundsRect():centerPoint()
        local transform = pd.geometry.affineTransform.new()
        transform:translate(center.x, center.y)

        local inverseTranslate = pd.geometry.affineTransform.new()
        inverseTranslate:translate(-center.x, -center.y)
        inverseTranslate:transformPolygon(poly)

        table.insert(transforms, transform)

        local transformedPoly = transform:transformedPolygon(poly)
        table.insert(transformedPolygons, transformedPoly)
    end
end


function draw()
    gfx.setColor(playdate.graphics.kColorBlack)
    gfx.drawCircleAtPoint(cursorPos.x, cursorPos.y, cursor_radius)

    for i, poly in ipairs(transformedPolygons) do
        if grabbed == i then
            gfx.fillPolygon(poly)
        else
            gfx.drawPolygon(poly)
        end
    end
end

function updateCursor(deltaT)
    local prevX = cursorPos.x
    local prevY = cursorPos.y

    local xInput = 0
    local yInput = 0
    if pd.buttonIsPressed("up") then
        yInput -= 1
    end
    if pd.buttonIsPressed("down") then
        yInput += 1
    end
    if pd.buttonIsPressed("right") then
        xInput += 1
    end
    if pd.buttonIsPressed("left") then
        xInput -= 1
    end

    --if moving this frame
    if xInput ~= 0 or yInput ~= 0 then
        if movingLastFrame == false then
            timeMoving = 0
        else
            timeMoving += deltaT
        end

        movingLastFrame = true

    else
        movingLastFrame = false
    end

    currentCursorVelocity = CURSOR_BASE_VELOCITY + (CURSOR_ACCELERATION * timeMoving)
    currentCursorVelocity = math.min(CURSOR_MAX_VELOCITY, currentCursorVelocity)

    local velocity = pd.geometry.vector2D.new(xInput, yInput):normalized()
    velocity *= currentCursorVelocity

    cursorPos += velocity * deltaT

    cursorPos.x = math.max(cursorPos.x, 0)
    cursorPos.x = math.min(cursorPos.x, 400)

    cursorPos.y = math.min(cursorPos.y, 240)
    cursorPos.y = math.max(cursorPos.y, 0)

    local delta = pd.geometry.point.new(cursorPos.x - prevX, cursorPos.y - prevY)
    return delta
end

function dot(v1, v2)

    return (v1.x * v2.x) + (v1.y * v2.y)
end


--normals from poly 1
--amount of overlap on poly1 normal
function checkOverlap(poly1, poly2)
    local separationVector = pd.geometry.vector2D.new(0, 0)
    local touching = false

    local poly1Points = {}
    local poly2Points = {}
    local normals = {}
    local poly1Separations = {}

    local offset = poly2:getBoundsRect():centerPoint() - poly1:getBoundsRect():centerPoint()

    for i = 1, poly1:count() do
        table.insert(poly1Points, poly1:getPointAt(i))
    end

    for i = 1, poly2:count() do
        table.insert(poly2Points, poly2:getPointAt(i))
    end


    local axis = poly1Points[1] - poly1Points[poly1:count()]
    axis = pd.geometry.vector2D.new(axis.y, -axis.x)
    axis:normalize()
    table.insert(normals, axis)

    axis = poly2Points[1] - poly2Points[poly2:count()]
    axis = pd.geometry.vector2D.new(axis.y, -axis.x)
    axis:normalize()
    table.insert(normals, axis)

    -- local centerPointX = (poly1Points[1].x + poly1Points[poly1:count()].x) / 2
    -- local centerPointY = (poly1Points[1].y + poly1Points[poly1:count()].y) / 2

    -- gfx.drawLine(centerPointX, centerPointY, centerPointX + axis.x * 20, centerPointY + axis.y * 20)
    for i=1, poly1:count() - 1 do
        axis = poly1Points[i+1] - poly1Points[i]
        axis = pd.geometry.vector2D.new(axis.y, -axis.x)
        axis:normalize()

        table.insert(normals, axis)
    end

    for i=1, poly2:count() - 1 do
        axis = poly2Points[i+1] - poly2Points[i]
        axis = pd.geometry.vector2D.new(axis.y, -axis.x)
        axis:normalize()

        table.insert(normals, axis)
    end

    

    for i, axis in ipairs(normals) do
        --project each point onto axis, keep track of min and max
        local p1Min = math.maxinteger
        local p2Min = math.maxinteger
        local p1Max = -math.maxinteger
        local p2Max = -math.maxinteger

        --for every point in polygon1
        for _, point in ipairs(poly1Points) do
            
            local dotProduct = dot(axis, point)

            p1Max = math.max(p1Max, dotProduct)
            p1Min = math.min(p1Min, dotProduct)
        end

        for _, point in ipairs(poly2Points) do
            local dotProduct = dot(axis, point)
            p2Max = math.max(p2Max, dotProduct)
            p2Min = math.min(p2Min, dotProduct)
        end

        --check for overlaps

        if (p1Min - p2Max > 0) or (p2Min - p1Max > 0) then
            --not touching
            --print("not touching")
            return false
        end


        --find overlap
        local minVal = math.min(p1Min, p2Min)
        local maxVal = math.max(p1Max, p2Max)
        local totalSpace = maxVal - minVal

        local p1Width = p1Max - p1Min
        local p2Width = p2Max - p2Min

        local overlap = p1Width + p2Width - totalSpace

        if p1Min < p2Min and p2Max > p1Max then
            --negate overlap
            overlap = -overlap
            
        elseif p2Min < p1Min and p1Max > p2Max then
            --leave overlap
        else
            --totally covered
            --print("total coverage")
        end

        poly1Separations[i] = overlap
    end

    --print("touching!!")
    local minIndex = -1
    local minSeparation = math.maxinteger
    for i, separation in ipairs(poly1Separations) do
        --print("checking %i", i)
        if(math.abs(separation) < math.abs(minSeparation)) then
        --if(separation < minSeparation) then
            minSeparation = separation
            
            minIndex = i

            --print(string.format("new min separation: %.1f", minSeparation))
        end
        
    end
    --print("found touching")
    return true, normals[minIndex]:scaledBy(minSeparation)
end

function playdate.update()
    if initialized == false then
        init()
    end

    local deltaT = pd.getElapsedTime()
    gfx.clear()

    local crankDelta = pd.getCrankChange()

    local deltaCursor = updateCursor(deltaT) --moves cursor, gets amount moved
    
    if pd.buttonJustPressed("a") then
        --check if grabbed anything
        grabbed = nil
        for i, poly in ipairs(transformedPolygons) do
            if poly:containsPoint(cursorPos) then
                grabbed = i
            end
        end
    end

    if pd.buttonIsPressed("a") and grabbed ~= nil then
        transforms[grabbed]:translate(deltaCursor.x, deltaCursor.y)
        transforms[grabbed]:rotate(crankDelta, transforms[grabbed].tx, transforms[grabbed].ty)

        transformedPolygons[grabbed] = transforms[grabbed]:transformedPolygon(polygons[grabbed])
    else
        grabbed = nil
    end

    


    resolvedCollisions = {}

    --check every pair for overlaps
    for i, poly1 in ipairs(transformedPolygons) do
        for j, poly2 in ipairs(transformedPolygons) do
            if i ~= j and i ~= grabbed then
                --print(string.format("checking %i vs %i", i, j))
                local overlapping, amount = checkOverlap(poly1, poly2)

                if overlapping then
                    --print(string.format("%i touching %i!", i, j))
                    
                    --local resolvedp2 = poly1:copy()
                    --resolvedp2:translate(amount.x, amount.y)
                    --table.insert(resolvedCollisions, resolvedp2)
                    transforms[i]:translate(amount.x, amount.y)
                end
            end
        end
    end

    --update transformed polygons
    for i, poly in ipairs(polygons) do
        transformedPolygons[i] = transforms[i]:transformedPolygon(polygons[i])
    end

    draw()
    pd.resetElapsedTime()
end