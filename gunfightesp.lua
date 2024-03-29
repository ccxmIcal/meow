---@vars
local runService = game:GetService('RunService')
local players = game:GetService('Players')
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera

local esp = {
    -- settings
    enabled = false,
    teamcheck = true,
    visiblecheck = false,
    outlines = true,
    limitdistance = false,

    visiblecheckparams = {},
    maxdistance = 1200,
    fadefactor = 20,
    arrowradius = 500,
    arrowsize = 20,
    

    -- drawings
    boxes = { false, Color3.new(1,1,1)},
    healthbar = { false, Color3.new(0.5, 1, 0.5), Color3.new(1, 0.5, 0.5) },
    arrowinfo = false,
    arrow = { false, Color3.new(0, 1, 0), Color3.new(1, 0, 0), 0, 1 },

    -- texts
    names = { false, Color3.new(1, 1, 1)},
    health = false,

    font = 2,
    textsize = 13,

    -- tables
    players = {},
    connections = {},
}

-- index optimisations
local NEWCF   = CFrame.new
local NEWVEC2 = Vector2.new

local MIN     = math.min
local MAX     = math.max
local ATAN2   = math.atan2
local CLAMP   = math.clamp
local FLOOR   = math.floor
local SIN     = math.sin
local COS     = math.cos
local RAD     = math.rad

-- functions
function esp:draw(a, b)
    local instance = Drawing.new(a)
    if type(b) == 'table' then
        for property, value in next, b do
            instance[property] = value
        end
    end
    return instance
end
function esp:setproperties(a, b)
    for i, v in next, b do
        a[i] = v;
    end
    return a
end
function esp:raycast(a, b, c)
    c = type(c) == 'table' and c or {}
    local params = RaycastParams.new();
    params.IgnoreWater = true;
    params.FilterType = Enum.RaycastFilterType.Blacklist;
    params.FilterDescendantsInstances = c;

    local ray = workspace:Raycast(a, b, params);
    if ray ~= nil then
        if ray.Instance.Transparency >= .250 then
            table.insert(c, ray.Instance);
            local newray = self:raycast(a,b,c)
            if newray ~= nil then
                ray = newray
            end
        end
    end
    return ray
end

function esp.getcharacter(plr)
    return plr.Character
end

function esp.checkalive(plr)
    if not plr then plr = localPlayer end
    local pass = false
    if (plr.Character and plr.Character:FindFirstChild('Humanoid') and plr.Character:FindFirstChild('Head') and plr.Character:FindFirstChild('LeftUpperArm') and plr.Character.Humanoid.Health > 0 and plr.Character.LeftUpperArm.Transparency == 0) then
        pass = true
    end
    return pass
end

function esp.checkteam(plr, bool)
    if not plr then plr = localPlayer end
    return plr ~= localPlayer and bool or plr.Team ~= localPlayer.Team
end

function esp:checkvisible(instance, origin, params)
    if not params then params = {} end
    local hit = self:raycast(camera.CFrame.p, (origin.Position - camera.CFrame.p).unit * 500, { unpack(params), camera, localPlayer.Character })
    return (hit and hit.Instance:IsDescendantOf(instance)) and true or false
end

function esp:check(plr)
	if plr == players.LocalPlayer then return false; end;
	local pass = true;
	local character = self.getcharacter(plr);
	if not self.checkalive(plr) then
		pass = false;
	elseif esp.limitdistance and (character.PrimaryPart.CFrame.p - workspace.CurrentCamera.CFrame.p).magnitude > esp.maxdistance then
		pass = false;
	elseif esp.teamcheck and not self.checkteam(plr, false) then
		pass = false
    elseif esp.visiblecheck and not self:checkvisible(character, character.Head, esp.visiblecheckparams) then
        pass = false
	end;
	return pass;
end;

function esp:returnoffsets(x, y, minY, z)
    return {
        NEWCF(x, y, z),
        NEWCF(-x, y, z),
        NEWCF(x, y, -z),
        NEWCF(-x, y, -z),
        NEWCF(x, -minY, z),
        NEWCF(-x, -minY, z),
        NEWCF(x, -minY, -z),
        NEWCF(-x, -minY, -z)
    };
end;

function esp:returntriangleoffsets(triangle)
    local minX = MIN(triangle.PointA.X, triangle.PointB.X, triangle.PointC.X)
    local minY = MIN(triangle.PointA.Y, triangle.PointB.Y, triangle.PointC.Y)
    local maxX = MAX(triangle.PointA.X, triangle.PointB.X, triangle.PointC.X)
    local maxY = MAX(triangle.PointA.Y, triangle.PointB.Y, triangle.PointC.Y)
    return minX, minY, maxX, maxY
