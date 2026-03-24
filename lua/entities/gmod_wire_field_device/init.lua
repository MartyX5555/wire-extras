
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include("shared.lua")

ENT.WireDebugName = "WIRE_FieldGen"

local EMP_IGNORE_INPUTS = {
	Kill         = true,
	Pod          = true,
	Eject        = true,
	Lock         = true,
	Terminate    = true,
	["Damage Armor"] = true,
	["Strip weapons"] = true,
	["Damage Health"] = true,
}

function ENT:Initialize()
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	self.multiplier    = 1
	self.active        = 0
	self.objects       = {}
	self.prox          = 100
	self.direction     = Vector(0,1,0)
	self.ignore        = {}

	self.props         = 1
	self.npcs          = 1
	self.player        = 0

	if ( self.FieldType == "Wind" ) then
		self.direction = Vector(1,0,0)
	end

	self:ConfigInOuts()
	self:SetOverlayText( self:GetDisplayText() )

end

function ENT:SetType( v )
	self.FieldType = v
end

function ENT:Setworkonplayers( v )
	self.workonplayers = tobool(v)
end

function ENT:Setignoreself( v )
	self.ignoreself = tobool(v)
end
function ENT:Setarc( v )
	self.arc=v
end

function ENT:BuildIgnoreList()

	local queue={self}
	self.ignore={}
	self.ignore[ self:EntIndex() ] =  self

	while ( # queue > 0 ) do

		local CEnt = constraint.GetTable( table.remove( queue ) )
		if type(CEnt) == "table" then
			for _, mc in pairs( CEnt ) do
				if mc.Constraint.Type ~= "Rope" then
					for _, my in pairs( mc.Entity ) do
						if self.ignore[ my.Index ] ~= my.Entity then
							self.ignore[ my.Index ] = my.Entity
							table.insert( queue , my.Entity )
						end
					end
				end
			end
		end

	end

end

function ENT:GetTypes()
	return { "Gravity" , "Pull" , "Push" , "Hold" , "Wind" , "Vortex" , "Flame" , "Crush" , "EMP" , "Death" , "Heal" , "Battery" , "NoCollide" , "Speed"  }
end

function ENT:GetTypeName( Type )

	local Text = ""

	if Type == "Gravity" then
		Text = "Zero Gravity"
	elseif Type == "Pull" then
		Text = "Attraction"
	elseif Type == "Push" then
		Text = "Repulsion"
	elseif Type == "Hold" then
		Text = "Stasis"
	elseif Type == "Wind" then
		Text = "Wind"
	elseif Type == "Vortex" then
		Text = "Vortex"
	elseif Type == "Flame" then
		Text = "Flame"
	elseif Type == "Crush" then
		Text = "Pressure"
	elseif Type == "EMP" then
		Text = "Electromagnetic"
	elseif Type == "Death" then
		Text = "Radiation"
	elseif Type == "Heal" then
		Text = "Recovery"
	elseif Type == "Battery" then
		Text = "Battery"
	elseif Type == "NoCollide" then
		Text = "Phase"
	elseif Type == "Speed" then
		Text = "Accelerator"
	end

	return Text

end

function ENT:GetDisplayText()

	local Isactive = self.active > 0 and true or false
	local FormatDirection = self.direction.x .. "," .. self.direction.y .. "," .. self.direction.z
	local text = "Status: " .. (Isactive and "On" or "Off") .. "\n\n"

	text = text .. "Field Type: " .. self:GetTypeName( self.FieldType ) .. "\n"
	text = text .. "Radius: " .. self.prox .. "\n"
	text = text .. "Arc Size: " .. self.arc .. "\n"
	text = text .. "Strength: " .. self.multiplier .. "\n"
	text = text .. "Direction: " .. FormatDirection .. "\n\n"

	text = text .. "Ignore Connected Props: " .. (self.ignoreself and "Yes" or "No") .. "\n"
	text = text .. "Affect Players: " .. (self.workonplayers and "Yes" or "No")

	return text
end

local AllInputs = {
	"Active",
	"Distance (Sets the range of the field)",
	"Multiplier (Sets the magnitude of the effect upon the props in this field)",
	"Direction.X (Sets the X direction component)",
	"Direction.Y (Sets the Y direction component)",
	"Direction.Z (Sets the Z direction component)",
	"Direction [VECTOR] (Sets the direction as a normalized vector)"
}


function ENT:ConfigInOuts()

	if ( self.FieldType == "Gravity" ) then
		self.Inputs = WireLib.CreateInputs(self, {AllInputs[1], AllInputs[2]})
	elseif ( self.FieldType == "Wind" or self.FieldType == "Vortex" ) then
		self.Inputs = WireLib.CreateInputs(self, {AllInputs[1], AllInputs[2], AllInputs[3], AllInputs[4], AllInputs[5], AllInputs[6], AllInputs[7]})
	else
		self.Inputs = WireLib.CreateInputs(self, {AllInputs[1], AllInputs[2], AllInputs[3]})
	end

end

function ENT:TriggerInput(iname, value)

	if iname == "Active" then
		self.active = value
		if value == 0 then
			self:Disable()
		end
	end

	if iname == "Distance" then
		if value > 0 then
			self.prox = value
		else
			self.prox = 100
		end
	end

	if iname == "Multiplier" then
		if value > 0 then
			self.multiplier = value
		else
			self.multiplier = 1
		end
	end

	if iname == "Direction.X" and math.abs(value) > 0 then
		self.direction.x = value
	end

	if iname == "Direction.Y" and math.abs(value) > 0 then
		self.direction.y = value
	end

	if iname == "Direction.Z" and math.abs(value) > 0 then
		self.direction.z = value
	end

	local default = self.FieldType == "Wind" and Vector(1,0,0) or Vector(0,1,0)
	if iname == "Direction" and value ~= default then
		self.direction = value
	end

	self:SetOverlayText( self:GetDisplayText() )

end

function ENT:Toggle_Prop_Gravity( prop , yes_no )

	if not IsValid(prop) then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetMoveType() == MOVETYPE_NONE then return false end
	if prop:GetMoveType() == MOVETYPE_NOCLIP then return false end //do this to prevent -uncliping-

	if prop:GetClass() ~= "player" and !gamemode.Call("PhysgunPickup",self.pl,prop) then return false end

	if prop:GetMoveType() ~= MOVETYPE_VPHYSICS then
		if yes_no == false then

			if prop:IsNPC() or prop:IsPlayer() then
				prop:SetMoveType(MOVETYPE_FLY)
				prop:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
			else
				prop:SetGravity(0)
			end

		else

			if prop:IsPlayer() then
				prop:SetMoveType(MOVETYPE_WALK)
				prop:SetMoveCollide(MOVECOLLIDE_DEFAULT)
			elseif prop:IsNPC() then
				prop:SetMoveType(MOVETYPE_STEP)
				prop:SetMoveCollide(MOVECOLLIDE_DEFAULT)
			else
				prop:SetGravity(1)
			end

		end
	end

	if prop:GetPhysicsObjectCount() > 1 then
		for x=0,prop:GetPhysicsObjectCount()-1 do
			local part=prop:GetPhysicsObjectNum(x)
			part:EnableGravity( yes_no )
		end
		return false
	end

	local phys=prop:GetPhysicsObject()

	if not phys:IsValid() then return end

	phys:EnableGravity( yes_no )

end

function ENT:Gravity_Logic()

	local NewObjs={}

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos(), self.prox or 10 ) ) do
		self:Toggle_Prop_Gravity( contact , false )
		NewObjs[ contact:EntIndex() ] = contact
	end

	for idx,contact in pairs( self.objects ) do
		if ( NewObjs[ idx ] ~= contact ) then
			self:Toggle_Prop_Gravity( contact , true )
		end
	end

	self.objects = NewObjs

