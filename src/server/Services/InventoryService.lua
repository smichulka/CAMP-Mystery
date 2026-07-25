--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EquipmentCatalog = require(Shared.Config:WaitForChild("EquipmentCatalog"))
local EquipmentTypes = require(Shared.Types:WaitForChild("EquipmentTypes"))
local EquipmentRules = require(script.Parent.Parent.Config:WaitForChild("EquipmentRules"))

type EquipmentId = EquipmentTypes.EquipmentId
type ItemInstance = EquipmentTypes.ItemInstance
type ItemSnapshot = EquipmentTypes.ItemSnapshot
type InventorySnapshot = EquipmentTypes.InventorySnapshot

type InventoryServiceState = {
	roundId: number,
	revision: number,
	nextItemNumber: number,
	capacity: number,
	inventories: { [string]: { string } },
	items: { [string]: ItemInstance },
}

local InventoryService = {}
InventoryService.__index = InventoryService

export type InventoryService = typeof(
	setmetatable({} :: InventoryServiceState, InventoryService)
)

local DEFAULT_CAPACITY = 15

local function removeValue(values: { string }, value: string): boolean
	local index = table.find(values, value)
	if not index then
		return false
	end
	table.remove(values, index)
	return true
end

function InventoryService.new(capacity: number?): InventoryService
	local resolvedCapacity = capacity or DEFAULT_CAPACITY
	assert(resolvedCapacity > 0, "Inventory capacity must be positive")
	return setmetatable({
		roundId = 0,
		revision = 0,
		nextItemNumber = 0,
		capacity = resolvedCapacity,
		inventories = {},
		items = {},
	}, InventoryService)
end

function InventoryService:BeginRound(roundId: number)
	assert(roundId > self.roundId, "Round IDs must increase")
	self.roundId = roundId
	self.revision = 0
	self.nextItemNumber = 0
	self.inventories = {}
	self.items = {}
end

function InventoryService:RegisterParticipant(participantId: string)
	if not self.inventories[participantId] then
		self.inventories[participantId] = {}
		self.revision += 1
	end
end

function InventoryService:GetCount(participantId: string): number
	local inventory = self.inventories[participantId]
	return if inventory then #inventory else 0
end

function InventoryService:HasSpace(participantId: string): boolean
	return self:GetCount(participantId) < self.capacity
end

function InventoryService:Grant(
	participantId: string,
	equipmentId: EquipmentId
): (boolean, string?)
	local inventory = self.inventories[participantId]
	if not inventory then
		return false, "Unknown participant"
	end
	if #inventory >= self.capacity then
		return false, "Inventory is full"
	end

	local rule = EquipmentRules[equipmentId]
	if not rule then
		return false, "Unknown equipment"
	end

	self.nextItemNumber += 1
	local instanceId = string.format(
		"item:%d:%d",
		self.roundId,
		self.nextItemNumber
	)
	local item: ItemInstance = {
		instanceId = instanceId,
		equipmentId = equipmentId,
		ownerParticipantId = participantId,
		charges = rule.maxCharges,
		durability = rule.maxDurability,
		equipped = false,
		cooldownEndsAt = 0,
	}
	self.items[instanceId] = item
	table.insert(inventory, instanceId)
	self.revision += 1
	return true, instanceId
end

function InventoryService:GetOwnedItem(
	participantId: string,
	instanceId: string
): ItemInstance?
	local item = self.items[instanceId]
	if not item or item.ownerParticipantId ~= participantId then
		return nil
	end
	return item
end

function InventoryService:GetItemServer(instanceId: string): ItemInstance?
	return self.items[instanceId]
end

function InventoryService:GetDroppedItemIds(): { string }
	local result: { string } = {}
	for instanceId, item in self.items do
		if item.ownerParticipantId == nil then
			table.insert(result, instanceId)
		end
	end
	table.sort(result)
	return result
end

