#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1

#define DEBUG_DETOURS

#define MODEL_PROP_GASCAN	"models/props_junk/gascan001a.mdl"
#define MODEL_PROP_OXYGEN	"models/props_equipment/oxygentank01.mdl"
#define MODEL_PROP_PROPANE	"models/props_junk/propanecanister001a.mdl"
#define MODEL_PROP_FIREWORKS	"models/props_junk/explosive_box001.mdl"

int g_iPropModelIndexes[3];
bool g_bIsHittingCar[MAXPLAYERS + 1];
bool g_bIsAttackingWitch[MAXPLAYERS + 1];
bool g_bIsHitDuringRevive[MAXPLAYERS + 1];

DynamicHook g_DHookIsBot;

ConVar os_gmc_bot_survivor_damage_props;
ConVar os_gmc_bots_spitter_damage_gascans;
ConVar os_gmc_bot_survivor_trigger_car_alarm;
ConVar os_gmc_bot_survivor_startle_witch;
ConVar os_gmc_bot_survivor_damage_spit;
ConVar os_gmc_bot_survivor_reset_revive;
ConVar os_gmc_human_survivor_damage_spit;

public Plugin myinfo = 
{
	name = "[L4D2] Officer Spy Game Mod Changes",
	author = "Officer Spy",
	description = "Game-specific changes for general use.",
	version = "1.0.2",
	url = ""
};

public void OnPluginStart()
{
	os_gmc_bot_survivor_damage_props = CreateConVar("sm_os_gmc_bot_survivor_damage_props", "1", "Let survivor bots damage props.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	os_gmc_bots_spitter_damage_gascans = CreateConVar("sm_os_gmc_bots_spitter_damage_gascans", "1", "Let spitter bots damage gas cans.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	os_gmc_bot_survivor_trigger_car_alarm = CreateConVar("sm_os_gmc_bot_survivor_trigger_car_alarm", "1", "Let survivor bots trigger car alarms.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	os_gmc_bot_survivor_startle_witch = CreateConVar("sm_os_gmc_bot_survivor_startle_witch", "1", "Let survivor bots startle the wandering witch.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	os_gmc_bot_survivor_damage_spit = CreateConVar("sm_os_gmc_bot_survivor_damage_spit", "1.0", "Multiplier for how much damage bots take from spitter acid.", FCVAR_NOTIFY);
	os_gmc_bot_survivor_reset_revive = CreateConVar("sm_os_gmc_bot_survivor_reset_revive", "1", "Force bots to stop reviving players when hit by an infected.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	os_gmc_human_survivor_damage_spit = CreateConVar("sm_os_gmc_human_survivor_damage_spit", "1.0", "Multiplier for how much damage human survivors take from spitter acid.", FCVAR_NOTIFY);
	
	GameData hGamedata = new GameData("l4d2.osgmc");
	
	if (hGamedata == null)
		SetFailState("Could not find gamedata file: l4d2.osgmc!");
	
	int gamedataFails = 0;
	
	if (!DH_RegisterHook(hGamedata, g_DHookIsBot, "CBasePlayer::IsBot"))
	{
		LogError("Failed to setup hook for CBasePlayer::IsBot!"); 
		gamedataFails++;
	}
	
	delete hGamedata;
	
	if (gamedataFails > 0)
		SetFailState("GameData file has %d problems!", gamedataFails);
}

public void OnMapStart()
{
	char propModels[][] = { MODEL_PROP_OXYGEN, MODEL_PROP_PROPANE, MODEL_PROP_FIREWORKS };
	
	for (int i = 0; i < sizeof(g_iPropModelIndexes); i++)
		g_iPropModelIndexes[i] = PrecacheModel(propModels[i]);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Player_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, Player_OnTakeDamageAlive);
	
	if (IsFakeClient(client))
		DHookEntity(g_DHookIsBot, true, client, _, DHookCallback_IsBot_Post);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "weapon_gascan"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, GasCan_OnTakeDamage);
	}
	else if (StrEqual(classname, "physics_prop"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, PropPhysics_OnTakeDamage);
	}
	else if (StrEqual(classname, "prop_car_alarm"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, CarProp_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, CarProp_OnTakeDamagePost);
		SDKHook(entity, SDKHook_TouchPost, CarProp_TouchPost);
	}
	else if (StrEqual(classname, "prop_car_glass")) //Follows same logic
	{
		SDKHook(entity, SDKHook_OnTakeDamage, CarProp_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, CarProp_OnTakeDamagePost);
	}
	else if (StrEqual(classname, "witch"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Witch_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, Witch_OnTakeDamagePost);
	}
}