end

function esp:convertnumrange(val, oldmin, oldmax, newmin, newmax)
    return (val - oldmin) * (newmax - newmin) / (oldmax - oldmin) + newmin;
end;

function esp:fadeviadistance(data)
    return data.limit and 1 - CLAMP(self:convertnumrange(FLOOR(((data.cframe.p - camera.CFrame.p)).magnitude), (data.maxdistance - data.factor), data.maxdistance, 0, 1), 0, 1) or 1;
end;

function esp:floorvector(vector)
    return NEWVEC2(FLOOR(vector.X),FLOOR(vector.Y))
end
function esp:rotatevector2(v2, r)
	local c = COS(r);
	local s = SIN(r);
	return NEWVEC2(c * v2.X - s * v2.Y, s * v2.X + c * v2.Y);
end;
--
function esp:add(plr)
    if plr == localPlayer then return end
    local objs = {
        box_outline = esp:draw('Square', { Filled = false, Thickness = 1 }),
        box = esp:draw('Square', { Filled = false, Thickness = 1, Color = Color3.new(1,1,1) }),
        arrow_name_outline = esp:draw('Text', { Color = Color3.new(), Font = 2, Size = 13 }),
        arrow_name = esp:draw('Text', { Color = Color3.new(1,1,1), Font = 2, Size = 13 }),
        arrow_bar_outline = esp:draw('Square', { Filled = true, Thickness = 1 }),
        arrow_bar_inline = esp:draw('Square', { Filled = true, Thickness = 1, Color = Color3.new(0.3, 0.3, 0.3) }),
        arrow_bar = esp:draw('Square', { Filled = true, Thickness = 1, Color = Color3.new(1,1,1) }),
        arrow_outline = esp:draw('Triangle', { Filled = false, Thickness = 1 });
        arrow = esp:draw('Triangle', { Filled = true, Thickness = 1, });
        -- bars
        bar_outline = esp:draw('Square', { Filled = true, Thickness = 1 }),
        bar_inline = esp:draw('Square', { Filled = true, Thickness = 1, Color = Color3.new(0.3, 0.3, 0.3) }),
        bar = esp:draw('Square', { Filled = true, Thickness = 1, Color = Color3.new(1,1,1) }),
        -- text
        name_outline = esp:draw('Text', { Color = Color3.new(), Font = 2, Size = 13 }),
        name = esp:draw('Text', { Color = Color3.new(1,1,1), Font = 2, Size = 13 }),
        health = esp:draw('Text', { Color = Color3.new(1,1,1), Font = 2, Size = 13, Center = true })
    }
    self.players[plr.Name] = objs
end
function esp:disable(plr)
    local objects = self.players[plr.Name];
    if objects then
        for i, v in next, objects do
            v.Visible = false
        end;
    end;
end;
function esp:remove(plr)
    local objects = self.players[plr.Name];
    if objects then
        for i, v in next, objects do
            v:Remove()
        end;
    end;
    self.players[plr.Name] = nil;
end;
-- connections
function esp:connect(a, callback)
    local c = a:Connect(callback)
    table.insert(self.connections, c)
    return c
end

function esp:bindtorenderstep(name, priority, callback)
    local a = {}
    function a:Disconnect()
        runService:UnbindFromRenderStep(name)
    end
    runService:BindToRenderStep(name, priority, callback)
    table.insert(self.connections, a)
    return a
end

function esp:clearconnections()
    for _, c in next, self.connections do
        c:Disconnect()
    end
end
for i, plr in next, players:GetChildren() do
    esp:add(plr)
end
esp:connect(players.ChildAdded, function(plr)
    esp:add(plr)
end)
esp:connect(players.ChildRemoved, function(plr)
    esp:remove(plr)
end)

