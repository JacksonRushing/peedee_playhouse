import "CoreLibs/graphics"
import "CoreLibs/ui"
import "constants.lua"

local pd <const> = playdate
local gfx <const> = playdate.graphics

local polygons = {}

local cursorPos = pd.geometry.point.new(200, 120)

local cursor_radius = 5
local movingLastFrame = false
local timeMoving = 0
local currentCursorVelocity = CURSOR_BASE_VELOCITY

local selection = nil
local selectionPoint = nil
local selectedIndex = -1


table.insert(polygons, pd.geometry.polygon.new(10, 10, 25, 25, 30, 5, 10, 10))

function getLowestPolygonIndex(polygon)
    local lowestIndex = nil
    local lowestY = math.maxinteger
    local lowestX = math.maxinteger
    for i=1, polygon:count() do
        local point = polygon:getPointAt(i)
        if point.y < lowestY then
            lowestY = point.y
            lowestX = point.x
            lowestIndex = i
        elseif point.y == lowestY then
            if point.x < lowestX then
                lowestX = point.x
                lowestIndex = i
            end
        end
    end

    return lowestIndex

end

function flipTriangle(polygon)
    local tempPoint = polygon:getPointAt(2)
    polygon:setPointAt(2, polygon:getPointAt(3))
    polygon:setPointAt(3, tempPoint)

    return polygon
end

function getWindingIsClockwise(polygon)
    local numVertices = polygon:count()
    if numVertices < 3 then
        print("tried to check winding order of a polygon with less than 3 points")
        return true
    end

    local lowestPointIndex = getLowestPolygonIndex(polygon)
    local foreIndex = lowestPointIndex - 1
    if foreIndex < 1 then
        foreIndex = numVertices
    end

    local aftIndex = lowestPointIndex + 1
    if aftIndex > numVertices then
        aftIndex = 1
    end

    local forePoint = polygon:getPointAt(foreIndex)
    local aftPoint = polygon:getPointAt(aftIndex)
    local lowestPoint = polygon:getPointAt(lowestPointIndex)

    print(string.format("lowest index is %i, fore index is %i, aft index is %i", lowestPointIndex, foreIndex, aftIndex))

    local foreLine = pd.geometry.vector2D.new(lowestPoint.x - forePoint.x, lowestPoint.y - forePoint.y)
    local aftLine = pd.geometry.vector2D.new(aftPoint.x - lowestPoint.x, aftPoint.y - lowestPoint.y)

    local dotProduct = foreLine:dotProduct(aftLine)
    local angle = math.acos(dotProduct / (foreLine:magnitude() * aftLine:magnitude()))

    local sign = math.sin(angle)

    print(string.format("angle is %f.1", angle))

    print(string.format("sign of cross product is positive? %s", tostring(sign > 0)))

    return sign < 0
end

function draw()
    gfx.setColor(playdate.graphics.kColorBlack)
    gfx.drawCircleAtPoint(cursorPos.x, cursorPos.y, cursor_radius)

    for i, poly in ipairs(polygons) do
        gfx.drawPolygon(poly)
        drawVertexIndices(poly)
    end

    if selection ~= nil then
        gfx.drawLine(cursorPos.x, cursorPos.y, selectionPoint.x, selectionPoint.y)
    end
end

function drawVertexIndices(poly)
    local points = {}
    for i=1, poly:count() do
        table.insert(points, poly:getPointAt(i))
    end

    for i, point in ipairs(points) do
        gfx.drawText(tostring(i), point.x + VERTEX_LABEL_OFFSET_X, point.y + VERTEX_LABEL_OFFSET_Y)
    end
end


function addPoint(point, selection)
    --no polygon selected
    if selection == nil then
        local newPolygon = pd.geometry.polygon.new(point.x, point.y, point.x, point.y)
        table.insert(polygons, newPolygon)
        print("creating new polygon at")
        print(point.x, point.y)
    else
        print(string.format("adding to existing polygon of length %i", selection:count()))
        
        print(selection)
        local points = {}
        for i=1, selection:count() do
            table.insert(points, selection:getPointAt(i))
        end

        table.insert(points, point)

        polygons[selectedIndex] = pd.geometry.polygon.new(points)
        polygons[selectedIndex]:close()

        if polygons[selectedIndex]:count() == 3 then
            print("created triangle")
            if getWindingIsClockwise(polygons[selectedIndex]) then
                print("winding was clockwise, flipping")
                print(polygons[selectedIndex])
                polygons[selectedIndex] = flipTriangle(polygons[selectedIndex])
                print(polygons[selectedIndex])
                print(string.format("winding is now %s", tostring(getWindingIsClockwise(polygons[selectedIndex]))))
            end
        end


    end
    

end

function updateCursor(deltaT)
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
end

function playdate.update()
    local deltaT = pd.getElapsedTime()
    gfx.clear()

    local distanceToSelection = math.maxinteger
    for i, poly in ipairs(polygons) do
        local bounds = poly:getBoundsRect()
        local center = bounds:centerPoint()
        -- print(string.format("poly %i", i))
        -- -- print(poly)
        -- print(poly:getPointAt(1))
        local distance = cursorPos:distanceToPoint(center)
        if distance < MAGNET_RADIUS and distance < distanceToSelection then
            distanceToSelection = distance
            selection = poly
            selectedIndex = i
            selectionPoint = center
        end
    end

    updateCursor(deltaT)
    
    if pd.buttonJustReleased("a") then
        addPoint(cursorPos, selection)
    end

    -- local velocityString = string.format("velocity: %.1f ", currentCursorVelocity)
    -- gfx.drawText(velocityString, 0, 0)

    draw()
    pd.resetElapsedTime()
end