end

function ENT:Gravity_Disable()

	for _,contact in pairs( self.objects ) do
		self:Toggle_Prop_Gravity( contact , true )
	end

end

function ENT:Slow_Prop( prop , yes_no )

	if not prop:IsValid() then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetMoveType() == MOVETYPE_NONE then return false end
	if prop:GetMoveType() == MOVETYPE_NOCLIP then return false end //do this to prevent -uncliping-

	if prop:GetClass() ~= "player" and !gamemode.Call("PhysgunPickup",self.pl,prop) then return false end

	local MulU=self.multiplier+15.1

	if MulU < 15.1 then
		MulU=15.1
	end

	if prop:GetMoveType() ~= MOVETYPE_VPHYSICS then
		if yes_no == false then

			if prop:IsNPC() or prop:IsPlayer() then

				if !prop:Alive() and prop:GetRagdollEntity() then
					local RagDoll=prop:GetRagdollEntity()
					for x=1,RagDoll:GetPhysicsObjectCount() do
						local part=RagDoll:GetPhysicsObjectNum(x)

						part:EnableGravity( yes_no )
						part:SetDragCoefficient( 100 * self.multiplier )

					end
				end

				prop:SetMoveType(MOVETYPE_FLY)
				prop:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
			else
				prop:SetGravity(0)
			end

			local Mul = -( 1 - 1 / ( MulU / 15 ) )
			local vel = prop:GetVelocity()

			if prop.AddVelocity then
				prop:AddVelocity( vel * Mul )
			else
				prop:SetVelocity( vel * Mul )
			end

		else


			if prop:IsNPC() or prop:IsPlayer() then
				if !prop:Alive() and prop:GetRagdollEntity() then
					local RagDoll=prop:GetRagdollEntity()
					for x=1,RagDoll:GetPhysicsObjectCount() do
						local part=RagDoll:GetPhysicsObjectNum(x)

						part:EnableGravity( yes_no )
						part:SetDragCoefficient( 1 )

					end
				end
			end


			if prop:IsPlayer() then
				prop:SetMoveCollide(MOVETYPE_WALK)
				prop:SetMoveCollide(MOVECOLLIDE_DEFAULT)
			elseif prop:IsNPC() then
				prop:SetMoveCollide(MOVETYPE_STEP)
				prop:SetMoveCollide(MOVECOLLIDE_DEFAULT)
			else
				prop:SetGravity(1)
			end

		end
	end

	if prop:GetPhysicsObjectCount() > 1 then
		for x=0,prop:GetPhysicsObjectCount()-1 do
			local part=prop:GetPhysicsObjectNum(x)

			part:EnableGravity( yes_no )
			if ! yes_no then
				part:SetDragCoefficient( 100 * self.multiplier )
			else
				part:SetDragCoefficient( 1 )
			end

		end
		return false
	end

	local phys=prop:GetPhysicsObject()

	if not phys:IsValid() then return end

	phys:EnableGravity( yes_no )
	if ! yes_no then
		phys:SetDragCoefficient( 100 * self.multiplier )
	else
		phys:SetDragCoefficient( 1 )
	end

