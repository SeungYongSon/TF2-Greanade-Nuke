#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>


int LastUsed[MAXPLAYERS+1];
#define IN_ATTACK3		(1 << 25)

#define SOUND_LAUNCH	"misc/doomsday_missile_launch.wav"
#define SOUND_EXPLODE	"misc/doomsday_missile_explosion.wav"

public void OnMapStart() 
{
	PrecacheSound("weapons/knife_swing.wav", true);
	PrecacheSound(SOUND_LAUNCH);
	PrecacheSound(SOUND_EXPLODE);
	
	PrecacheGeneric("dooms_nuke_collumn");
	PrecacheGeneric("base_destroyed_smoke_doomsday");
	PrecacheGeneric("flash_doomsday");
	PrecacheGeneric("ping_circle");
	PrecacheGeneric("smoke_marker");
	
	PrecacheModel("models/props_halloween/eyeball_projectile.mdl");	
}

public void OnClientPostAdminCheck(int client)
{
    if (!IsFakeClient(client))
    {
		SDKHook(client, SDKHook_PreThink, OnPreThink);
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public Action OnPreThink(int iClient) 
{
	if(GetClientButtons(iClient) & IN_ATTACK3){
		if((IsValidClient(iClient)) && (IsPlayerAlive(iClient))){
			int currentTime = GetTime();
			if (currentTime - LastUsed[iClient] < 1.5)
				return Plugin_Handled;
			LastUsed[iClient] = GetTime();
			int iBall = CreateEntityByName("tf_projectile_stun_ball");
			if(IsValidEntity(iBall))
			{
				//iClient = GetEntPropEnt(iBall, Prop_Data, "m_hOwner")
				float vPosition[3];
				float vAngles[3];
				float flSpeed = 1500.0;
				float vVelocity[3];
				float vBuffer[3];
				GetClientEyePosition(iClient, vPosition);
				GetClientEyeAngles(iClient, vAngles);
						
				GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
						
				vVelocity[0] = vBuffer[0]*flSpeed;
				vVelocity[1] = vBuffer[1]*flSpeed;
				vVelocity[2] = vBuffer[2]*flSpeed;
				SetEntPropVector(iBall, Prop_Data, "m_vecVelocity", vVelocity);
				SetEntPropEnt(iBall, Prop_Send, "m_hOwnerEntity", iClient);
				SetEntProp(iBall, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
				SetVariantString("OnUser3 !self:FireUser4::3.0:1");
				AcceptEntityInput(iBall, "AddOutput");
				HookSingleEntityOutput(iBall, "OnUser4", BallBreak, false);
				AcceptEntityInput(iBall, "FireUser3");
				DispatchSpawn(iBall);
				EmitSoundToClient(iClient, "weapons/knife_swing.wav");
				TeleportEntity(iBall, vPosition, vAngles, vVelocity);
				CreateParticle(iBall, "xms_icicle_melt", true, 3.0);
				CreateParticle(iBall, "burningplayer_corpse", true, 3.0);
				CreateParticle(iBall, "unusual_smoking", true, 3.0);
				//CreateParticle(iBall, "utaunt_meteor_parent", true, 3.0);
				SetEntityRenderColor(iBall, 190, 251, 250, 255);
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;	
}

public void BallBreak(const char[] output, int caller, int activator, float delay){

	if(caller == -1){
		return;
	}
	
	float pos[3];
	
	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", pos);
	
	EmitSoundToAll(SOUND_EXPLODE);
	pos[2] += 436.0;
	ShowParticle(pos, "cinefx_goldrush", 15.0);
	/*
	float Flash[3], Collumn[3];
	Flash[0] = pos[0];
	Flash[1] = pos[1];
	Flash[2] = pos[2];
	
	Collumn[0] = pos[0];
	Collumn[1] = pos[1];
	Collumn[2] = pos[2];
	
	pos[2] += 6.0;
	Flash[2] += 236.0;
	Collumn[2] += 1652.0;


	ShowParticle(pos, "base_destroyed_smoke_doomsday", 30.0);
	ShowParticle(Flash, "flash_doomsday", 10.0);
	ShowParticle(Collumn, "dooms_nuke_collumn", 30.0);*/

	int shaker = CreateEntityByName("env_shake");
	if(shaker != -1)
	{
		DispatchKeyValue(shaker, "amplitude", "50");
		DispatchKeyValue(shaker, "radius", "8000");
		DispatchKeyValue(shaker, "duration", "4");
		DispatchKeyValue(shaker, "frequency", "50");
		DispatchKeyValue(shaker, "spawnflags", "4");

		TeleportEntity(shaker, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(shaker, "StartShake");
		DispatchSpawn(shaker);
		
		CreateTimer(10.0, Timer_Delete, EntIndexToEntRef(shaker)); 
	}
	
	int iBomb = CreateEntityByName("tf_generic_bomb");
	DispatchKeyValueVector(iBomb, "origin", pos);
	DispatchKeyValueFloat(iBomb, "damage", 999999.0);
	//DispatchKeyValueFloat(iBomb, "radius", 1200.0);
	DispatchKeyValueFloat(iBomb, "radius", 500.0);
	DispatchKeyValue(iBomb, "health", "1");
	SetEntPropEnt(iBomb, Prop_Send, "m_hOwnerEntity", GetEntPropEnt(caller, Prop_Send, "m_hOwnerEntity"));
	DispatchSpawn(iBomb);

	AcceptEntityInput(iBomb, "Detonate");
	
	AcceptEntityInput(caller, "Kill");
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(IsValidEntity(attacker))
	{
		new iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "tf_generic_bomb")) != -1) 
		{
			if (iEnt == attacker)
			{
				if(GetClientTeam(GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity")) == GetClientTeam(client))
				{
					return Plugin_Handled;
				}else{
					Event event = CreateEvent("player_death");
					if (event != INVALID_HANDLE)
					{ 
						event.SetInt("userid", GetClientUserId(client));
						event.SetInt("attacker", GetClientUserId(attacker));
						event.SetInt("weapon_def_index", 939);
						event.SetString("weapon", "bat_outta_hell");
						event.SetString("weapon_logclassname", "bat_outta_hell");
						event.Fire(false);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}


stock int CreateParticle(int iEntity, char[] sParticle, bool bAttach = false, float time)
{
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(iParticle))
	{
		float fPosition[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPosition);
		
		TeleportEntity(iParticle, fPosition, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(iParticle, "effect_name", sParticle);
		
		if (bAttach)
		{
			SetVariantString("!activator");
			AcceptEntityInput(iParticle, "SetParent", iEntity, iParticle, 0);			
		}

		DispatchSpawn(iParticle);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");
		CreateTimer(time, DeleteParticle, iParticle)
	}
	return iParticle;
}

public void ShowParticle(float pos[3], char[] particlename, float time)
{
    int particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(particle, "effect_name", particlename);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        CreateTimer(time, DeleteParticles, EntIndexToEntRef(particle));
    }
}

public Action DeleteParticles(Handle timer, any particle)
{
	int ent = EntRefToEntIndex(particle);

	if (ent != INVALID_ENT_REFERENCE)
	{
		char classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
			AcceptEntityInput(ent, "kill");
	}
}

public Action Timer_Delete(Handle hTimer, any iRefEnt) 
{ 
	int iEntity = EntRefToEntIndex(iRefEnt); 
	if(iEntity > MaxClients) 
	{
		AcceptEntityInput(iEntity, "Kill"); 
		AcceptEntityInput(iEntity, "StopShake");
	}
	 
	return Plugin_Handled; 
}

public Action DeleteParticle(Handle timer, any particle)
{
	if (IsValidEntity(particle))
	{
		char classN[64];
		GetEdictClassname(particle, classN, sizeof(classN));
		if (StrEqual(classN, "info_particle_system", false))
		{
			RemoveEdict(particle);
		}
	}
}
stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}