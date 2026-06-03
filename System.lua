if _G.NBall == true then
	warn("Script 8Ball đã run, không thể run tiếp.")
	return
end
_G.NBall = true

-- Load UI
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/8BallAim/refs/heads/main/UI.lua"))()

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local BallGui = PlayerGui:WaitForChild("8BallGui")

local RotationL = BallGui:WaitForChild("RotationL")
local RotationR = BallGui:WaitForChild("RotationR")
local BackBall = BallGui:WaitForChild("BackBall")
local RotationMode = BallGui:WaitForChild("RotationMode")
local NextBall = BallGui:WaitForChild("NextBall")
local CueLine = BallGui:WaitForChild("CueLine")
local BallText = BallGui:WaitForChild("BallText")
local GuideRotation = BallGui:WaitForChild("GuideRotation")

local RotationCueL = BallGui:FindFirstChild("RotationCueL")
local RotationCueR = BallGui:FindFirstChild("RotationCueR")

local function tween(obj, timeSec, props)
	local tw = TweenService:Create(obj, TweenInfo.new(timeSec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function getStroke(obj)
	return obj and obj:FindFirstChildOfClass("UIStroke")
end

local function setText(obj, text)
	if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
		obj.Text = text
	end
end

local function setVisible(obj, state)
	if obj then
		obj.Visible = state
	end
end

local function updateGuideKeyPC()
	local hasKeys = UIS.KeyboardEnabled
	for _, obj in ipairs(BallGui:GetDescendants()) do
		if obj:IsA("TextLabel") and obj.Name == "GuideKeyPC" then
			obj.Visible = hasKeys
		end
	end
end

local MODE_POCKET_BG = Color3.fromRGB(50, 0, 0)
local MODE_POCKET_STROKE = Color3.fromRGB(255, 0, 0)
local MODE_ROT_BG = Color3.fromRGB(0, 50, 0)
local MODE_ROT_STROKE = Color3.fromRGB(0, 255, 0)

local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera
end)

local TablesFolder = Workspace:WaitForChild("ClassicTables")

for _, tbl in ipairs(TablesFolder:GetChildren()) do
	local barrier = tbl:FindFirstChild("Barrier")
	if barrier then
		barrier:Destroy()
	end
end

local MODE_POCKET = 1
local MODE_PREDICT = 2
local mode = MODE_POCKET

local currentTable
local balls = {}
local cueBallPart = nil
local pockets = {}
local tableObstacles = {}

local ballIndex = 1
local aimAngle = 0
local cueAngle = 0

local pocketNames = {"BL", "BM", "BR", "TL", "TM", "TR"}
local POCKET_RADIUS = 1
local MAX_BOUNCES = 3
local MAX_CUE_BOUNCES = 4
local MAX_DRAW_EVENTS = 128
local MAX_CUE_DRAW_EVENTS = MAX_CUE_BOUNCES + 1
local RAY_LENGTH = 500

local GLOW_TRANSPARENCY = 0.75
local ROTATE_SPEED = math.rad(120)
local FINE_ROTATE_MULT = 0.05

local ROOT_COLOR = Color3.fromRGB(0, 255, 0)
local CHILD_COLOR = Color3.fromRGB(255, 255, 0)
local HIT_COLOR = Color3.fromRGB(255, 170, 0)
local CUE_COLOR = Color3.fromRGB(255, 255, 255)

local cueEnabled = false
local holdingQ = false
local holdingE = false
local holdingShift = false
local holdingB = false
local holdingN = false

local VisualFolder = Workspace:FindFirstChild("TableVisuals")
if VisualFolder then
	VisualFolder:Destroy()
end

VisualFolder = Instance.new("Folder")
VisualFolder.Name = "TableVisuals"
VisualFolder.Parent = Workspace

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
wallParams.IgnoreWater = true

local function newBeam(defaultColor)
	local p0 = Instance.new("Part")
	p0.Anchored = true
	p0.CanCollide = false
	p0.CanTouch = false
	p0.CanQuery = false
	p0.Transparency = 1
	p0.Size = Vector3.new(0.1, 0.1, 0.1)
	p0.Parent = VisualFolder

	local p1 = Instance.new("Part")
	p1.Anchored = true
	p1.CanCollide = false
	p1.CanTouch = false
	p1.CanQuery = false
	p1.Transparency = 1
	p1.Size = Vector3.new(0.1, 0.1, 0.1)
	p1.Parent = VisualFolder

	local a0 = Instance.new("Attachment")
	a0.Parent = p0

	local a1 = Instance.new("Attachment")
	a1.Parent = p1

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Width0 = 0.08
	beam.Width1 = 0.08
	beam.Color = ColorSequence.new(defaultColor)
	beam.Transparency = NumberSequence.new(0)
	beam.Enabled = false
	beam.Parent = p0

	return {
		p0 = p0,
		p1 = p1,
		beam = beam,
		Set = function(self, fromPos, toPos, color, width, transparency)
			self.p0.Position = fromPos
			self.p1.Position = toPos
			self.beam.Color = ColorSequence.new(color)
			self.beam.Width0 = width
			self.beam.Width1 = width
			if transparency ~= nil then
				self.beam.Transparency = NumberSequence.new(transparency)
			end
			self.beam.Enabled = true
		end,
		Hide = function(self)
			self.beam.Enabled = false
		end,
		Destroy = function(self)
			self.p0:Destroy()
			self.p1:Destroy()
		end,
	}
end

local function newCircle(defaultColor)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Parent = VisualFolder

	local function makeGui(baseSize, strokeThickness, strokeTransparency)
		local bb = Instance.new("BillboardGui")
		bb.AlwaysOnTop = true
		bb.MaxDistance = 100000
		bb.Size = UDim2.fromOffset(baseSize, baseSize)
		bb.StudsOffsetWorldSpace = Vector3.zero
		bb.Enabled = false
		bb.Parent = part

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Parent = bb

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Color = defaultColor
		stroke.Thickness = strokeThickness
		stroke.Transparency = strokeTransparency
		stroke.Parent = frame

		return bb, stroke
	end

	local glowGui, glowStroke = makeGui(28, 8, 0.75)
	local coreGui, coreStroke = makeGui(18, 2, 0)

	return {
		part = part,
		coreGui = coreGui,
		glowGui = glowGui,
		coreStroke = coreStroke,
		glowStroke = glowStroke,
		Set = function(self, pos, color, sizePx)
			self.part.Position = pos
			self.coreGui.Size = UDim2.fromOffset(sizePx, sizePx)
			self.glowGui.Size = UDim2.fromOffset(sizePx + 14, sizePx + 14)
			self.coreStroke.Color = color
			self.glowStroke.Color = color
			self.coreGui.Enabled = true
			self.glowGui.Enabled = true
		end,
		Hide = function(self)
			self.coreGui.Enabled = false
			self.glowGui.Enabled = false
		end,
		Destroy = function(self)
			self.part:Destroy()
		end,
	}
end

local function makeBeamPool(count, color)
	local t = table.create(count)
	for i = 1, count do
		t[i] = newBeam(color)
	end
	return t
end

local function makeCirclePool(count, color)
	local t = table.create(count)
	for i = 1, count do
		t[i] = newCircle(color)
	end
	return t
end

local pocketLines = makeBeamPool(6, ROOT_COLOR)
local pocketGlowLines = makeBeamPool(6, ROOT_COLOR)

local predLines = makeBeamPool(MAX_DRAW_EVENTS, ROOT_COLOR)
local predGlowLines = makeBeamPool(MAX_DRAW_EVENTS, ROOT_COLOR)

local cuePredLines = makeBeamPool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)
local cuePredGlowLines = makeBeamPool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)

