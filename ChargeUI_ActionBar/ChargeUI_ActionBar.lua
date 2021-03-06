-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChargeUI_ActionBar
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "GameLib"
require "CollectiblesLib"
require "Spell"
require "Unit"
require "Item"
require "AbilityBook"
require "ActionSetLib"
require "Tooltip"

local ChargeUI_ActionBar = {}

function ChargeUI_ActionBar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ChargeUI_ActionBar:Init()
    Apollo.RegisterAddon(self)
end

function ChargeUI_ActionBar:OnLoad()
	self.nSelectedMount = nil
	self.nSelectedPotion = nil

	self.xmlDoc = XmlDoc.CreateFromFile("ChargeUI_ActionBar.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ChargeUI_ActionBar:OnDocumentReady()
	Apollo.RegisterEventHandler("UnitEnteredCombat", 						"OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("PlayerChanged", 							"InitializeBars", self)
	Apollo.RegisterEventHandler("ResolutionChanged",						"InitializeBars", self)
	Apollo.RegisterEventHandler("ApplicationWindowSizeChanged", 			"InitializeBars", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDPreferences", 			"InitializeBars", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 						"InitializeBars", self)

	Apollo.RegisterEventHandler("CharacterCreated", 						"OnCharacterCreated", self)

	Apollo.RegisterEventHandler("AbilityBookChange",						"RedrawMounts", self)
	Apollo.RegisterEventHandler("StanceChanged", 							"RedrawStances", self)

	Apollo.RegisterEventHandler("ShowActionBarShortcut", 					"OnShowActionBarShortcut", self)
	Apollo.RegisterEventHandler("ShowActionBarShortcutDocked", 				"OnShowActionBarShortcutDocked", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 				"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterEventHandler("Options_UpdateActionBarTooltipLocation", 	"OnUpdateActionBarTooltipLocation", self)
	Apollo.RegisterEventHandler("ActionBarNonSpellShortcutAddFailed", 		"OnActionBarNonSpellShortcutAddFailed", self)
	Apollo.RegisterEventHandler("UpdateInventory", 							"OnUpdateInventory", self)

	self.wndShadow = Apollo.LoadForm(self.xmlDoc, "Shadow", "FixedHudStratum", self)
	self.wndArt = Apollo.LoadForm(self.xmlDoc, "Art", "FixedHudStratum", self)
	self.wndBar2 = Apollo.LoadForm(self.xmlDoc, "Bar2ButtonContainer", "FixedHudStratum", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ActionBarFrameForm", "FixedHudStratumHigh", self)
	self.wndBar1 = self.wndMain:FindChild("Bar1ButtonContainer")
	self.wndBar3 = self.wndMain:FindChild("Bar3ButtonContainer")

	self.wndStancePopoutFrame = self.wndMain:FindChild("StancePopoutFrame")

	self.wndPotionFlyout = self.wndMain:FindChild("PotionFlyout")
	self.wndPotionPopoutFrame = self.wndPotionFlyout:FindChild("PotionPopoutFrame")

	g_wndActionBarResources	= Apollo.LoadForm(self.xmlDoc, "Resources", "FixedHudStratum", self) -- Do not rename. This is global and used by other forms as a parent.

	Event_FireGenericEvent("ActionBarLoaded")

	self.wndMountFlyoutFrame = self.wndMain:FindChild("MountPopoutFrame")

	self.wndArt:Show(false)
	self.wndMain:Show(false)
	self.wndPotionFlyout:Show(false)
	
	self:SetWindows()
	
	self.tAnchorMapping =
	{
		[GameLib.CodeEnumTutorialAnchor.InnateAbility] 	= self.wndMain:FindChild("StancePopoutBtn"),
	}

	if GameLib.GetPlayerUnit() ~= nil then
		self:OnCharacterCreated()
	end
end

function ChargeUI_ActionBar:StartCustomise()
	self.wndMain:FindChild("MouseCatcher"):Show(true)
	self.wndMain:SetStyle("IgnoreMouse",false)
	self.wndMain:SetStyle("Moveable",true)
	self.wndMain:SetStyle("Sizable",true)
	self.wndBar2:FindChild("MouseCatcher"):Show(true)
	self.wndBar2:SetStyle("IgnoreMouse",false)
	self.wndBar2:SetStyle("Moveable",true)
	self.wndBar2:SetStyle("Sizable",true)
end

function ChargeUI_ActionBar:EndCustomise()
	self.wndMain:FindChild("MouseCatcher"):Show(false)
	self.wndMain:SetStyle("IgnoreMouse",true)
	self.wndMain:SetStyle("Moveable",false)
	self.wndMain:SetStyle("Sizable",false)
	self.wndBar2:FindChild("MouseCatcher"):Show(false)
	self.wndBar2:SetStyle("IgnoreMouse",true)
	self.wndBar2:SetStyle("Moveable",false)
	self.wndBar2:SetStyle("Sizable",false)
end

function ChargeUI_ActionBar:SaveWindows()
	local l,t,r,b = self.wndMain:GetAnchorOffsets()
	self.OffsetsMain = {l,t,r,b}

	l,t,r,b = self.wndBar2:GetAnchorOffsets()
	self.OffsetsBar2 = {l,t,r,b}
	self:ArrangeGridWithGab(self.wndBar2:FindChild("Grid"),5)
end

function ChargeUI_ActionBar:OnMouseCatcherClick( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	local Addon = Apollo.GetAddon("ChargeUI")
	if Addon ~= nil then
		Addon:OnWindowClick(wndHandler:GetParent())
	end
end

function ChargeUI_ActionBar:SetWindows()
	local l,t,r,b

	if self.OffsetsMain ~= nil then
		l,t,r,b = unpack(self.OffsetsMain)
		self.wndMain:SetAnchorOffsets(l,t,r,b)
	end

	if self.OffsetsBar2 ~= nil then
		l,t,r,b = unpack(self.OffsetsBar2)
		self.wndBar2:SetAnchorOffsets(l,t,r,b)
	end
end

function ChargeUI_ActionBar:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSavedData =
	{
		nSelectedMount = self.nSelectedMount,
		nSelectedPotion = self.nSelectedPotion,
		tVehicleBar = self.tCurrentVehicleInfo,
		OffsetsMain = self.OffsetsMain,
		OffsetsBar2 = self.OffsetsBar2,
	}

	return tSavedData
end

function ChargeUI_ActionBar:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	if tSavedData.nSelectedMount then
		self.nSelectedMount = tSavedData.nSelectedMount
	end

	if tSavedData.nSelectedPotion then
		self.nSelectedPotion = tSavedData.nSelectedPotion
	end

	if tSavedData.tVehicleBar then
		self.tCurrentVehicleInfo = tSavedData.tVehicleBar
	end

	if tSavedData.OffsetsMain then
		self.OffsetsMain = tSavedData.OffsetsMain
	end

	if tSavedData.OffsetsBar2 then
		self.OffsetsBar2 = tSavedData.OffsetsBar2
	end
end

function ChargeUI_ActionBar:OnPlayerEquippedItemChanged()
	local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")
	if (nVisibility == nil or nVisibility < 1) and self:IsWeaponEquipped() then
		Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "skillsBarDisplay")
	end
end

function ChargeUI_ActionBar:IsWeaponEquipped()
	local unitPlayer = GameLib.GetPlayerUnit()

	local tEquipment = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetEquippedItems() or {}
	for idx, tItemData in pairs(tEquipment) do
		if tItemData:GetSlot() == 16 then
			return true
		end
	end

	return false
end

function ChargeUI_ActionBar:OnUnitEnteredCombat(unit)
	if unit ~= GameLib.GetPlayerUnit() then
		return
	end

	self:RedrawBarVisibility()
end

function ChargeUI_ActionBar:InitializeBars()
	self:RedrawStances()
	self:RedrawMounts()
	self:RedrawPotions()

	local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")

	if nVisibility == nil or nVisibility < 1 then
		local bHasWeaponEquipped = self:IsWeaponEquipped()

		if bHasWeaponEquipped then
			-- This isn't a new character, set the preference to always display.
			Apollo.SetConsoleVariable("hud.skillsBarDisplay", 1)
		else
			-- Wait for the player to equip their first item
			Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 	"OnPlayerEquippedItemChanged", self)
		end
	end

	self.wndArt:Show(true)
	self.wndMain:Show(true)
	self.wndBar1:DestroyChildren()
	self.wndBar2:FindChild("Grid"):DestroyChildren()
	self.wndBar3:DestroyChildren()

	-- All the buttons
	self.arBarButtons = {}
	self.arBarButtons[0] = self.wndMain:FindChild("ActionBarInnate")
	--Hotkeys
	self.wndMain:FindChild("StanceFlyout:StanceCover:EditBox"):SetText(GameLib.GetKeyBinding("CastInnateAbility"))
	if GameLib.GetKeyBinding("Mount") == "Unbound" then
		self.wndMain:FindChild("Mount:EditBox"):SetText("--")
	else
		self.wndMain:FindChild("Mount:EditBox"):SetText(GameLib.GetKeyBinding("Mount"))
	end

	for idx = 1, 28 do--34 max (reduced to 28 for benik ui)
		local wndCurr = nil
		local wndActionBarBtn = nil

		if idx < 9 then
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemBig", self.wndBar1, self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx - 1)
			wndCurr:FindChild("EditBox"):SetText(GameLib.GetKeyBinding("LimitedActionSet"..tostring(idx)))

			if idx == 1 then
				self.tAnchorMapping[GameLib.CodeEnumTutorialAnchor.AbilityBarSlotOne] = wndCurr
			elseif idx == 3 then
				self.tAnchorMapping[GameLib.CodeEnumTutorialAnchor.AbilityBarSlotThree] = wndCurr
			end

			if ActionSetLib.IsSlotUnlocked(idx - 1) ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
				wndCurr:FindChild("LockSprite"):Show(true)
				wndCurr:FindChild("Cover"):Show(false)
			else
				wndCurr:FindChild("LockSprite"):Show(false)
				wndCurr:FindChild("Cover"):Show(true)
			end
		elseif idx < 10 then -- Gadget
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemMed", self.wndMain:FindChild("Bar1ButtonSmallContainer:Buttons:Window"), self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx - 1)
			wndCurr:FindChild("EditBox"):SetText(GameLib.GetKeyBinding("CastGadgetAbility"))


			wndCurr:FindChild("LockSprite"):Show(false)
			wndCurr:FindChild("Cover"):Show(false)

			if ActionSetLib.IsSlotUnlocked(idx - 1) ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
				wndCurr:SetTooltip(Apollo.GetString("ActionBarFrame_LockedGadgetSlot"))
			else
				wndCurr:SetTooltip("")
			end
		elseif idx < 11 then -- Path
			--Deprecated

			if GameLib.GetKeyBinding("CastPathAbility") == "Unbound" then
				self.wndMain:FindChild("PathButton:EditBox"):SetText("--")
			else
				self.wndMain:FindChild("PathButton:EditBox"):SetText(GameLib.GetKeyBinding("CastPathAbility"))
			end
		elseif idx < 23 then -- 11 to 22
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemSmall", self.wndBar2:FindChild("Grid"), self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx + 1)

			--hide bars we can't draw due to screen size
			--if (idx - 10) * wndCurr:GetWidth() > self.wndBar2:GetWidth() and self.wndBar2:GetWidth() > 0 then
			--	wndCurr:Show(false)
			--end
		else -- 23 to 34
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemSmall", self.wndBar3, self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx + 1)

			--hide bars we can't draw due to screen size
			--if (idx - 22) * wndCurr:GetWidth() > self.wndBar3:GetWidth() and self.wndBar3:GetWidth() > 0 then
			--	wndCurr:Show(false)
			--end
		end

		self.arBarButtons[idx] = wndActionBarBtn
	end

	self:ArrangeWithGab(self.wndBar1,5)
	self.wndMain:FindChild("Bar1ButtonSmallContainer:Buttons"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	self:ArrangeGridWithGab(self.wndBar2:FindChild("Grid"),5)--Window.CodeEnumArrangeOrigin.LeftOrTop
	self.wndBar2:FindChild("Grid"):Reposition()
	self:ArrangeWithGab(self.wndBar3,5)
	self:OnUpdateActionBarTooltipLocation()

	self:RedrawBarVisibility()
end

function ChargeUI_ActionBar:ArrangeWithGab(wnd,gab)
	local last = 0
	local children = wnd:GetChildren()
	local l,t,r,b = wnd:GetAnchorOffsets()
	local wndHeight = math.abs(b-t)
	l,t,r,b = children[1]:GetAnchorOffsets()
	wndHeight = wndHeight - math.abs(r-l)
	for i,j in pairs(children) do
		local l,t,r,b = j:GetAnchorOffsets()
		local width = math.abs(r-l)
		j:SetAnchorOffsets(last,wndHeight,last+width,wndHeight+b)
		last = last +width +gab;
	end
end

function ChargeUI_ActionBar:ArrangeGridWithGab(wnd,gab)
	local last = 0
	local height = 0
	local children = wnd:GetChildren()
	local l,t,r,b = wnd:GetParent():GetAnchorOffsets()
	local l2,t2,r2,b2 = wnd:GetAnchorOffsets()
	b = b+b2
	t = t+t2
	r = r+r2
	l = l+l2
	local wndHeight = b-t
	local wndWidth = r-l
	for i,j in pairs(children) do
		local l,t,r,b = j:GetAnchorOffsets()
		local width = r-l
		if last+width > wndWidth then
			last = 0
			height = height + b-t+gab
		end
		j:SetAnchorOffsets(last,height,last+width,height+b-t)
		last = last +width +gab
	end
end

function ChargeUI_ActionBar:RedrawBarVisibility()
	local unitPlayer = GameLib.GetPlayerUnit()

	--Toggle Visibility based on ui preference
	local nSkillsVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")
	local nResourceVisibility = Apollo.GetConsoleVariable("hud.resourceBarDisplay")
	local nLeftVisibility = Apollo.GetConsoleVariable("hud.secondaryLeftBarDisplay")
	local nRightVisibility = Apollo.GetConsoleVariable("hud.secondaryRightBarDisplay")
	local nMountVisibility = Apollo.GetConsoleVariable("hud.mountButtonDisplay")

	if nSkillsVisibility == 1 then --always on
		self.wndMain:Show(true)
	elseif nSkillsVisibility == 2 then --always off
		self.wndMain:Show(false)
	elseif nSkillsVisibility == 3 then --on in combat
		self.wndMain:Show(unitPlayer and unitPlayer:IsInCombat())
	elseif nSkillsVisibility == 4 then --on out of combat
		self.wndMain:Show(unitPlayer and not unitPlayer:IsInCombat())
	else
		self.wndMain:Show(false)
	end

	if nResourceVisibility == 1 then --always on
		g_wndActionBarResources:Show(true)
	elseif nResourceVisibility == 2 then --always off
		g_wndActionBarResources:Show(false)
	elseif nResourceVisibility == 3 then --on in combat
		g_wndActionBarResources:Show(unitPlayer and unitPlayer:IsInCombat())
	elseif nResourceVisibility == 4 then --on out of combat
		g_wndActionBarResources:Show(unitPlayer and not unitPlayer:IsInCombat())
	else
		g_wndActionBarResources:Show(self.wndMain:IsShown())
	end

	if nLeftVisibility == 1 then --always on
		self.wndBar2:Show(true)--self.wndBar2:Show(true)
	elseif nLeftVisibility == 2 then --always off
		self.wndBar2:Show(false)
	elseif nLeftVisibility == 3 then --on in combat
		self.wndBar2:Show(unitPlayer and unitPlayer:IsInCombat())
	elseif nLeftVisibility == 4 then --on out of combat
		self.wndBar2:Show(unitPlayer and not unitPlayer:IsInCombat())
	else
		--NEW Player Experience: Set the bottom left/right bars to Always Show once you've reached level 3
		if unitPlayer and (unitPlayer:GetLevel() or 1) > 2 then
			--Trigger a HUD Tutorial
			Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "secondaryLeftBarDisplay")
		end

		self.wndBar2:Show(false)
	end

	if nRightVisibility == 1 then --always on
		self.wndBar3:Show(true)
	elseif nRightVisibility == 2 then --always off
		self.wndBar3:Show(false)
	elseif nRightVisibility == 3 then --on in combat
		self.wndBar3:Show(unitPlayer and unitPlayer:IsInCombat())
	elseif nRightVisibility == 4 then --on out of combat
		self.wndBar3:Show(unitPlayer and not unitPlayer:IsInCombat())
	else
		--NEW Player Experience: Set the bottom left/right bars to Always Show once you've reached level 3
		if unitPlayer and (unitPlayer:GetLevel() or 1) > 2 then
			--Trigger a HUD Tutorial
			Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "secondaryRightBarDisplay")
		end

		self.wndBar3:Show(false)
	end


	local bActionBarShown = self.wndMain:IsShown()
	local bFloatingActionBarShown = self.wndArt:FindChild("BarFrameShortcut"):IsShown()

	self.wndShadow:SetOpacity(0.5)
	self.wndShadow:Show(true)
	self.wndArt:Show(bActionBarShown)
	self.wndPotionFlyout:Show(true)--self.wndPotionFlyout:IsShown() and unitPlayer and not unitPlayer:IsInVehicle()

	--local nLeft, nTop, nRight, nBottom = g_wndActionBarResources:GetAnchorOffsets()

	if bActionBarShown then
		--local nOffset = bFloatingActionBarShown and -173 or -103

		--g_wndActionBarResources:SetAnchorOffsets(nLeft, nTop, nRight, nOffset)
	else
		--g_wndActionBarResources:SetAnchorOffsets(nLeft, nTop, nRight, -19)
	end
end

-----------------------------------------------------------------------------------------------
-- Main Redraw
-----------------------------------------------------------------------------------------------
function ChargeUI_ActionBar:RedrawStances()
	local wndStancePopout = self.wndStancePopoutFrame:FindChild("StancePopoutList")
	wndStancePopout:DestroyChildren()

	local nCountSkippingTwo = 0
	for idx, spellObject in pairs(GameLib.GetClassInnateAbilitySpells().tSpells) do
		if idx % 2 == 1 then
			nCountSkippingTwo = nCountSkippingTwo + 1
			local strKeyBinding = GameLib.GetKeyBinding("SetStance"..nCountSkippingTwo) -- hardcoded formatting
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "StanceBtn", wndStancePopout, self)
			wndCurr:FindChild("StanceBtnIcon"):SetSprite(spellObject:GetIcon())
			wndCurr:SetData(nCountSkippingTwo)

			if Tooltip and Tooltip.GetSpellTooltipForm then
				wndCurr:SetTooltipDoc(nil)
				Tooltip.GetSpellTooltipForm(self, wndCurr, spellObject)
			end
		end
	end

	local nHeight = wndStancePopout:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	local nLeft, nTop, nRight, nBottom = self.wndStancePopoutFrame:GetAnchorOffsets()
	self.wndStancePopoutFrame:SetAnchorOffsets(nLeft, nBottom - nHeight, nRight, nBottom)
end

function ChargeUI_ActionBar:OnStanceBtn(wndHandler, wndControl)
	self.wndMain:FindChild("StancePopoutFrame"):Show(false)
	GameLib.SetCurrentClassInnateAbilityIndex(wndHandler:GetData())
end

function ChargeUI_ActionBar:RedrawSelectedMounts()
	GameLib.SetShortcutMount(self.nSelectedMount)
end

function ChargeUI_ActionBar:RedrawMounts()
	local wndMountPopout = self.wndMountFlyoutFrame:FindChild("MountPopoutList")
	wndMountPopout:DestroyChildren()

	local tMountList = CollectiblesLib.GetMountList()
	local splSelected = nil

	for idx, tMountData  in pairs(tMountList) do
		if tMountData.bIsKnown then
			local splMount = tMountData.splObject

			if not splSelected then
				splSelected = splMount
			end

			if splMount:GetId() == self.nSelectedMount then
				splSelected = splMount
			end

			local wndCurr = Apollo.LoadForm(self.xmlDoc, "MountBtn", wndMountPopout, self)
			wndCurr:FindChild("MountBtnIcon"):SetSprite(splMount:GetIcon())
			wndCurr:SetData(splMount)

			if Tooltip and Tooltip.GetSpellTooltipForm then
				wndCurr:SetTooltipDoc(nil)
				Tooltip.GetSpellTooltipForm(self, wndCurr, splMount, {})
			end
		end
	end

	if splSelected then
		GameLib.SetShortcutMount(splSelected:GetId())
	end

	local nCount = #wndMountPopout:GetChildren()
	if nCount > 0 then
		local nMax = 7
		local nMaxHeight = (wndMountPopout:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop) / nCount) * nMax
		local nHeight = wndMountPopout:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)

		nHeight = nHeight <= nMaxHeight and nHeight or nMaxHeight

		local nLeft, nTop, nRight, nBottom = self.wndMountFlyoutFrame:GetAnchorOffsets()

		self.wndMountFlyoutFrame:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
		self:RedrawBarVisibility()
	end