end

function ENT:Static_Logic()

	local NewObjs={}

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos(), self.prox or 10 ) ) do
		self:Slow_Prop( contact , false )
		NewObjs[ contact:EntIndex() ] = contact
	end

	for idx,contact in pairs( self.objects ) do
		if ( NewObjs[ idx ] ~= contact ) then
			self:Slow_Prop( contact , true )
		end
	end

	self.objects = NewObjs

end

function ENT:Static_Disable()

	for _,contact in pairs( self.objects ) do
		self:Slow_Prop( contact , true )
	end

end

function ENT:PullPushProp( prop , vec )

	if not IsValid(prop) then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetMoveType() == MOVETYPE_NONE then return false end

	if prop:GetClass() ~= "player" and !gamemode.Call("PhysgunPickup",self.pl,prop) then return false end

	if prop:GetMoveType() ~= MOVETYPE_VPHYSICS then
		if prop.AddVelocity then
			prop:AddVelocity( vec )
		else
			prop:SetVelocity( vec )
		end
	end

	if prop:GetPhysicsObjectCount() > 1 then
		for x=0,prop:GetPhysicsObjectCount()-1 do
			local part=prop:GetPhysicsObjectNum(x)
			part:AddVelocity( vec )
		end
		return false
	end

	local phys=prop:GetPhysicsObject()

	if not phys:IsValid() then return end

	phys:AddVelocity( vec )

end

function ENT:VelModProp( prop , mul )

	if not IsValid(prop) then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetMoveType() == MOVETYPE_NONE then return false end

	if prop:GetClass() ~= "player" and !gamemode.Call("PhysgunPickup",self.pl,prop) then return false end

	if prop:GetMoveType() ~= MOVETYPE_VPHYSICS then
		local vel1 = prop:GetVelocity()
		vel1:Normalize()

		if prop.AddVelocity then
			prop:AddVelocity( vel1 * mul )
		else
			prop:SetVelocity( vel1 * mul)
		end
	end

	if prop:GetPhysicsObjectCount() > 1 then
		for x=0,prop:GetPhysicsObjectCount()-1 do
			local part=prop:GetPhysicsObjectNum(x)
			local vel2=part:GetVelocity()
			vel2:Normalize()
			part:AddVelocity( vel2 * mul )
		end
		return false
	end

	local phys=prop:GetPhysicsObject()

	if not phys:IsValid() then return end

	local vel3 = phys:GetVelocity()
	vel3:Normalize()
	phys:AddVelocity( vel3 * mul )