local bounceCircles = makeCirclePool(MAX_DRAW_EVENTS, CHILD_COLOR)
local ballHitCircles = makeCirclePool(MAX_DRAW_EVENTS, HIT_COLOR)
local ballHitLines = makeBeamPool(MAX_DRAW_EVENTS, HIT_COLOR)
local ballHitGlowLines = makeBeamPool(MAX_DRAW_EVENTS, HIT_COLOR)
local ballPushLines = makeBeamPool(MAX_DRAW_EVENTS, HIT_COLOR)
local ballPushGlowLines = makeBeamPool(MAX_DRAW_EVENTS, HIT_COLOR)

local cueBounceCircles = makeCirclePool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)
local cueBallHitCircles = makeCirclePool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)
local cueBallHitLines = makeBeamPool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)
local cueBallHitGlowLines = makeBeamPool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)
local cueBallPushLines = makeBeamPool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)
local cueBallPushGlowLines = makeBeamPool(MAX_CUE_DRAW_EVENTS, CUE_COLOR)

local function hidePool(pool)
	for i = 1, #pool do
		pool[i]:Hide()
	end
end

local function hidePocketLines()
	hidePool(pocketLines)
	hidePool(pocketGlowLines)
end

local function hidePredictLines()
	hidePool(predLines)
	hidePool(predGlowLines)
	hidePool(ballPushLines)
	hidePool(ballPushGlowLines)