end

function ChargeUI_ActionBar:OnMountBtn(wndHandler, wndControl)
	self.nSelectedMount = wndControl:GetData():GetId()

	self.wndMountFlyoutFrame:Show(false)
	self:RedrawSelectedMounts()
end

function ChargeUI_ActionBar:RedrawPotions()
	local unitPlayer = GameLib.GetPlayerUnit()

	local wndPotionPopout = self.wndPotionPopoutFrame:FindChild("PotionPopoutList")
	wndPotionPopout:DestroyChildren()

	local tItemList = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetInventoryItems() or {}
	local tSelectedPotion = nil;
	local tFirstPotion = nil
	local tPotions = { }

	for idx, tItemData in pairs(tItemList) do
		if tItemData and tItemData.itemInBag and tItemData.itemInBag:GetItemCategory() == 48 then--and tItemData.itemInBag:GetConsumable() == "Consumable" then
			local itemPotion = tItemData.itemInBag

			if tFirstPotion == nil then
				tFirstPotion = itemPotion
			end

			if itemPotion:GetItemId() == self.nSelectedPotion then
				tSelectedPotion = itemPotion
			end

			local idItem = itemPotion:GetItemId()

			if tPotions[idItem] == nil then
				tPotions[idItem] =
				{
					itemObject = itemPotion,
					nCount = itemPotion:GetStackCount(),
				}
			else
				tPotions[idItem].nCount = tPotions[idItem].nCount + itemPotion:GetStackCount()
			end
		end
	end

	for idx, tData  in pairs(tPotions) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "PotionBtn", wndPotionPopout, self)
		wndCurr:FindChild("PotionBtnIcon"):SetSprite(tData.itemObject:GetIcon())
		if (tData.nCount > 1) then wndCurr:FindChild("PotionBtnStackCount"):SetText(tData.nCount) end
		wndCurr:SetData(tData.itemObject)

		wndCurr:SetTooltipDoc(nil)
		Tooltip.GetItemTooltipForm(self, wndCurr, tData.itemObject, {})
	end

	if tSelectedPotion == nil and tFirstPotion ~= nil then
		tSelectedPotion = tFirstPotion
	end

	if tSelectedPotion ~= nil then
		GameLib.SetShortcutPotion(tSelectedPotion:GetItemId())
	end

	local nCount = #wndPotionPopout:GetChildren()
	if nCount > 0 then
		local nMax = 7
		local nMaxHeight = (wndPotionPopout:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop) / nCount) * nMax
		local nHeight = wndPotionPopout:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)

		nHeight = nHeight <= nMaxHeight and nHeight or nMaxHeight

		local nLeft, nTop, nRight, nBottom = self.wndPotionPopoutFrame:GetAnchorOffsets()

		self.wndPotionPopoutFrame:SetAnchorOffsets(nLeft, nBottom - nHeight - 74, nRight, nBottom)
	end

	self.wndPotionFlyout:Show(nCount > 0)