function InventoryService:Equip(
	participantId: string,
	instanceId: string
): (boolean, string?)
	local inventory = self.inventories[participantId]
	local item = self:GetOwnedItem(participantId, instanceId)
	if not inventory or not item then
		return false, "Item is not owned by participant"
	end

	for _, ownedId in inventory do
		local ownedItem = self.items[ownedId]
		if ownedItem then
			ownedItem.equipped = ownedId == instanceId
		end
	end
	self.revision += 1
	return true, nil
end

function InventoryService:Drop(
	participantId: string,
	instanceId: string
): (boolean, string?)
	local inventory = self.inventories[participantId]
	local item = self:GetOwnedItem(participantId, instanceId)
	if not inventory or not item or not removeValue(inventory, instanceId) then
		return false, "Item is not owned by participant"
	end

	item.ownerParticipantId = nil
	item.equipped = false
	self.revision += 1
	return true, nil
end

function InventoryService:Transfer(
	fromParticipantId: string,
	toParticipantId: string,
	instanceId: string
): (boolean, string?)
	local fromInventory = self.inventories[fromParticipantId]
	local toInventory = self.inventories[toParticipantId]
	local item = self:GetOwnedItem(fromParticipantId, instanceId)
	if not fromInventory or not toInventory or not item then
		return false, "Transfer participants or item are invalid"
	end
	if #toInventory >= self.capacity then
		return false, "Target inventory is full"
	end
	if not removeValue(fromInventory, instanceId) then
		return false, "Item is not in source inventory"
	end

	item.ownerParticipantId = toParticipantId
	item.equipped = false
	table.insert(toInventory, instanceId)
	self.revision += 1
	return true, nil
end

function InventoryService:RecoverDropped(
	participantId: string,
	instanceId: string
): (boolean, string?)
	local inventory = self.inventories[participantId]
	local item = self.items[instanceId]
	if not inventory or not item then
		return false, "Participant or item is invalid"
	end
	if item.ownerParticipantId ~= nil then
		return false, "Item is already owned"
	end
	if #inventory >= self.capacity then
		return false, "Inventory is full"
	end

	item.ownerParticipantId = participantId
	table.insert(inventory, instanceId)
	self.revision += 1
	return true, nil
end

function InventoryService:DropAll(participantId: string): { string }
	local inventory = self.inventories[participantId]
	if not inventory then
		return {}
	end

	local dropped = table.clone(inventory)
	for _, instanceId in dropped do
		local item = self.items[instanceId]
		if item then
			item.ownerParticipantId = nil
			item.equipped = false
		end
	end
	table.clear(inventory)
	self.revision += 1
	return dropped
end

function InventoryService:ConsumeCharge(
	participantId: string,
	instanceId: string,
	now: number
): (boolean, string?)
	local item = self:GetOwnedItem(participantId, instanceId)
	if not item or not item.equipped then
		return false, "Item must be owned and equipped"
	end
	if item.charges <= 0 or item.durability <= 0 then
		return false, "Item is depleted"
	end
	if now < item.cooldownEndsAt then
		return false, "Item is cooling down"
	end

	local rule = EquipmentRules[item.equipmentId]
	item.charges -= 1
	item.cooldownEndsAt = now + rule.cooldownSeconds
	self.revision += 1
	return true, nil
end

function InventoryService:GetSnapshot(participantId: string): InventorySnapshot
	local snapshots: { ItemSnapshot } = {}
	local inventory = self.inventories[participantId] or {}
	for _, instanceId in inventory do
		local item = self.items[instanceId]
		if item then
			local presentation = EquipmentCatalog[item.equipmentId]
			table.insert(snapshots, {
				instanceId = item.instanceId,
				equipmentId = item.equipmentId,
				displayName = presentation.displayName,
				charges = item.charges,
				durability = item.durability,
				equipped = item.equipped,
			})
		end
	end

	return {
		roundId = self.roundId,
		revision = self.revision,
		capacity = self.capacity,
		items = snapshots,
	}
end

return InventoryService