end

local function hideCuePredictLines()
	hidePool(cuePredLines)
	hidePool(cuePredGlowLines)
	hidePool(cueBallPushLines)
	hidePool(cueBallPushGlowLines)
end

local function hideBounceCircles()
	hidePool(bounceCircles)
end

local function hideBallHitMarkers()
	hidePool(ballHitCircles)
	hidePool(ballHitLines)
	hidePool(ballHitGlowLines)
	hidePool(ballPushLines)
	hidePool(ballPushGlowLines)
end

local function hideCueBounceCircles()
	hidePool(cueBounceCircles)
end

local function hideCueBallHitMarkers()
	hidePool(cueBallHitCircles)
	hidePool(cueBallHitLines)
	hidePool(cueBallHitGlowLines)
	hidePool(cueBallPushLines)
	hidePool(cueBallPushGlowLines)
end

local function hideAll()
	hidePocketLines()
	hidePredictLines()
	hideCuePredictLines()
	hideBounceCircles()
	hideBallHitMarkers()
	hideCueBounceCircles()
	hideCueBallHitMarkers()
end

local function getBallScreenDiameter(ball)
	local radius = ball.Size.X / 2
	local pos = ball.Position
	local offset = pos + Vector3.new(radius, 0, 0)

	local p1 = Camera:WorldToViewportPoint(pos)
	local p2 = Camera:WorldToViewportPoint(offset)

	local screenRadius = (Vector2.new(p1.X, p1.Y) - Vector2.new(p2.X, p2.Y)).Magnitude
	return math.max(1, screenRadius * 2)
end

local function getClosestTable()
	local closest
	local closestDist = math.huge

	for _, tbl in ipairs(TablesFolder:GetChildren()) do
		local camPart = tbl:FindFirstChild("Camera")
		if camPart then
			local dist = (Camera.CFrame.Position - camPart.Position).Magnitude
			if dist < closestDist then
				closestDist = dist
				closest = tbl
			end
		end
	end

	return closest
end