end

function ChargeUI_ActionBar:OnPotionBtn(wndHandler, wndControl)
	self.nSelectedPotion = wndControl:GetData():GetItemId()

	self.wndPotionPopoutFrame:Show(false)
	self:RedrawPotions()
end

function ChargeUI_ActionBar:OnShowActionBarShortcut(eWhichBar, bIsVisible, nNumShortcuts)
	if eWhichBar == ActionSetLib.CodeEnumShortcutSet.VehicleBar and self.wndMain and self.wndMain:IsValid() then
		if self.arBarButtons then
			for idx, wndBtn in pairs(self.arBarButtons) do
				wndBtn:Enable(not bIsVisible) -- Turn on or off all buttons
			end
		end
		self:ShowVehicleBar(eWhichBar, bIsVisible, nNumShortcuts) -- show/hide vehicle bar if eWhichBar matches
	end
end

function ChargeUI_ActionBar:OnShowActionBarShortcutDocked(bVisible)
	self.wndArt:FindChild("BarFrameShortcut"):Show(bVisible, not bVisible)
	self:RedrawBarVisibility()
end

function ChargeUI_ActionBar:ShowVehicleBar(eWhichBar, bIsVisible, nNumShortcuts)
	if eWhichBar ~= ActionSetLib.CodeEnumShortcutSet.VehicleBar or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndVehicleBar = self.wndMain:FindChild("VehicleBarMain")
	wndVehicleBar:Show(bIsVisible)
	self.wndMain:FindChild("VehicleBarMain:VehicleBarFrame"):Show(bIsVisible)
	self.wndMain:FindChild("StanceFlyout"):Show(not bIsVisible)
	self.wndMain:FindChild("Bar1ButtonSmallContainer"):Show(not bIsVisible)

	self.wndBar1:Show(not bIsVisible)
	local unitPlayer = GameLib:GetPlayerUnit()
	if unitPlayer and not unitPlayer:IsInVehicle() then
		self.tCurrentVehicleInfo = nil
	end

	if bIsVisible then
		for idx = 1, 6 do -- TODO hardcoded formatting
			wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):Show(false)
		end

		if nNumShortcuts then
			for idx = 1, nNumShortcuts do
				wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):Show(true)
				wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):FindChild("ActionBarShortcut." .. idx):Enable(true)
				wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):FindChild("EditBox"):SetText(GameLib.GetKeyBinding("LimitedActionSet"..tostring(idx)))
			end

			--local nLeft, nTop ,nRight, nBottom = wndVehicleBar:FindChild("VehicleBarFrame"):GetParent():GetAnchorOffsets() -- TODO SUPER HARDCODED FORMATTING
			--wndVehicleBar:FindChild("VehicleBarFrame"):SetAnchorOffsets(nLeft, nTop, nLeft + (58 * nNumShortcuts) + 66, nBottom)
		end

		--wndVehicleBar:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.Middle)

		self.tCurrentVehicleInfo =
		{
			nBar = nWhichBar,
			nNumShortcuts = nNumShortcuts,
		}
	end
