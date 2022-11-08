
-- CustomizationService
-- Author(s): Sam Floyd
-- Date: 08/31/2022



--[[

    Use for anything related to granting users skins, upgrading skins.

    Feel free to use for retrieving a user's skin profile, or directly use DataService, your preference.

    Contains a multitude of RemoteSignals for client UI manipulation


    // Methods
    put here

    // Client-Exposed Methods
    put here

    // Signals
    put here

]]

---------------------------------------------------------------------

-- Constants
local MIN_TIME_WAIT_MORPH = 3
-- Knit
local Knit = require( game:GetService("ReplicatedStorage").Packages:WaitForChild("Knit") )
local t = require( game:GetService("ReplicatedStorage").Util.t )
local RemoteSignal = require( game:GetService("ReplicatedStorage").Util.Remote.RemoteSignal )
-- Modules

-- Roblox Services
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
-- Variables
local insert = table.insert
-- Objects

---------------------------------------------------------------------


type skinTemplate = {
	skin : string;
	quantity : number;
}

local CustomizationService = Knit.CreateService {
	Name = "CustomizationService";
	Client = {
		SkinAdded = RemoteSignal.new();
	};
	MorphDebounce = {}
}


function CustomizationService.Client:RetrieveSkins( user : Player ) : {}
	return self.Server:RetrieveSkins ( user )
end

--Retrieve Skins
local tRetrieveSkins = t.tuple( t.instanceIsA("Player") )
function CustomizationService:RetrieveSkins( user : Player ) : {}
	assert( tRetrieveSkins( user ) )
	local userProfile : {}? = self.DataService:GetPlayerDataAsync( user ).Data
	local userSkins : {}? = userProfile.Skins
	return userSkins
end

--Retrieve Skin By Name
local tRetrieveSkinByName = t.tuple( t.instanceIsA("Player"), t.string )
function CustomizationService:RetrieveSkinByName( user : Player, skinName : string ) : {}
	assert( tRetrieveSkinByName( user, skinName ) )
	local userSkins : {}? = self:RetrieveSkins( user )
	if ( userSkins ) then
		for _ : number, skinData : {}? in ipairs ( userSkins ) do
			if ( skinData.skin ~= skinName ) then
				continue
			end
			return skinData
		end
	end
end

--User Owns Skin
local tUserOwnsSkin = t.tuple( t.instanceIsA("Player"), t.string )
function CustomizationService:UserOwnsSkin( user : Player, skinName : string) : boolean
	assert ( tUserOwnsSkin(user, skinName) )
	local userProfile : {} = self.DataService:GetPlayerDataAsync( user ).Data
	local userSkins : {} = userProfile.Skins
	if ( userSkins ) then
		for _ : number?, ownedSkin : {} in ipairs ( userSkins ) do
			if ( ownedSkin.skin == skinName ) then
				return true
			end
		end
	end
	--Return false if user does not own the skin
	return false
end

--Add Skin
local tAddSkin = t.tuple( t.instanceIsA("Player"), t.string )
function CustomizationService:AddSkin( user : Player, skinName : string ) : boolean
	assert( tAddSkin( user, skinName ) )
	local userSkins : {}? = self:RetrieveSkins( user ) :: {}

	local userOwnsSkin : boolean? = self:UserOwnsSkin( user, skinName )
	if ( userOwnsSkin ) then
		local skin = self:RetrieveSkinByName( user, skinName )
		skin.quantity += 1
		return
	end
	if ( not userOwnsSkin ) then
		local newSkin : skinTemplate = {
			skin = skinName;
			quantity = 1;
		}
		insert(userSkins, newSkin)
		self.Client.SkinAdded:Fire( user, skinName )
	end
end

--Remove Skin
local tRemoveSkin = t.tuple( t.instanceIsA("Player"), t.string, t.number)
function CustomizationService:RemoveSkin( user : Player, skinName : string, quantity : number )
	assert( tRemoveSkin( user, skinName, quantity ) )
	local userSkins : {}? = self:RetrieveSkins( user ) :: {}
	local userHasSkin : boolean? = self:UserOwnsSkin( user, skinName ) :: boolean

	if ( userHasSkin ) then
		local userSkin : string? = self:RetrieveSkinByName( user, skinName ) :: string
		local skinQuantity = userSkin.quantity
		local _task = "Delete"

		if ( skinQuantity > quantity ) then
			_task = "Remove"
		end

		local skinIndex = table.find(userSkins, userSkin)

		if _task == "Delete" and skinIndex then
			table.remove(userSkins, skinIndex)
		else
			userSkin.quantity -= quantity
		end
	end
end

local tRetrieveMorphFromSkin = t.tuple( t.string )
function CustomizationService:RetrieveMorphFromSkin( skinName : string ) : Model
	assert ( tRetrieveMorphFromSkin( skinName ))
	local morphPath = ServerStorage.Assets.Outfits
	for _ : number, morph : Model in ipairs ( morphPath:GetChildren() ) do
		if ( morph.Name == skinName ) and ( morph:IsA("Model") ) then
			return morph
		end
	end
end