local function setupTable(tbl)
	pockets = {}
	tableObstacles = {}
	cueBallPart = nil

	local pocketModel = tbl:FindFirstChild("PocketPoints")
	if pocketModel then
		for _, name in ipairs(pocketNames) do
			local part = pocketModel:FindFirstChild(name)
			if part then
				table.insert(pockets, part)
			end
		end
	end

	local ballsModel = tbl:FindFirstChild("Balls")
	for _, inst in ipairs(tbl:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name ~= "Camera" then
			if not (ballsModel and inst:IsDescendantOf(ballsModel)) and not (pocketModel and inst:IsDescendantOf(pocketModel)) then
				if inst.CanQuery ~= false then
					table.insert(tableObstacles, inst)
				end
			end
		end
	end

	wallParams.FilterDescendantsInstances = tableObstacles
	ballIndex = 1
	hideAll()
end

local function ballNearPocket(ball)
	for _, pocket in ipairs(pockets) do
		if (ball.Position - pocket.Position).Magnitude <= POCKET_RADIUS then
			return true
		end
	end
	return false
end

local function updateBalls()
	table.clear(balls)
	cueBallPart = nil

	if not currentTable then
		return
	end

	local ballsModel = currentTable:FindFirstChild("Balls")
	if not ballsModel then
		return
	end

	cueBallPart = ballsModel:FindFirstChild("Cue")

	for _, p in ipairs(ballsModel:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Cue" then
			if not ballNearPocket(p) then
				table.insert(balls, p)
			end
		end
	end

	if #balls == 0 then
		ballIndex = 1
		return
	end

	if ballIndex > #balls then
		ballIndex = 1
	elseif ballIndex < 1 then
		ballIndex = #balls
	end
end

local function setPredictAngleFromCamera()
	local lv = Camera.CFrame.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude > 1e-6 then
		flat = flat.Unit
		aimAngle = math.atan2(flat.Z, flat.X)
	end
end

local function setCueAngleFromCamera()
	local lv = Camera.CFrame.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude > 1e-6 then
		flat = flat.Unit
		cueAngle = math.atan2(flat.Z, flat.X)
	end
end

local function getForwardDirFromAngle(angle)
	local v = Vector3.new(math.cos(angle), 0, math.sin(angle))
	return v.Magnitude > 1e-6 and v.Unit or Vector3.new(1, 0, 0)
end

local function colorForDepth(depth, rootColor, childColor, hitColor)
	if depth <= 1 then
		return rootColor
	elseif depth == 2 then
		return childColor
	else
		return hitColor
	end
end

local function getWallCollision(center, dir, radius)
	if #tableObstacles == 0 then
		return nil
	end

	local result = Workspace:Raycast(center, dir * RAY_LENGTH, wallParams)
	if not result then
		return nil
	end

	local normal = Vector3.new(result.Normal.X, 0, result.Normal.Z)
	if normal.Magnitude < 1e-6 then
		return nil
	end

	normal = normal.Unit
	local dn = -dir:Dot(normal)
	if dn <= 1e-6 then
		return nil
	end

	local surfaceDist = (result.Position - center):Dot(dir)
	local t = surfaceDist - (radius / dn)
	if t <= 1e-4 then
		return nil
	end

	return {
		t = t,
		center = center + dir * t,
		normal = normal,
	}
end

local function getBallCollision(center, dir, radius, currentBall, ballsModel, ignoreBall)
	local d2 = Vector2.new(dir.X, dir.Z)
	if d2.Magnitude < 1e-6 then
		return nil
	end
	d2 = d2.Unit

	local o2 = Vector2.new(center.X, center.Z)
	local best

	for _, other in ipairs(balls) do
		if other ~= currentBall and other ~= ignoreBall and other.Parent == ballsModel then
			local otherR = other.Size.X / 2
			local sumR = radius + otherR
			local c2 = Vector2.new(other.Position.X, other.Position.Z)
			local oc = o2 - c2

			local a = d2:Dot(d2)
			local b = 2 * oc:Dot(d2)
			local c = oc:Dot(oc) - (sumR * sumR)
			local disc = b * b - 4 * a * c

			if disc >= 0 then
				local s = math.sqrt(disc)
				local t1 = (-b - s) / (2 * a)
				local t2 = (-b + s) / (2 * a)
				local t

				if t1 > 1e-4 then
					t = t1
				elseif t2 > 1e-4 then
					t = t2
				end

				if t and (not best or t < best.t) then
					local contactCenter = center + dir * t
					local n = Vector3.new(contactCenter.X - other.Position.X, 0, contactCenter.Z - other.Position.Z)
					if n.Magnitude > 1e-6 then
						n = n.Unit
						local cueNextDir = dir - dir:Dot(n) * n
						best = {
							t = t,
							center = contactCenter,
							other = other,
							normal = n,
							cueNextDir = cueNextDir,
							targetDir = -n,
						}
					end
				end
			end
		end
	end

	return best
end

local function buildPrediction(sourceBall, angle, maxBounces)
	local events = {}
	if not currentTable or not sourceBall then
		return events
	end

	local ballsModel = currentTable:FindFirstChild("Balls")
	if not ballsModel then
		return events
	end

	local radius = sourceBall.Size.X / 2
	local dir = getForwardDirFromAngle(angle)
	local center = sourceBall.Position
	local ignoreBall = nil

	for depth = 1, maxBounces + 1 do
		local wallHit = getWallCollision(center, dir, radius)
		local ballHit = getBallCollision(center, dir, radius, sourceBall, ballsModel, ignoreBall)

		local choice
		if wallHit and ballHit then
			choice = (ballHit.t < wallHit.t) and { kind = "ball", data = ballHit, depth = depth } or { kind = "wall", data = wallHit, depth = depth }
		elseif wallHit then
			choice = { kind = "wall", data = wallHit, depth = depth }
		elseif ballHit then
			choice = { kind = "ball", data = ballHit, depth = depth }
		else
			table.insert(events, {
				kind = "end",
				from = center,
				to = center + dir * RAY_LENGTH,
				depth = depth,
			})
			break
		end

		if choice.kind == "wall" then
			local hit = choice.data
			table.insert(events, {
				kind = "wall",
				from = center,
				to = hit.center,
				center = hit.center,
				depth = depth,
			})

			local reflected = dir - 2 * dir:Dot(hit.normal) * hit.normal
			reflected = Vector3.new(reflected.X, 0, reflected.Z)
			if reflected.Magnitude < 1e-6 then
				break
			end

			dir = reflected.Unit
			center = hit.center

		elseif choice.kind == "ball" then
			local hit = choice.data
			table.insert(events, {
				kind = "ball",
				from = center,
				to = hit.center,
				center = hit.center,
				depth = depth,
				hitBall = hit.other,
				hitDir = hit.targetDir,
			})

			local nextDir = hit.cueNextDir
			nextDir = Vector3.new(nextDir.X, 0, nextDir.Z)
			if nextDir.Magnitude < 1e-6 then
				break
			end

			dir = nextDir.Unit
			center = hit.center
			ignoreBall = hit.other
		end
	end

	return events
end

local function getGlowWidth(part)
	return math.max(part.Size.X, 0.08)
end

local function setLine(lineObj, glowObj, fromPos, toPos, color, width, glowWidth)
	lineObj:Set(fromPos, toPos, color, width, 0)
	glowObj:Set(fromPos, toPos, color, glowWidth or width * 3, GLOW_TRANSPARENCY)
end

local function setMarker(markerObj, pos, color, sizePx)
	markerObj:Set(pos, color, sizePx)
end

local function drawHitDirection(lineObj, glowObj, origin3D, dir3D, length, color, width)
	local d = dir3D
	if d.Magnitude < 1e-6 then
		d = Vector3.new(1, 0, 0)
	else
		d = d.Unit
	end

	local endPos = origin3D + d * length
	setLine(lineObj, glowObj, origin3D, endPos, color, width)
end

GuideRotation.TextTransparency = 1
local guideShown = false
local lastRotateTime = 0

local function showGuideRotation()
	lastRotateTime = os.clock()
	if not guideShown then
		guideShown = true
		tween(GuideRotation, 0.2, { TextTransparency = 0.25 })
	end
end

local function hideGuideRotation()
	if guideShown then
		guideShown = false
		tween(GuideRotation, 0.2, { TextTransparency = 1 })
	end
end

local function updateBallText()
	local ball = balls[ballIndex]
	if ball then
		BallText.Text = "Ball [" .. ball.Name .. "]"
	else
		BallText.Text = "Ball [None]"
	end
end

local function updateRotationModeUI()
	local stroke = getStroke(RotationMode)
	if mode == MODE_POCKET then
		tween(RotationMode, 0.2, { BackgroundColor3 = MODE_POCKET_BG })
		if stroke then
			tween(stroke, 0.2, { Color = MODE_POCKET_STROKE })
		end
	else
		tween(RotationMode, 0.2, { BackgroundColor3 = MODE_ROT_BG })
		if stroke then
			tween(stroke, 0.2, { Color = MODE_ROT_STROKE })
		end
	end
end

local function updateCueLineUI()
	CueLine.Text = cueEnabled and "Cue line [on]" or "Cue line [off]"
end

local cueLineShownPos = CueLine.Position
local cueLineHiddenPos = UDim2.new(cueLineShownPos.X.Scale, cueLineShownPos.X.Offset, 1.25, cueLineShownPos.Y.Offset)

local function updateCueLineVisibility()
	if mode == MODE_PREDICT then
		CueLine.Visible = true
		tween(CueLine, 0.25, { Position = cueLineShownPos })
	else
		tween(CueLine, 0.25, { Position = cueLineHiddenPos })
		task.delay(0.26, function()
			if CueLine then
				CueLine.Visible = false
			end
		end)
	end
end

local cueBtnShownPosL = RotationCueL and RotationCueL.Position
local cueBtnShownPosR = RotationCueR and RotationCueR.Position
local cueBtnHiddenPosL = RotationCueL and UDim2.new(cueBtnShownPosL.X.Scale, cueBtnShownPosL.X.Offset, 1.25, cueBtnShownPosL.Y.Offset)
local cueBtnHiddenPosR = RotationCueR and UDim2.new(cueBtnShownPosR.X.Scale, cueBtnShownPosR.X.Offset, 1.25, cueBtnShownPosR.Y.Offset)

local function slideTo(gui, shownPos, hiddenPos, show, timeSec)
	if not gui then
		return
	end

	if show then
		gui.Visible = true
		tween(gui, timeSec or 0.25, { Position = shownPos })
	else
		tween(gui, timeSec or 0.25, { Position = hiddenPos })
		task.delay((timeSec or 0.25) + 0.03, function()
			if gui then
				gui.Visible = false
			end
		end)
	end
end

local function updateCueRotateButtons()
	local show = (mode == MODE_PREDICT and cueEnabled)
	slideTo(RotationCueL, cueBtnShownPosL, cueBtnHiddenPosL, show, 0.25)
	slideTo(RotationCueR, cueBtnShownPosR, cueBtnHiddenPosR, show, 0.25)
end

local function updateMainControls()
	if mode == MODE_POCKET then
		BackBall.Visible = true
		NextBall.Visible = true
		RotationL.Visible = false
		RotationR.Visible = false
	else
		BackBall.Visible = false
		NextBall.Visible = false
		RotationL.Visible = true
		RotationR.Visible = true
	end
end

local function syncMainUI()
	updateBallText()
	updateRotationModeUI()
	updateCueLineUI()
	updateCueLineVisibility()
	updateCueRotateButtons()
	updateMainControls()
end

local function pressBallBack()
	if mode == MODE_POCKET then
		ballIndex -= 1
		if ballIndex < 1 then
			ballIndex = #balls
		end
		updateBallText()
	end
end

local function pressBallNext()
	if mode == MODE_POCKET then
		ballIndex += 1
		if ballIndex > #balls then
			ballIndex = 1
		end
		updateBallText()
	end
end

local function setRotationHold(btn, onDown, onUp)
	if not btn then
		return
	end

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onDown()
		end
	end)

	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onUp()
		end
	end)