end

function ChargeUI_ActionBar:OnUpdateActionBarTooltipLocation()
	for idx = 0, 9 do
		self:HelperSetTooltipType(self.arBarButtons[idx])
	end
	self:HelperSetTooltipType(self.wndMain:FindChild("Mount:ActionBarMount"))
	self:HelperSetTooltipType(self.wndMain:FindChild("PotionFlyout:PotionCover:ActionBarPotion"))
end

function ChargeUI_ActionBar:HelperSetTooltipType(wnd)
	wnd:SetTooltipType(Window.TPT_OnCursor)
end

function ChargeUI_ActionBar:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if self.tAnchorMapping and self.tAnchorMapping[eAnchor] then
		Event_FireGenericEvent("Tutorial_ShowCallout", eAnchor, idTutorial, strPopupText, self.tAnchorMapping[eAnchor])
	end
end

function ChargeUI_ActionBar:OnUpdateInventory()
	local unitPlayer = GameLib.GetPlayerUnit()

	if self.nPotionCount == nil then
		self.nPotionCount = 0
	end

	local nLastPotionCount = self.nPotionCount
	local tItemList = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetInventoryItems() or {}
	local tPotions = { }

	for idx, tItemData in pairs(tItemList) do
		if tItemData and tItemData.itemInBag and tItemData.itemInBag:GetItemCategory() == 48 then--and tItemData.itemInBag:GetConsumable() == "Consumable" then
			local tItem = tItemData.itemInBag

			if tPotions[tItem:GetItemId()] == nil then
				tPotions[tItem:GetItemId()] = {}
				tPotions[tItem:GetItemId()].nCount=tItem:GetStackCount()
			else
				tPotions[tItem:GetItemId()].nCount = tPotions[tItem:GetItemId()].nCount + tItem:GetStackCount()
			end
		end
	end

	self.nPotionCount = 0
	for idx, tItemData in pairs(tPotions) do
		self.nPotionCount = self.nPotionCount + 1
	end

	if self.nPotionCount ~= nLastPotionCount then
		self:RedrawPotions()
	end