esp:connect(runService.RenderStepped, function()
    if esp.enabled then
        for plr, drawing in next, esp.players do
            local player = players:FindFirstChild(plr)
            if not player then esp.players[plr] = nil continue end
            if esp.enabled and esp.checkalive(player) then
                local character = esp.getcharacter(player)
                if not character:FindFirstChild("HumanoidRootPart") then
                    continue
                end
                local _, onScreen = camera:WorldToViewportPoint(character['HumanoidRootPart'].Position)
                local centerMassPos = character['HumanoidRootPart'].CFrame
                local transparency = esp:fadeviadistance({
                    limit = esp.limitdistance,
                    cframe = centerMassPos,
                    maxdistance = esp.maxdistance,
                    factor = esp.fadefactor
                })
                local health = FLOOR(character.Humanoid.Health)

                if not (esp:check(player) and onScreen) then
                    for i,v in next, drawing do
                        v.Visible = false
                    end
                end

                -- arrows
                drawing.arrow.Visible = esp.arrow[1] and esp:check(player);
                drawing.arrow_outline.Visible = drawing.arrow.Visible;
                if drawing.arrow.Visible then
                    local proj = camera.CFrame:PointToObjectSpace(centerMassPos.p);
                    local ang = ATAN2(proj.Z, proj.X);
                    local dir = NEWVEC2(COS(ang), SIN(ang));
                    local a = (dir * esp.arrowradius * .5) + camera.ViewportSize / 2;
                    local b, c = a - esp:rotatevector2(dir, RAD(35)) * esp.arrowsize, a - esp:rotatevector2(dir, (-RAD(35))) * esp.arrowsize;
                    drawing.arrow.PointA = a;
                    drawing.arrow.PointB = b;
                    drawing.arrow.PointC = c;
                    drawing.arrow.Color = not onScreen and esp.arrow[3] or esp.arrow[2];
                    drawing.arrow.Transparency = not onScreen and esp.arrow[5] or esp.arrow[4];
                    drawing.arrow_outline.PointA = a;
                    drawing.arrow_outline.PointB = b;
                    drawing.arrow_outline.PointC = c;
                    drawing.arrow_outline.Color = not onScreen and esp.arrow[3] or esp.arrow[2];
                    drawing.arrow_outline.Transparency = not onScreen and esp.arrow[5] or  esp.arrow[4];
                    if esp.arrowinfo then
                        local smallestX, smallestY, biggestX, biggestY = esp:returntriangleoffsets(drawing.arrow_outline)
                        -- healthbar
                        drawing.arrow_bar.Visible = not onScreen and drawing.arrow.Visible
                        drawing.arrow_bar_inline.Visible = drawing.arrow_bar.Visible
                        drawing.arrow_bar_outline.Visible = esp.outlines and drawing.arrow_bar.Visible
                        if drawing.arrow_bar.Visible then
                            esp:setproperties(drawing.arrow_bar, {
                                Color = esp.healthbar[3]:Lerp(esp.healthbar[2], health / 100),
                                Size = esp:floorvector(NEWVEC2(1, ( - health / 100 * ( biggestY - smallestY + 2)) + 3)),
                                Position = esp:floorvector(NEWVEC2(smallestX - 3, smallestY + drawing.arrow_bar_outline.Size.Y)),
                                Transparency = transparency
                            })
                            esp:setproperties(drawing.arrow_bar_inline, {
                                Size = esp:floorvector(NEWVEC2(1, ( - 1 * ( biggestY - smallestY + 2)) + 3)),
                                Position = drawing.arrow_bar.Position,
                                Transparency = transparency
                            })
                            esp:setproperties(drawing.arrow_bar_outline, {
                                Size = esp:floorvector(NEWVEC2(1, biggestY - smallestY)),
                                Position = esp:floorvector(NEWVEC2(smallestX - 2, smallestY + 1)),
                                Transparency = transparency
                            })
                        end

                        -- name
                        drawing.arrow_name.Visible = not onScreen and drawing.arrow.Visible
                        drawing.arrow_name_outline.Visible = esp.outlines and drawing.arrow_name.Visible
                        if drawing.arrow_name.Visible then
                            esp:setproperties(drawing.arrow_name, {
                                Text = plr,
                                Font = esp.font,
                                Size = esp.textsize,
                                Color = esp.names[2],
                                Position = esp:floorvector(NEWVEC2(smallestX + (biggestX - smallestX) / 2 - (drawing.arrow_name.TextBounds.X / 2), smallestY - drawing.arrow_name.TextBounds.Y - 2)),
                                Transparency = transparency
                            })
                            esp:setproperties(drawing.arrow_name_outline, {
                                Text = drawing.arrow_name.Text,
                                Font = drawing.arrow_name.Font,
                                Size = drawing.arrow_name.Size,
                                Position = drawing.arrow_name.Position + NEWVEC2(1,1),
                                Transparency = transparency
                            })
                        end
                    end
                end;


                if not esp:check(player) or (not onScreen) then
                    continue
                end


                local smallestX, biggestX = 1e5, -1e5
                local smallestY, biggestY = 1e5, -1e5

                local y = (centerMassPos.p - character['Head'].Position).magnitude + character['Head'].Size.Y / 2
                local x1 = (centerMassPos.p - character['LeftHand'].Position).magnitude
                local x2 = (centerMassPos.p - character['LeftHand'].Position).magnitude
                local minY1 = (centerMassPos.p - character['RightFoot'].Position).magnitude
                local minY2 = (centerMassPos.p - character['LeftFoot'].Position).magnitude

                local minY = minY1 > minY2 and minY1 or minY2
                local minX = x1 < x2 and x1 or x2

                local offsets = esp:returnoffsets(minX, y, minY, character['HumanoidRootPart'].Size.Z / 2)

                for i, v in next, offsets do
                    local pos = camera:WorldToViewportPoint(centerMassPos * v.p)
                    if smallestX > pos.X then smallestX = pos.X end
                    if biggestX < pos.X then biggestX = pos.X end
                    if smallestY > pos.Y then smallestY = pos.Y end
                    if biggestY < pos.Y then biggestY = pos.Y end
                end

                -- box
                drawing.box.Visible = esp.boxes[1]
                drawing.box_outline.Visible = esp.outlines and drawing.box.Visible
                if drawing.box.Visible then
                    esp:setproperties(drawing.box, {
                        Color = esp.boxes[2],
                        Size = esp:floorvector(NEWVEC2(biggestX - smallestX, biggestY - smallestY)),
                        Position = esp:floorvector(NEWVEC2(smallestX, smallestY)),
                        Transparency = transparency
                    })
                    esp:setproperties(drawing.box_outline, {
                        Size = esp:floorvector(NEWVEC2(biggestX - smallestX, biggestY - smallestY)),
                        Position = drawing.box.Position + NEWVEC2(1,1),
                        Transparency = transparency
                    })
                end

                -- healthbar
                drawing.bar.Visible = esp.healthbar[1]
                drawing.bar_inline.Visible = drawing.bar.Visible
                drawing.bar_outline.Visible = esp.outlines and drawing.bar.Visible
                if drawing.bar.Visible then
                    esp:setproperties(drawing.bar, {
                        Color = esp.healthbar[3]:Lerp(esp.healthbar[2], health / 100),
                        Size = esp:floorvector(NEWVEC2(1, ( - health / 100 * ( biggestY - smallestY + 2)) + 3)),
                        Position = esp:floorvector(NEWVEC2(smallestX - 3, smallestY + drawing.bar_outline.Size.Y)),
                        Transparency = transparency
                    })
                    esp:setproperties(drawing.bar_inline, {
                        Size = esp:floorvector(NEWVEC2(1, ( - 1 * ( biggestY - smallestY + 2)) + 3)),
                        Position = drawing.bar.Position,
                        Transparency = transparency
                    })
                    esp:setproperties(drawing.bar_outline, {
                        Size = esp:floorvector(NEWVEC2(1, biggestY - smallestY)),
                        Position = esp:floorvector(NEWVEC2(smallestX - 2, smallestY + 1)),
                        Transparency = transparency
                    })
                end

                -- name
                drawing.name.Visible = esp.names[1]
                drawing.name_outline.Visible = esp.outlines and drawing.name.Visible
                if drawing.name.Visible then
                    esp:setproperties(drawing.name, {
                        Text = plr,
                        Font = esp.font,
                        Size = esp.textsize,
                        Color = esp.names[2],
                        Position = esp:floorvector(NEWVEC2(smallestX + (biggestX - smallestX) / 2 - (drawing.name.TextBounds.X / 2), smallestY - drawing.name.TextBounds.Y - 2)),
                        Transparency = transparency
                    })
                    esp:setproperties(drawing.name_outline, {
                        Text = drawing.name.Text,
                        Font = drawing.name.Font,
                        Size = drawing.name.Size,
                        Position = drawing.name.Position + NEWVEC2(1,1),
                        Transparency = transparency
                    })
                end

                -- health
                drawing.health.Visible = health ~= 100 and health ~= 0  and esp.health
                if drawing.health.Visible then
                    esp:setproperties(drawing.health, {
                        Text = tostring(health),
                        Font = esp.font,
                        Size = esp.textsize,
                        Outline = esp.outlines,
                        Color = esp.healthbar[3]:Lerp(esp.healthbar[2], health / 100),
                        Position = esp:floorvector(NEWVEC2(smallestX - 3, drawing.bar.Position.Y + drawing.bar.Size.Y - drawing.health.TextBounds.Y + 5)),
                        Transparency = transparency
                    })
                end
            else
                esp:disable(player)
            end
        end
    end
end)

return esp