public Action Player_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (GetClientTeam(victim) == 2)
	{
		if (inflictor > 0)
		{
			char classname[PLATFORM_MAX_PATH]; GetEntityClassname(inflictor, classname, sizeof(classname));
			
			if (StrEqual(classname, "insect_swarm"))
			{
				float multDamage = IsFakeClient(victim) ? os_gmc_bot_survivor_damage_spit.FloatValue : os_gmc_human_survivor_damage_spit.FloatValue;
				
				if (multDamage != 1.0)
				{
					damage *= multDamage;
					return Plugin_Changed;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Player_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (os_gmc_bot_survivor_reset_revive.BoolValue)
	{
		if (IsIncapacitatedSurvivor(victim) && IsValidInfected(attacker))
		{
			int reviver = GetEntPropEnt(victim, Prop_Send, "m_reviveOwner");
			
			if (reviver != -1 && IsFakeClient(reviver))
			{
				g_bIsHitDuringRevive[reviver] = true;
				
				//SDKHook_OnTakeDamageAlivePost will not work here because m_reviveOwner becomes NULL
				//when CTerrorPlayer::StopBeingRevived gets called in CTerrorPlayer::OnTakeDamage_Alive
				//So we'll just reset our variable by a frame later
				RequestFrame(Frame_Player_OnTakeDamageAlive, reviver);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action GasCan_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (os_gmc_bot_survivor_damage_props.BoolValue && IsValidSurvivorBot(attacker))
	{
		//Have the bot only be the inflictor, and the world the attacker
		SDKHooks_TakeDamage(victim, attacker, 0, damage, damagetype, weapon, NULL_VECTOR, damagePosition, true);
		return Plugin_Handled;
	}
	
	if (os_gmc_bots_spitter_damage_gascans.BoolValue && IsValidSpitterBot(attacker))
	{
		//Let spitter bots damage only Scavenge gas cans
		if (GetEntProp(victim, Prop_Data, "m_nSkin") == 1)
		{
			//NOTE: Setting the spitter as the inflictor causes the spit damage sound effect when the gas can's fire inflicts
			//damage to survivors. however, it is still just fire (inferno) damage and stops when the acid is gone
			SDKHooks_TakeDamage(victim, attacker, 0, damage, damagetype, weapon, NULL_VECTOR, damagePosition, true);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action PropPhysics_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (os_gmc_bot_survivor_damage_props.BoolValue && IsValidSurvivorBot(attacker) && IsExplosivePropWeapon(victim))
	{
		//For prop_physics, have the bot's weapon be the actual attacker, as it will show as them doing the damage
		SDKHooks_TakeDamage(victim, attacker, GetActiveWeapon(attacker), damage, damagetype, weapon, NULL_VECTOR, damagePosition, true);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action CarProp_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (os_gmc_bot_survivor_trigger_car_alarm.BoolValue)
	{
		// if (GetEntProp(victim, Prop_Send, "m_bDisabled") == 1)
			// return Plugin_Continue;
		
		if (IsValidSurvivorBot(attacker))
			g_bIsHittingCar[attacker] = true;
	}
	
	return Plugin_Continue;
}

public void CarProp_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (os_gmc_bot_survivor_trigger_car_alarm.BoolValue)
	{
		// if (GetEntProp(victim, Prop_Send, "m_bDisabled") == 1)
			// return;
		
		if (IsValidSurvivorBot(attacker))
			g_bIsHittingCar[attacker] = false;
	}
}

public void CarProp_TouchPost(int entity, int other)
{
	if (os_gmc_bot_survivor_trigger_car_alarm.BoolValue)
	{
		// if (GetEntProp(entity, Prop_Send, "m_bDisabled") == 1)
			// return;
		
		//Detouring around Touch does not work here, so we trigger it manually
		if (IsValidSurvivorBot(other) && GetEntPropEnt(other, Prop_Send, "m_hGroundEntity") == entity)
			TriggerCarAlarm(entity, other);
	}
}

public Action Witch_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (os_gmc_bot_survivor_startle_witch.BoolValue)
	{
		if (GetEntPropFloat(victim, Prop_Send, "m_rage") >= 1.0)
			return Plugin_Continue;
		
		if (IsValidSurvivorBot(attacker))
			g_bIsAttackingWitch[attacker] = true;
	}
	
	return Plugin_Continue;
}

public void Witch_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (os_gmc_bot_survivor_startle_witch.BoolValue)
	{
		if (IsValidSurvivorBot(attacker))
			g_bIsAttackingWitch[attacker] = false;
	}
}

public void Frame_Player_OnTakeDamageAlive(int client)
{
	g_bIsHitDuringRevive[client] = false;
}

public MRESReturn DHookCallback_IsBot_Post(int pThis, DHookReturn hReturn)
{
	if (g_bIsHittingCar[pThis] || g_bIsAttackingWitch[pThis] || g_bIsHitDuringRevive[pThis])
	{
		hReturn.Value = false;
		
#if defined DEBUG_DETOURS
		PrintToChatAll("[DHookCallback_IsBot_Post] return false");
#endif
		
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

bool IsIncapacitatedSurvivor(int client)
{
	return GetClientTeam(client) == 2 && GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1;
}

//Infected player or common infected or witch
bool IsValidInfected(int entity)
{
	if (entity < 1)
		return false;
	
	if (entity <= MaxClients)
		return GetClientTeam(entity) == 3;
	
	char classname[PLATFORM_MAX_PATH]; GetEntityClassname(entity, classname, sizeof(classname));
	
	return StrEqual(classname, "infected") || StrEqual(classname, "witch");
}

bool IsValidSurvivorBot(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	
	//Survivor team only
	if (GetClientTeam(client) != 2)
		return false;
	
	return IsFakeClient(client);
}

bool IsValidSpitterBot(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	
	//Infected team only
	if (GetClientTeam(client) != 3)
		return false;
	
	//Spitter only
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 4)
		return false;
	
	return IsFakeClient(client);
}

//Fireworks, oxygen tank, propane tank
bool IsExplosivePropWeapon(int entity)
{
	//TODO: neither classname nor serverclass name are reliable here, because they change for prop_physics after being dropped by players
	//Find a more reliable way to check these
	
	int modelIndex = GetEntProp(entity, Prop_Data, "m_nModelIndex");
	
	for (int i = 0; i < sizeof(g_iPropModelIndexes); i++)
		if (modelIndex == g_iPropModelIndexes[i])
			return true;
	
	return false;
}

void TriggerCarAlarm(int car, int client)
{
	g_bIsHittingCar[client] = true;
	AcceptEntityInput(car, "SurvivorStandingOnCar", client, client);
	g_bIsHittingCar[client] = false;
}

stock int GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}

stock bool DH_RegisterHook(GameData gd, DynamicHook &hook, const char[] fnName)
{
	hook = DynamicHook.FromConf(gd, fnName);
	
	return hook != null;
}