end

function ChargeUI_ActionBar:OnGenerateTooltip(wndControl, wndHandler, eType, arg1, arg2)
  local xml = nil
   if eType == Tooltip.TooltipGenerateType_ItemInstance then -- Doesn't need to compare to item equipped
  		Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
   elseif eType == Tooltip.TooltipGenerateType_ItemData then -- Doesn't need to compare to item equipped
   		Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
   elseif eType == Tooltip.TooltipGenerateType_GameCommand then
      xml = XmlDoc.new()
      xml:AddLine(arg2)
      wndControl:SetTooltipDoc(xml)
    elseif eType == Tooltip.TooltipGenerateType_Macro then
      xml = XmlDoc.new()
      xml:AddLine(arg1)
      wndControl:SetTooltipDoc(xml)
    elseif eType == Tooltip.TooltipGenerateType_Spell then
      if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
		Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
      end
    elseif eType == Tooltip.TooltipGenerateType_PetCommand then
      xml = XmlDoc.new()
      xml:AddLine(arg2)
      wndControl:SetTooltipDoc(xml)
    end
end

function ChargeUI_ActionBar:OnActionBarNonSpellShortcutAddFailed()
	--TODO: Print("You can not add that to your Limited Action Set bar.")
end

function ChargeUI_ActionBar:OnCharacterCreated()
	if not GameLib.IsCharacterLoaded() then
			self.timerCharacterCreated = ApolloTimer.Create(0.5, false, "OnCharacterCreated", self)
			return
	end

	if self.timerCharacterCreated then
		self.timerCharacterCreated:Stop()
	end

	local unitPlayer = GameLib.GetPlayerUnit()

	if GameLib.IsCharacterLoaded() and not self.bCharacterLoaded and unitPlayer and unitPlayer:IsValid() then
		self.bCharacterLoaded = true
		Event_FireGenericEvent("ActionBarReady", self.wndMain)
		self:InitializeBars()

		if self.tCurrentVehicleInfo and unitPlayer:IsInVehicle() then
			self:OnShowActionBarShortcut(self.tCurrentVehicleInfo.nBar, true, self.tCurrentVehicleInfo.nNumShortcuts)
		else
			self.tCurrentVehicleInfo = nil
		end
	end