--Equip Skin
local tEquipSkin = t.tuple( t.instanceIsA("Player"), t.string )
function CustomizationService:EquipSkin( user : Player, skinName : string ) : boolean
	print(skinName)
	assert( tEquipSkin( user, skinName ))
	local userProfile : {}? = self.DataService:GetPlayerDataAsync( user )
	local userOwnsSkin : boolean? = self:UserOwnsSkin( user, skinName, userProfile )
	if ( userOwnsSkin ) then
		local morph = self:RetrieveMorphFromSkin( skinName )
		local character = user.Character
		if ( not morph ) or ( not character ) or ( userProfile.EquippedSkin == skinName ) 
			or ( self.MorphDebounce[user] and time() - self.MorphDebounce[user] < MIN_TIME_WAIT_MORPH ) then
			return false
		end
		userProfile.Data.EquippedSkin = skinName
		self:ApplyMorph( character, morph )
		self.MorphDebounce[user] = time()
		return true
	end
	return false
end


function CustomizationService.Client:EquipSkin( user, skinName ) : boolean
	local didSucceed = self.Server:EquipSkin( user, skinName )
	return { didSucceed, skinName }
end


local tRemoveMorph = t.tuple( t.instanceIsA("Model") )
function CustomizationService:RemoveMorph( character : Model )
	assert( tRemoveMorph( character ))
	local morphContents = character:FindFirstChild("MorphContents")
	if morphContents then
		morphContents:Destroy()
	end
end

local tApplyMorph = t.tuple( t.instanceIsA("Model"), t.instanceIsA("Model"))
function CustomizationService:ApplyMorph( character : Model, morph : Model )
	assert( tApplyMorph( character, morph ))
	self:RemoveMorph( character )

	local function removeCharacterAccessories( character : Model )
		for _ : number, accessory : Accessory? in ipairs (character:GetDescendants()) do
			if ( accessory:IsA("Accessory") ) or ( accessory:IsA("Shirt") ) or ( accessory:IsA("Pants") ) then
				accessory:Destroy()
			end
		end
	end

	local function setM6D( bodyPart, userBodyPart )
		local M6D = bodyPart.Motor6D
		M6D.Part0 = userBodyPart
	end

	local function addMorphParts( character : Model, morph : Model )
		local newMorph = morph:Clone()
		local morphFolder = Instance.new("Folder")
		morphFolder.Name = "MorphContents"
		morphFolder.Parent = character

		for _, k in ipairs (newMorph:GetDescendants()) do
			if k:IsA("BasePart") then
				k.CanCollide = false
				k.Anchored = false
				k.Massless = true
			end
		end

		for _ : number, bodyPart : BasePart? in ipairs (newMorph:GetChildren()) do
			if bodyPart:IsA("BasePart") then
				local bodyPartName = bodyPart.Name
				bodyPart.Name = "Part"
				local userBodyPart = character:FindFirstChild(bodyPartName)
				local armor = bodyPart:FindFirstChild("Armor")
				if armor then
					for _: number, armorPart : BasePart in ipairs (armor:GetDescendants()) do
						if armorPart:IsA("BasePart") then
							armorPart.Parent = morphFolder
							armorPart.CFrame = userBodyPart.CFrame
							setM6D(armorPart, userBodyPart)
						end
					end
				end
			end
		end
	end

	local function addShirts( character : Model, morph : Model)
		local morphShirt = morph.Shirt:Clone()
		local morphPants = morph.Pants:Clone()

		morphShirt.Parent = character
		morphPants.Parent = character
	end

	removeCharacterAccessories( character )
	addMorphParts( character, morph )
	addShirts ( character, morph )
end




--Revert To Default Skin
local tRevertDefaultSkin = t.tuple( t.instanceIsA("Player") )
function CustomizationService:RevertToDefaultSkin( user : Player )
	assert( tRevertDefaultSkin(user) )
	local userProfile : {}? = self.DataService:GetPlayerDataAsync( user )
	userProfile.EquippedSkin = "default"
end

function CustomizationService:RemovePackage(user, character )
	local humanoid = character:WaitForChild("Humanoid")
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	local humanoidDescription = humanoid:GetAppliedDescription()
	humanoidDescription.Head = 0
	humanoidDescription.Torso = 0
	humanoidDescription.RightLeg = 0
	humanoidDescription.LeftLeg = 0
	humanoidDescription.RightArm = 0
	humanoidDescription.LeftArm = 0
	humanoid:ApplyDescription(humanoidDescription)
end


function CustomizationService:KnitStart(): ()
	Players.PlayerAdded:Connect(function(user)
		user.CharacterAdded:Connect(function(character)
			user.CharacterAppearanceLoaded:Connect(function()
				local userProfile = self.DataService:GetPlayerDataAsync( user ).Data
				if userProfile.EquippedSkin then
					local skin = userProfile.EquippedSkin
					if skin == "default" then
						skin = "Raiden"
					end
					local morph = game.ServerStorage.Assets.Outfits:FindFirstChild(skin)
					if morph then
						self:ApplyMorph( character, morph )
						task.delay(2, function()
							self:RemovePackage( user, character )
						end)
					end
				end
			end)
			

		end)
		self:AddSkin( user, "Raiden" )
		self:AddSkin( user, "TestSkin" )
		self:AddSkin( user, "Berserker" )
		self:AddSkin( user, "Stalker" )
		self:AddSkin( user, "Blademaster" )
	end)
end

function CustomizationService:KnitInit(): ()
	self.DataService = Knit.GetService("DataService")
end


return CustomizationService