end

local function stopRotationHolds()
	holdingQ = false
	holdingE = false
	holdingB = false
	holdingN = false
end

local function setMode(newMode)
	if mode == newMode then
		return
	end

	mode = newMode
	stopRotationHolds()

	if mode == MODE_PREDICT then
		setPredictAngleFromCamera()
		if cueEnabled then
			setCueAngleFromCamera()
		end
	end

	hideAll()
	syncMainUI()
end

local function toggleCueLine()
	if mode ~= MODE_PREDICT then
		return
	end

	cueEnabled = not cueEnabled
	if cueEnabled then
		setCueAngleFromCamera()
	end

	updateCueLineUI()
	updateCueRotateButtons()
end

BackBall.Activated:Connect(pressBallBack)
NextBall.Activated:Connect(pressBallNext)

RotationMode.Activated:Connect(function()
	if mode == MODE_POCKET then
		setMode(MODE_PREDICT)
	else
		setMode(MODE_POCKET)
	end
end)

CueLine.Activated:Connect(toggleCueLine)

setRotationHold(RotationL, function()
	if mode == MODE_PREDICT then
		holdingQ = true
	end
end, function()
	holdingQ = false
end)

setRotationHold(RotationR, function()
	if mode == MODE_PREDICT then
		holdingE = true
	end
end, function()
	holdingE = false
end)