end


function ENT:Pull_Logic()

	local Center=self:GetPos()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos(), self.prox or 10 ) ) do

		local Path = Center-contact:GetPos()
		local Length = math.max(Path:Length(), 1e-5)
		Path = Path * ( self.multiplier * math.sqrt(math.max(1-Length/self.prox, 0)) / Length )
		self:PullPushProp( contact , Path )

	end

end

function ENT:Pull_Disable()


end

function ENT:Push_Logic()

	local Center=self:GetPos()
	local HalfProx=self.prox / 2

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos(), self.prox or 10 ) ) do

		local Path = contact:GetPos() - Center
		local Length = math.max(Path:Length(), 1e-5)
		Path = Path * (self.multiplier / Length)
		self:PullPushProp( contact , Path )

	end

end


function ENT:Push_Logic()

	local Center=self:GetPos()
	local HalfProx=self.prox / 2

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos(), self.prox or 10 ) ) do

		local Path = contact:GetPos()-Center
		local Length = Path:Length()
		Path = Path * ( 1.0 / Length )
		self:PullPushProp( contact , Path * self.multiplier )

	end

end



function ENT:Push_Logic()

	local Center=self:GetPos()
	local HalfProx=self.prox / 2

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos(), self.prox or 10 ) ) do

		local Path = contact:GetPos()-Center
		local Length = Path:Length()
		Path = Path * ( 1.0 / Length )
		self:PullPushProp( contact , Path * self.multiplier )

	end

end


function ENT:Push_Disable()
end

function ENT:Wind_Logic()

	local Up = self.direction:GetNormalized()
	Up:Normalize()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos(), self.prox or 10 ) ) do

		self:PullPushProp( contact , Up * self.multiplier )

	end

end

function ENT:Wind_Disable()
end

local blacklist = {
	gmod_wire_hologram = true,
}
local function FindInSphere(source, origin, radius)
	local results = {}
	for _, entity in ipairs(ents.FindInSphere(origin,radius)) do
		if entity == source then continue end
		if blacklist[entity:GetClass()] then continue end
		if string.StartsWith(entity:GetClass(), "env_") then continue end
		table.insert(results, entity)
	end
	return results
end

