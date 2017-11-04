-----------------------------------------------------------------------------------------------
-- Client Lua Script for BenikUI_ShortcutBar
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "Unit"
require "ActionSetLib"

local BenikUI_ShortcutBar = {}
local knVersion			= 1
local knMaxBars			= ActionSetLib.CodeEnumShortcutSet.Count
local knStartingBar		= 4 -- Skip 1 to 3, as that is the Engineer Bar and Engineer Pet Bars, which is handled in EngineerResource

function BenikUI_ShortcutBar:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function BenikUI_ShortcutBar:Init()
	Apollo.RegisterAddon(self, nil, nil, {"BenikUI_ActionBar"})
end

function BenikUI_ShortcutBar:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("BenikUI_ShortcutBar.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	self.bDocked = false
	self.bHorz = true
end

function BenikUI_ShortcutBar:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local tSavedData =
	{
		nVersion = knVersion,
		bDocked = self.bDocked,
		bHorz = self.bHorz,
	}

	return tSavedData
end

function BenikUI_ShortcutBar:OnRestore(eType, tSavedData)
	if tSavedData.nVersion ~= knVersion then
		return
	end

	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	if tSavedData.bDocked ~= nil then
		self.bDocked = tSavedData.bDocked
	end

	if tSavedData.bHorz ~= nil then
		self.bHorz = tSavedData.bHorz
	end

	self.tSavedData = tSavedData
end

function BenikUI_ShortcutBar:OnDocumentReady()
	self.bTimerRunning = false
	self.timerShorcutArt = ApolloTimer.Create(0.5, false, "OnActionBarShortcutArtTimer", self)
	self.timerShorcutArt:Stop()
	Apollo.RegisterEventHandler("ShowActionBarShortcut", "ShowWindow", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", "OnTutorial_RequestUIAnchor", self)

	local tShortcutCount = {}

	self.tActionBarSettings = {}

	--Floating Bar - Docked
	self.tActionBars = {}
	for idx = knStartingBar, knMaxBars do
		local wndCurrBar = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcut", "FixedHudStratumHigh5", self)
		wndCurrBar:FindChild("ActionBarContainer"):DestroyChildren() -- TODO can remove
		wndCurrBar:Show(false)

		for nButton = 0, 7 do
			local wndBarItem = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcutItem", wndCurrBar:FindChild("ActionBarContainer"), self)
			wndBarItem:FindChild("ActionBarShortcutBtn"):SetContentId(idx * 12 + nButton)
			if wndBarItem:FindChild("ActionBarShortcutBtn"):GetContent()["strIcon"] ~= "" then
				tShortcutCount[idx] = nButton + 1
			end

			wndCurrBar:FindChild("ActionBarContainer"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
		end

		wndCurrBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		wndCurrBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
		self.tActionBars[idx] = wndCurrBar
	end

	--Floating Bar - Horizontal
	self.tActionBarsHorz = {}
	for idx = knStartingBar, knMaxBars do
		local wndCurrBar = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcutHorz", nil, self)
		wndCurrBar:FindChild("ActionBarContainer"):DestroyChildren() -- TODO can remove
		wndCurrBar:Show(false)

		for nButton = 0, 7 do
			local wndBarItem = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcutItem", wndCurrBar:FindChild("ActionBarContainer"), self)
			wndBarItem:FindChild("ActionBarShortcutBtn"):SetContentId(idx * 12 + nButton)
			if wndBarItem:FindChild("ActionBarShortcutBtn"):GetContent()["strIcon"] ~= "" then
				tShortcutCount[idx] = nButton + 1
			end

			wndCurrBar:FindChild("ActionBarContainer"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
		end

		wndCurrBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		wndCurrBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
		self.tActionBarsHorz[idx] = wndCurrBar
	end

	--Floating Bar - Vertical
	self.tActionBarsVert = {}
	for idx = knStartingBar, knMaxBars do
		local wndCurrBar = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcutVert", nil, self)
		wndCurrBar:FindChild("ActionBarContainer"):DestroyChildren() -- TODO can remove
		wndCurrBar:Show(false)

		for nButton = 0, 7 do
			local wndBarItem = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcutItem", wndCurrBar:FindChild("ActionBarContainer"), self)
			wndBarItem:FindChild("ActionBarShortcutBtn"):SetContentId(idx * 12 + nButton)
			if wndBarItem:FindChild("ActionBarShortcutBtn"):GetContent()["strIcon"] ~= "" then
				tShortcutCount[idx] = nButton + 1
			end

			wndCurrBar:FindChild("ActionBarContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
		end

		wndCurrBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		wndCurrBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
		self.tActionBarsVert[idx] = wndCurrBar
	end

	for idx = knStartingBar, knMaxBars do
		self:ShowWindow(idx, IsActionBarSetVisible(idx), tShortcutCount[idx])
	end
end

function BenikUI_ShortcutBar:GetBarPosition(wndBar)
	if not wndBar then
		return {}
	end

	local tAnchors = {}
	tAnchors.nLeft, tAnchors.nTop, tAnchors.nRight, tAnchors.nBottom = wndBar:GetAnchorOffsets()

	local tSize = {}
	tSize.nWidth = wndBar:GetWidth()
	tSize.nHeight = wndBar:GetHeight()

	local tCenter = {}
	tCenter.nX = (tAnchors.nLeft + tAnchors.nRight) / 2
	tCenter.nY = (tAnchors.nTop + tAnchors.nBottom) / 2

	return { tSize = tSize, tCenter = tCenter }
end

function BenikUI_ShortcutBar:SetBarPosition(wndBar, tArgSize, tArgCenter)
	if  tArgSize == nil then
		tArgSize = {}
	end

	if  tArgCenter == nil then
		tArgCenter = {}
	end

	local tPosition = self:GetBarPosition(wndBar)

	local tHalf = {}
	tHalf.nWidth = (tArgSize.nWidth or tPosition.tSize.nWidth) / 2
	tHalf.nHeight = (tArgSize.nHeight or tPosition.tSize.nHeight) / 2

	local tCenter = {}
	tCenter.nX = tArgCenter.nX or tPosition.tCenter.nX
	tCenter.nY = tArgCenter.nY or tPosition.tCenter.nY

	local tDisplay = Apollo.GetDisplaySize()
	if tDisplay and tDisplay.nWidth then
		if tCenter.nX + tHalf.nWidth > tDisplay.nWidth / 2 or tCenter.nX - tHalf.nWidth < tDisplay.nWidth / -2 then
			tCenter.nX = 0
		end
	end

	tAnchors = {
		nLeft   = tCenter.nX - tHalf.nWidth,
		nTop    = tCenter.nY - tHalf.nHeight,
		nRight  = tCenter.nX + tHalf.nWidth,
		nBottom = tCenter.nY + tHalf.nHeight
	}

	wndBar:SetAnchorOffsets( tAnchors.nLeft, tAnchors.nTop, tAnchors.nRight, tAnchors.nBottom )
end

function BenikUI_ShortcutBar:ShowBarDocked(nBar, bIsVisible, nShortcuts)
	-- set the position of this action bar ignoring overlapping
	self:SetBarPosition( self.tActionBars[nBar], { nWidth = (nShortcuts * 48) + 136 } )

	local tPosition = self:GetBarPosition(self.tActionBars[nBar])

	-- collect all overlapping bars
	local arRow = { nBar }
	local nRowWidth = tPosition.tSize.nWidth
	local nRowX = tPosition.tCenter.nX
	for nOtherBar,tActionBar in pairs(self.tActionBars) do
		if nOtherBar ~= nBar and tActionBar:IsShown() then
			local tOtherPosition = self:GetBarPosition(nOtherBar)

			if tOtherPosition and tOtherPosition.tCenter and tOtherPosition.tCenter.nY == tPosition.tCenter.nY then
				nRowWidth = nRowWidth + tOtherPosition.tSize.nWidth
				nRowX = (nRowX * #arRow + tOtherPosition.tCenter.nX) / (#arRow + 1)
				arRow[#arRow + 1] = self.tActionBars[nOtherBar]
			end
		end
	end

	-- if there were any overlapping then rearrange all of them
	if #arRow > 1 then
		local kOverlap = 4

		local nLeft = nRowX - nRowWidth / 2
		local tDisplay = Apollo.GetDisplaySize()
		if tDisplay and tDisplay.nWidth then
			if nLeft + nRowWidth > tDisplay.nWidth / 2 then
				nLeft = nRowWidth / -2
			end
		end
		nLeft = nLeft + kOverlap * #arRow

		for nIdx, nTmpBar in pairs(arRow) do
			local tTmpPosition = self:GetBarPosition(nTmpBar)
			self:SetBarPosition(nTmpBar, nil, { nX = nLeft + tTmpPosition.tSize.nWidth / 2 } )
			nLeft = nLeft + tTmpPosition.tSize.nWidth - kOverlap
		end
	end
end

function BenikUI_ShortcutBar:ShowBarFloatHorz(nBar, bIsVisible, nShortcuts)
	-- set the position of this action bar ignoring overlapping
	self:SetBarPosition( self.tActionBarsHorz[nBar], { nWidth = (nShortcuts * 48) + 136 } )

	local tPosition = self:GetBarPosition(self.tActionBarsHorz[nBar])

	-- collect all overlapping bars
	local arRow = { nBar }
	local nRowWidth = tPosition.tSize.nWidth
	local nRowX = tPosition.tCenter.nX
	for nOtherBar,tActionBar in pairs(self.tActionBarsHorz) do
		if nOtherBar ~= nBar and tActionBar:IsShown() then
			local tOtherPosition = self:GetBarPosition(nOtherBar)

			if tOtherPosition and tOtherPosition.tCenter and tOtherPosition.tCenter.nY == tPosition.tCenter.nY then
				nRowWidth = nRowWidth + tOtherPosition.tSize.nWidth
				nRowX = (nRowX * #arRow + tOtherPosition.tCenter.nX) / (#arRow + 1)
				arRow[#arRow + 1] = self.tActionBarsHorz[nOtherBar]
			end
		end
	end

	-- if there were any overlapping then rearrange all of them
	if #arRow > 1 then
		local kOverlap = 4

		local nLeft = nRowX - nRowWidth / 2
		local tDisplay = Apollo.GetDisplaySize()
		if tDisplay and tDisplay.nWidth then
			if nLeft + nRowWidth > tDisplay.nWidth / 2 then
				nLeft = nRowWidth / -2
			end
		end
		nLeft = nLeft + kOverlap * #arRow

		for nIdx, nTmpBar in pairs(arRow) do
			local tTmpPosition = self:GetBarPosition(nTmpBar)
			self:SetBarPosition(nTmpBar, nil, { nX = nLeft + tTmpPosition.tSize.nWidth / 2 } )
			nLeft = nLeft + tTmpPosition.tSize.nWidth - kOverlap
		end
	end
end

function BenikUI_ShortcutBar:ShowBarFloatVert(nBar, bIsVisible, nShortcuts)
	-- set the position of this action bar ignoring overlapping
	self:SetBarPosition( self.tActionBarsVert[nBar], { nHeight = (nShortcuts * 60) + 116 } )

	local tPosition = self:GetBarPosition(self.tActionBarsVert[nBar])

	-- collect all overlapping bars
	local arRow = { nBar }
	local nRowHeight = tPosition.tSize.nHeight
	local nRowY = tPosition.tCenter.nY
	for nOtherBar,tActionBar in pairs(self.tActionBarsVert) do
		if nOtherBar ~= nBar and tActionBar:IsShown() then
			local tOtherPosition = self:GetBarPosition(nOtherBar)

			if tOtherPosition and tOtherPosition.tCenter and tOtherPosition.tCenter.nX == tPosition.tCenter.nX then
				nRowHeight = nRowHeight + tOtherPosition.tSize.nHeight
				nRowY = (nRowY * #arRow + tOtherPosition.tCenter.nY) / (#arRow + 1)
				arRow[#arRow + 1] = self.tActionBarsVert[nOtherBar]
			end
		end
	end

	-- if there were any overlapping then rearrange all of them
	if #arRow > 1 then
		local kOverlap = 4

		local nTop = nRowY - nRowHeight / 2
		local tDisplay = Apollo.GetDisplaySize()
		if tDisplay and tDisplay.nWidth then
			if nTop + nRowHeight > tDisplay.nWidth / 2 then
				nTop = nRowHeight / -2
			end
		end
		nTop = nTop + kOverlap * #arRow

		for nIdx, nTmpBar in pairs(arRow) do
			local tTmpPosition = self:GetBarPosition(nTmpBar)
			self:SetBarPosition(nTmpBar, nil, { nY = nTop + tTmpPosition.tSize.nHeight / 2 } )
			nTop = nTop + tTmpPosition.tSize.nHeight - kOverlap
		end
	end
end

function BenikUI_ShortcutBar:ShowWindow(nBar, bIsVisible, nShortcuts)
    if self.tActionBarsHorz[nBar] == nil then
		return
	end

	self.tActionBarSettings[nBar] = {}
	self.tActionBarSettings[nBar].bIsVisible = bIsVisible
	self.tActionBarSettings[nBar].nShortcuts = nShortcuts

	if nShortcuts and bIsVisible then
		--self:ShowBarDocked(nBar, bIsVisible, nShortcuts)
		self:ShowBarFloatHorz(nBar, bIsVisible, nShortcuts)
		self:ShowBarFloatVert(nBar, bIsVisible, nShortcuts)
	end

	if not self.bTimerRunning then
		self.timerShorcutArt:Start()
		self.bTimerRunning = true
	end

	self.tActionBars[nBar]:Show(bIsVisible and self.bDocked, not bIsVisible)
	self.tActionBarsHorz[nBar]:Show(bIsVisible and not self.bDocked and self.bHorz, not bIsVisible)
	self.tActionBarsVert[nBar]:Show(bIsVisible and not self.bDocked and not self.bHorz, not bIsVisible)
end

function BenikUI_ShortcutBar:OnActionBarShortcutArtTimer()
	self.bTimerRunning = false
	local bBarVisible = false

	for nbar, tSettings in pairs(self.tActionBarSettings) do
		bBarVisible = bBarVisible or (tSettings.bIsVisible and self.bDocked)
	end

	Event_FireGenericEvent("ShowActionBarShortcutDocked", bBarVisible)
	for idx = knStartingBar, knMaxBars do
		self.tActionBars[idx]:ToFront()
	end
end

function BenikUI_ShortcutBar:OnDockBtn(wndControl, wndHandler)
	self.bDocked = not self.bDocked
	self.bHorz = true

	for nbar, tActionBar in pairs(self.tActionBars) do
		tActionBar:Show(self.tActionBarSettings[nbar].bIsVisible and self.bDocked)
		tActionBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		tActionBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
	end

	for nbar, tActionBar in pairs(self.tActionBarsHorz) do
		tActionBar:Show(self.tActionBarSettings[nbar].bIsVisible and not self.bDocked and self.bHorz)
		tActionBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		tActionBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
	end

	for nbar, tActionBar in pairs(self.tActionBarsVert) do
		tActionBar:Show(self.tActionBarSettings[nbar].bIsVisible and not self.bDocked and not self.bHorz)
		tActionBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		tActionBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
	end

	Event_FireGenericEvent("ShowActionBarShortcutDocked", self.bDocked)
end

function BenikUI_ShortcutBar:OnOrientationBtn(wndControl, wndHandler)
	self.bDocked = false
	self.bHorz = not self.bHorz

	for nbar, tActionBar in pairs(self.tActionBars) do
		tActionBar:Show(self.tActionBarSettings[nbar].bIsVisible and self.bDocked)
		tActionBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		tActionBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
	end

	for nbar, tActionBar in pairs(self.tActionBarsHorz) do
		tActionBar:Show(self.tActionBarSettings[nbar].bIsVisible and not self.bDocked and self.bHorz)
		tActionBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		tActionBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
	end

	for nbar, tActionBar in pairs(self.tActionBarsVert) do
		tActionBar:Show(self.tActionBarSettings[nbar].bIsVisible and not self.bDocked and not self.bHorz)
		tActionBar:FindChild("DockBtn"):SetCheck(not self.bDocked)
		tActionBar:FindChild("OrientationBtn"):SetCheck(not self.bHorz)
	end

	Event_FireGenericEvent("ShowActionBarShortcutDocked", self.bDocked)
end

function BenikUI_ShortcutBar:OnGenerateTooltip(wndControl, wndHandler, eType, oArg1, oArg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemInstance then
		local itemEquipped = oArg1:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, oArg1, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		--Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = oArg1}) -- OLD
	elseif eType == Tooltip.TooltipGenerateType_ItemData then
		local itemEquipped = oArg1:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, oArg1, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		--Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = oArg1}) - OLD
	elseif eType == Tooltip.TooltipGenerateType_GameCommand then
		xml = XmlDoc.new()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Macro then
		xml = XmlDoc.new()
		xml:AddLine(oArg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, oArg1)
	elseif eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	end
end

function BenikUI_ShortcutBar:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	local tAnchors =
	{
		[GameLib.CodeEnumTutorialAnchor.FloatingActionBar]				= true,
		[GameLib.CodeEnumTutorialAnchor.FloatingActionBarSecondButton]	= true,
		[GameLib.CodeEnumTutorialAnchor.FloatingActionBarFifthButton]	= true,
	}

	if not tAnchors[eAnchor] or not self.tActionBarSettings[ActionSetLib.CodeEnumShortcutSet.FloatingSpellBar].bIsVisible then
		return
	end
	local tAnchorToButton =
	{
		[GameLib.CodeEnumTutorialAnchor.FloatingActionBar]				= 1,
		[GameLib.CodeEnumTutorialAnchor.FloatingActionBarSecondButton]	= 2,
		[GameLib.CodeEnumTutorialAnchor.FloatingActionBarFifthButton]	= 5,
	}
	local nButton = tAnchorToButton[eAnchor]

	local wndActionBar = nil
	local eOrientationOverride = nil
	if self.bDocked then
		eOrientationOverride = GameLib.CodeEnumTutorialAnchorOrientation.South
		for nBar, wndBar in pairs(self.tActionBars) do
			if wndBar:IsVisible() then
				wndActionBar = wndBar
				break
			end
		end
	elseif self.bHorz then
		eOrientationOverride = GameLib.CodeEnumTutorialAnchorOrientation.North
		for nBar, wndBar in pairs(self.tActionBarsHorz) do
			if wndBar:IsVisible() then
				wndActionBar = wndBar
				break
			end
		end
	else
		eOrientationOverride = GameLib.CodeEnumTutorialAnchorOrientation.Northwest
		for nBar, wndBar in pairs(self.tActionBarsVert) do
			if wndBar:IsVisible() then
				wndActionBar = wndBar
				break
			end
		end
	end

	if wndActionBar then
		local wndChild = wndActionBar:FindChild("ActionBarContainer"):GetChildren()[nButton]
		if wndChild then
			Event_FireGenericEvent("Tutorial_ShowCallout", eAnchor, idTutorial, strPopupText, wndChild, eOrientationOverride)
		end
	end
end

-----------------------------------------------------------
local ActionBarShortcut_Singleton = BenikUI_ShortcutBar:new()
ActionBarShortcut_Singleton:Init()