setRotationHold(RotationCueL, function()
	if mode == MODE_PREDICT and cueEnabled then
		holdingB = true
	end
end, function()
	holdingB = false
end)

setRotationHold(RotationCueR, function()
	if mode == MODE_PREDICT and cueEnabled then
		holdingN = true
	end
end, function()
	holdingN = false
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		holdingShift = true
	end

	if input.KeyCode == Enum.KeyCode.G then
		if mode == MODE_POCKET then
			setMode(MODE_PREDICT)
		else
			setMode(MODE_POCKET)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.H then
		toggleCueLine()
		return
	end

	if mode == MODE_POCKET then
		if input.KeyCode == Enum.KeyCode.E then
			pressBallNext()
		elseif input.KeyCode == Enum.KeyCode.Q then
			pressBallBack()
		end
	else
		if input.KeyCode == Enum.KeyCode.E then
			holdingE = true
		elseif input.KeyCode == Enum.KeyCode.Q then
			holdingQ = true
		elseif input.KeyCode == Enum.KeyCode.Z then
			holdingB = true
		elseif input.KeyCode == Enum.KeyCode.X then
			holdingN = true
		end
	end
end)

UIS.InputEnded:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		holdingShift = false
	end

	if input.KeyCode == Enum.KeyCode.E then
		holdingE = false
	elseif input.KeyCode == Enum.KeyCode.Q then
		holdingQ = false
	elseif input.KeyCode == Enum.KeyCode.Z then
		holdingB = false
	elseif input.KeyCode == Enum.KeyCode.X then
		holdingN = false
	end