function ENT:GetEverythingInSphere( center , range )

	local Objs = {}

	if self.arc >= 0 and self.arc < 360 then
		local rgc = math.cos( (self.arc / 360) * math.pi ) //decrease arc by half, 0-360 isntead of 0-180
		local upvec = self:GetUp()

		for _, obj in ipairs( FindInSphere(self, center, range) ) do
			if not (obj:IsPlayer() or obj:GetMoveType() == MOVETYPE_NOCLIP or gamemode.Call("PhysgunPickup", self:GetCreator(), obj)==false) then
				local dir = ( obj:GetPos() - center )
				dir:Normalize()
				if dir:Dot( upvec ) > rgc then
					Objs[#Objs + 1] = obj
				end
			end
		end
	else
		for _, obj in ipairs( FindInSphere(self, center, range) ) do
			if obj:IsPlayer() and not self.workonplayers then  continue end
			if obj:GetMoveType() == MOVETYPE_NOCLIP then  continue end
			if not obj:IsPlayer() and not gamemode.Call("PhysgunPickup", self:GetCreator(), obj) then  continue end

			Objs[#Objs + 1] = obj
		end
	end

	return Objs
end

function ENT:Vortex_Logic()

	local Up = self.direction:GetNormalized()
	Up:Normalize()
	local Center=self:GetPos()
	local HalfProx=self.prox / 2

	for _,contact in pairs( self:GetEverythingInSphere( Center , self.prox or 10 ) ) do

		local Path = ( contact:GetPos()+contact:GetVelocity() )-Center
		Path:Normalize()
		self:PullPushProp( contact , Path:Cross( Up ) * self.multiplier )

	end

end



function ENT:Vortex_Disable()


end

function ENT:Flame_Apply( prop  , yes_no )

	if not IsValid(prop) then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if prop:GetMoveType() == MOVETYPE_NONE then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetClass() ~= "player" and !gamemode.Call("PhysgunPickup",self.pl,prop) then return false end

	if yes_no == true then
		prop:Ignite( self.multiplier , 0.0 )
	else
		prop:Extinguish()
	end

end


function ENT:Flame_Logic()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do
		self:Flame_Apply( contact , true )
	end

end

function ENT:Flame_Disable()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do
		self:Flame_Apply( contact , false )
	end

end

function ENT:Crush_Apply( prop , yes_no )

	if not IsValid(prop) then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetClass() ~= "player" and !gamemode.Call( "PhysgunPickup", self.pl , prop ) then return false end

	if yes_no == true then
		prop:TakeDamage( self.multiplier ,  self.pl )
	end

end

function ENT:Battery_Apply( prop , yes_no )

	local x,maxx

	if not IsValid(prop) then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetClass() ~= "player" and !gamemode.Call( "PhysgunPickup", self.pl , prop ) then return false end

	if prop.Armor then

		x=prop:Armor()+self.multiplier
		maxx=100 // prop:GetMaxHealth()

		if ( x > maxx ) then
			x=maxx
		end

		prop:SetArmor( x )

	end

end

function ENT:Health_Apply( prop , yes_no )

	local x,maxx

	if not IsValid(prop) then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetClass() ~= "player" and !gamemode.Call( "PhysgunPickup", self.pl , prop ) then return false end

	if yes_no == true then

		x=prop:Health()+self.multiplier
		maxx=prop:GetMaxHealth()

		if ( x > maxx ) then
			x=maxx
		end

		prop:SetHealth( x )

	end

end

function ENT:Heal_Logic()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do
		if contact:IsNPC() or contact:IsPlayer() then

			self:Health_Apply( contact , true )

		end
	end

end

function ENT:Heal_Disable()

end

function ENT:Death_Logic()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do
		if contact:IsNPC() or contact:IsPlayer() then
			self:Crush_Apply( contact , true )//cheat and use crushing effect, just do it on npcs/players tho.
		end
	end

end

function ENT:Death_Disable()

end

function ENT:Crush_Logic()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do
		self:Crush_Apply( contact , true )
	end

end

function ENT:Crush_Disable()

end

function ENT:EMP_Apply( prop , yes_no )

	if not IsValid(prop) then return end
	if prop:IsPlayer() then return end

	if ( self.ignore[ prop:EntIndex() ] == prop ) then return false end

	if not self.workonplayers and prop:GetClass() == "player" then
		return false
	end

	if prop:GetClass() ~= "player" and !gamemode.Call( "PhysgunPickup", self.pl , prop ) then return false end

	if (prop) and (prop.Inputs) and type(prop.Inputs) == "table" then
		for k,v in pairs(prop.Inputs) do

			if not EMP_IGNORE_INPUTS[ k ] then
				//Msg( k .. "\n" ) use to find out what inputs are bad to override. =D

				if v.Type == "NORMAL" then

					if (prop.TriggerInput) then
						if yes_no then
							prop:TriggerInput( k , prop.Inputs[ k ].Value + math.random() * ( self.multiplier * 2 ) - self.multiplier )
						else
							prop:TriggerInput( k , prop.Inputs[ k ].Value )
						end

					end

				elseif v.Type == "VECTOR" or v.Type == "ANGLE" then

					if (prop.TriggerInput) then
						if yes_no then
							prop:TriggerInput( k , prop.Inputs[ k ].Value + Vector(math.random() * ( self.multiplier * 2 ) - self.multiplier,math.random() * ( self.multiplier * 2 ) - self.multiplier ,math.random() * ( self.multiplier * 2 ) - self.multiplier) )
						else
							prop:TriggerInput( k , prop.Inputs[ k ].Value )
						end

					end
				end

			end
		end
	end

end

function ENT:EMP_Logic()

	local NewObjs={}
	local Range = self.prox or 10
	local Entities = self:GetEverythingInSphere( self:GetPos(), Range )

	for _,contact in pairs( Entities ) do
		self:EMP_Apply( contact , true )
		NewObjs[ contact:EntIndex() ] = contact
	end

	for idx,contact in pairs( self.objects ) do
		if ( NewObjs[ idx ] ~= contact ) then
			self:EMP_Apply( contact , false )
		end
	end

	self.objects = NewObjs

end

function ENT:EMP_Disable()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do
		self:EMP_Apply( contact , false )
	end

end

function ENT:WakeUp( prop )

	if prop ~= nil then
		if prop:GetMoveType() == MOVETYPE_VPHYSICS then

			if prop:GetPhysicsObjectCount() > 1 then
				for x=0,prop:GetPhysicsObjectCount()-1 do
					local part=prop:GetPhysicsObjectNum(x)
					part:Wake()
				end
				return false
			end

			local phys=prop:GetPhysicsObject()
			if ( phys:IsValid() ) then phys:Wake() end

		end
	end

end

function ENT:NoCollide_Logic()

	local myid
	local obj
	local Valid={}

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do

		myid=contact:EntIndex()

		if ( self.ignore[ myid ] ~= contact ) then

			Valid[ myid ]=true

			if self.objects[ myid ] == nil and contact.SetCollisionGroup and contact.GetCollisionGroup then

				self.objects[ myid ] = {}
				self.objects[ myid ].old_group=contact:GetCollisionGroup()
				self.objects[ myid ].obj=contact
				contact:SetCollisionGroup( COLLISION_GROUP_WORLD )
				self:WakeUp(contact)

			end
		end

	end

	for Idx,contact in pairs( self.objects ) do
		if true ~= Valid[ Idx ] and type(contact) == "table" then

			if ( contact.obj:IsValid() ) then
				contact.obj:SetCollisionGroup( contact.old_group )
				self:WakeUp(contact.obj)
			end

			self.objects[Idx]=nil

		end
	end

end

function ENT:NoCollide_Disable()

	for Idx,contact in pairs( self.objects ) do
		if type(contact) == "table" then

			if ( contact.obj:IsValid() ) then
				contact.obj:SetCollisionGroup( contact.old_group )
				self:WakeUp(contact.obj)
			end

		end
	end

	self.objects={}

end

function ENT:Battery_Logic()

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do
		if contact:IsNPC() or contact:IsPlayer() then

			self:Battery_Apply( contact , true )

		end
	end

end

function ENT:Speed_Logic()

	local NewObjs={}
	local doo=nil

	for _,contact in pairs( self:GetEverythingInSphere( self:GetPos() , self.prox or 10 ) ) do

		if ( self.multiplier > 0 ) then
			self:VelModProp( contact , 1+self.multiplier )
		elseif ( self.multiplier < 0 ) then
			self:VelModProp( contact , -1+self.multiplier )
		end

	end

end

function ENT:Think()

	if self.ignoreself then
		self:BuildIgnoreList() // ignore these guys...
	else
		self.ignore = {}
	end

	if self.active ~= 0 then

		if self.FieldType == "Gravity" then
			self:Gravity_Logic()
		elseif self.FieldType == "Hold" then
			self:Static_Logic()
		elseif self.FieldType == "Pull" then
			self:Pull_Logic()
		elseif self.FieldType == "Push" then
			self:Push_Logic()
		elseif self.FieldType == "Wind" then
			self:Wind_Logic()
		elseif self.FieldType == "Vortex" then
			self:Vortex_Logic()
		elseif self.FieldType == "Flame" then
			self:Flame_Logic()
		elseif self.FieldType == "Crush" then
			self:Crush_Logic()
		elseif self.FieldType == "Death" then
			self:Death_Logic()
		elseif self.FieldType == "Heal" then
			self:Heal_Logic()
		elseif self.FieldType == "NoCollide" then
			self:NoCollide_Logic()
		elseif self.FieldType == "Battery" then
			self:Battery_Logic()
		elseif self.FieldType == "Speed" then
			self:Speed_Logic()
		elseif self.FieldType == "EMP" then
			self:EMP_Logic()
		end

	end

	self.BaseClass.Think(self)
end

function ENT:Disable()

	if self.FieldType == "Gravity" then
		self:Gravity_Disable()
	elseif self.FieldType == "NoCollide" then
		self:NoCollide_Disable()
	elseif self.FieldType == "Hold" then
		self:Static_Disable()
	elseif self.FieldType == "Pull" then
		self:Pull_Disable()
	elseif self.FieldType == "Push" then
		self:Push_Disable()
	elseif self.FieldType == "Wind" then
		self:Wind_Disable()
	elseif self.FieldType == "Vortex" then
		self:Vortex_Disable()
	elseif self.FieldType == "Flame" then
		self:Flame_Disable()
	elseif self.FieldType == "Crush" then
		self:Crush_Disable()
	elseif self.FieldType == "Death" then
		self:Death_Disable()
	elseif self.FieldType == "Heal" then
		self:Heal_Disable()
	elseif self.FieldType == "EMP" then
		self:EMP_Disable()
	end

	self.BaseClass.Think(self)
end

function ENT:OnRemove()
	self:Disable()
end
