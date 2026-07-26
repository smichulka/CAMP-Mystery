--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

type UIAssetControllerState = {
	root: Folder?,
	destroyed: boolean,
}

local UIAssetController = {}
UIAssetController.__index = UIAssetController

export type UIAssetController = typeof(setmetatable({} :: UIAssetControllerState, UIAssetController))

local function normalizeAssetId(value: any): string?
	local digits: string? = nil
	if type(value) == "string" then
		digits = string.match(value, "^%s*(%d+)%s*$")
			or string.match(value, "^rbxassetid://(%d+)$")
	elseif type(value) == "number"
		and value == value
		and value > 0
		and value < math.huge
		and value % 1 == 0
	then
		digits = string.format("%.0f", value)
	end
	if not digits or not string.find(digits, "[1-9]") then
		return nil
	end
	return "rbxassetid://" .. digits
end

local function findRoot(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local images = if assets then assets:FindFirstChild("Images") else nil
	local ui = if images then images:FindFirstChild("UI") else nil
	return if ui and ui:IsA("Folder") then ui else nil
end

function UIAssetController.new(): UIAssetController
	return setmetatable({
		root = findRoot(),
		destroyed = false,
	}, UIAssetController)
end

function UIAssetController:Resolve(key: string): string?
	if self.destroyed or #key == 0 or #key > 64 or string.match(key, "^[%w_%-]+$") == nil then
		return nil
	end
	local root = self.root
	if not root or root.Parent == nil then
		root = findRoot()
		self.root = root
	end
	if not root then
		return nil
	end

	local resolved = normalizeAssetId(root:GetAttribute(key))
	if resolved then
		return resolved
	end
	local asset = root:FindFirstChild(key)
	if not asset then
		return nil
	end
	if asset:IsA("StringValue") then
		return normalizeAssetId(asset.Value)
	end
	if asset:IsA("NumberValue") then
		return normalizeAssetId(asset.Value)
	end
	if asset:IsA("ImageLabel") then
		return normalizeAssetId(asset.Image)
	end
	if asset:IsA("ImageButton") then
		return normalizeAssetId(asset.Image)
	end
	return normalizeAssetId(asset:GetAttribute("AssetId"))
end

function UIAssetController:Destroy()
	self.destroyed = true
	self.root = nil
end

return table.freeze(UIAssetController)