end)

updateGuideKeyPC()
syncMainUI()

RunService.RenderStepped:Connect(function(dt)
	local closest = getClosestTable()

	if closest ~= currentTable then
		currentTable = closest
		if currentTable then
			setupTable(currentTable)
			syncMainUI()
		end
	end

	updateBalls()
	updateBallText()

	local ball = balls[ballIndex]
	if not ball then
		hideAll()
		return
	end

	if mode == MODE_PREDICT then
		local speed = ROTATE_SPEED
		if holdingShift then
			speed *= FINE_ROTATE_MULT
		end

		if holdingE then
			aimAngle += speed * dt
		end
		if holdingQ then
			aimAngle -= speed * dt
		end

		if cueEnabled then
			local cueSpeed = ROTATE_SPEED
			if holdingShift then
				cueSpeed *= FINE_ROTATE_MULT
			end

			if holdingN then
				cueAngle += cueSpeed * dt
			end
			if holdingB then
				cueAngle -= cueSpeed * dt
			end
		end
	end

	local ballPos, ballOnScreen = Camera:WorldToViewportPoint(ball.Position)
	if not ballOnScreen then
		hideAll()
		return
	end

	local ballDiameter = getBallScreenDiameter(ball)
	local lineWidth = math.clamp(ball.Size.X * 0.04, 0.05, 0.12)

	if mode == MODE_POCKET then
		hidePredictLines()
		hideCuePredictLines()
		hideBounceCircles()
		hideBallHitMarkers()
		hideCueBounceCircles()
		hideCueBallHitMarkers()

		for i, pocket in ipairs(pockets) do
			local pocketFlat = Vector3.new(pocket.Position.X, ball.Position.Y, pocket.Position.Z)
			setLine(pocketLines[i], pocketGlowLines[i], ball.Position, pocketFlat, ROOT_COLOR, lineWidth, getGlowWidth(ball))
		end
	else
		hidePocketLines()

		local events = buildPrediction(ball, aimAngle, MAX_BOUNCES)
		local cueEvents = nil
		if cueEnabled and cueBallPart then
			cueEvents = buildPrediction(cueBallPart, cueAngle, MAX_CUE_BOUNCES)
		end

		hideBounceCircles()
		hideBallHitMarkers()
		hideCueBounceCircles()
		hideCueBallHitMarkers()

		for i, ev in ipairs(events) do
			local col = colorForDepth(ev.depth or 1, ROOT_COLOR, CHILD_COLOR, HIT_COLOR)

			if ev.kind == "wall" and ev.center and bounceCircles[i] then
				local sizePx = math.clamp(ballDiameter, 14, 42)
				setMarker(bounceCircles[i], ev.center, col, sizePx)

			elseif ev.kind == "ball" and ev.center and ev.hitBall then
				local sizePx = math.clamp(ballDiameter, 14, 42)
				setMarker(bounceCircles[i], ev.center, col, sizePx)

				local hit = ev.hitBall
				local hitDiameter = getBallScreenDiameter(hit)
				local hitSizePx = math.clamp(hitDiameter, 14, 42)
				setMarker(ballHitCircles[i], hit.Position, col, hitSizePx)

				local hitWidth = math.clamp(hit.Size.X * 0.04, 0.05, 0.12)
				local hitDir = ev.hitDir or Vector3.new(1, 0, 0)

				setLine(ballHitLines[i], ballHitGlowLines[i], hit.Position, hit.Position + hitDir.Unit * hit.Size.X, col, hitWidth, getGlowWidth(hit))
				drawHitDirection(ballPushLines[i], ballPushGlowLines[i], hit.Position, hitDir, hit.Size.X, col, hitWidth)
			end
		end

		for i = 1, MAX_DRAW_EVENTS do
			local ev = events[i]
			if ev then
				local col = colorForDepth(ev.depth or 1, ROOT_COLOR, CHILD_COLOR, HIT_COLOR)
				setLine(predLines[i], predGlowLines[i], ev.from, ev.to, col, lineWidth, getGlowWidth(ball))
			else
				predLines[i]:Hide()
				predGlowLines[i]:Hide()
			end
		end

		if cueEnabled and cueBallPart and cueEvents then
			local cueDiameter = getBallScreenDiameter(cueBallPart)
			local cueWidth = math.clamp(cueBallPart.Size.X * 0.04, 0.05, 0.12)

			for i = 1, MAX_CUE_DRAW_EVENTS do
				local ev = cueEvents[i]
				if ev then
					setLine(cuePredLines[i], cuePredGlowLines[i], ev.from, ev.to, CUE_COLOR, cueWidth, getGlowWidth(cueBallPart))
				else
					cuePredLines[i]:Hide()
					cuePredGlowLines[i]:Hide()
				end
			end

			for i, ev in ipairs(cueEvents) do
				if ev.kind == "wall" and ev.center and cueBounceCircles[i] then
					local sizePx = math.clamp(cueDiameter, 14, 42)
					setMarker(cueBounceCircles[i], ev.center, CUE_COLOR, sizePx)

				elseif ev.kind == "ball" and ev.center and ev.hitBall then
					local sizePx = math.clamp(cueDiameter, 14, 42)
					setMarker(cueBounceCircles[i], ev.center, CUE_COLOR, sizePx)

					local hit = ev.hitBall
					local hitDiameter = getBallScreenDiameter(hit)
					local hitSizePx = math.clamp(hitDiameter, 14, 42)
					setMarker(cueBallHitCircles[i], hit.Position, CUE_COLOR, hitSizePx)

					local hitWidth = math.clamp(hit.Size.X * 0.04, 0.05, 0.12)
					local hitDir = ev.hitDir or Vector3.new(1, 0, 0)

					setLine(cueBallHitLines[i], cueBallHitGlowLines[i], hit.Position, hit.Position + hitDir.Unit * hit.Size.X, CUE_COLOR, hitWidth, getGlowWidth(hit))
					drawHitDirection(cueBallPushLines[i], cueBallPushGlowLines[i], hit.Position, hitDir, hit.Size.X, CUE_COLOR, hitWidth)
				end
			end
		else
			hideCuePredictLines()
			hideCueBounceCircles()
			hideCueBallHitMarkers()
		end
	end

	local rotating = holdingQ or holdingE or (cueEnabled and (holdingB or holdingN))
	if mode == MODE_PREDICT then
		if rotating then
			showGuideRotation()
		elseif os.clock() - lastRotateTime >= 3 then
			hideGuideRotation()
		end
	end
end)