end

function ChargeUI_ActionBar:OnMouseButtonInnate( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if eMouseButton == 1 then
		self.wndStancePopoutFrame:Show(not self.wndStancePopoutFrame:IsShown())
		self.wndStancePopoutFrame:ToFront()
	end
end
function ChargeUI_ActionBar:OnMouseButtonPotion( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	if eMouseButton == 1 then
		self.wndPotionPopoutFrame:Show(not self.wndPotionPopoutFrame:IsShown())
		self.wndPotionPopoutFrame:ToFront()
	end
end

function ChargeUI_ActionBar:OnMountButtonUp( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	if eMouseButton == 1 then
		self.wndMountFlyoutFrame:Show(not self.wndMountFlyoutFrame:IsShown())
		self.wndMountFlyoutFrame:ToFront()
	end
end

function ChargeUI_ActionBar:OpenMountsCustomization()
	Event_FireGenericEvent("GenericEvent_OpenCollectables")
end


function ChargeUI_ActionBar:SwitchAS( wndHandler, wndControl, eMouseButton )
	local LAS = AbilityBook.GetCurrentSpec()
	local name = wndControl:GetName()
	if name == "l" then
		if LAS == 1 then
			AbilityBook.SetCurrentSpec(4)
		else
			AbilityBook.SetCurrentSpec(LAS-1)
		end
	else
		if LAS == 4 then
			AbilityBook.SetCurrentSpec(1)
		else
			AbilityBook.SetCurrentSpec(LAS+1)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- ActionBarFrameForm Functions
---------------------------------------------------------------------------------------------------

function ChargeUI_ActionBar:OnMainMoved( wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom )
	local l,t,r,b = wndControl:GetAnchorOffsets()
	self.OffsetsMain = {l,t,r,b}
end

function ChargeUI_ActionBar:OnBar2Move( wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom )
	local l,t,r,b = wndControl:GetAnchorOffsets()
	self.OffsetsBar2 = {l,t,r,b}
	self:ArrangeGridWithGab(self.wndBar2:FindChild("Grid"),5)
end

local ActionBarFrameInst = ChargeUI_ActionBar:new()
ActionBarFrameInst:Init()
