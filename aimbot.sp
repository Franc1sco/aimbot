#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new bool:aimbot[MAXPLAYERS+1];

new bool:csgo;

#define DATA "1.2"

public Plugin:myinfo =
{
	name = "SM Aimbot",
	author = "Franc1sco franug",
	description = "Give you a legal aimbot made by sourcemod",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	CreateConVar("sm_aimbot_version", DATA, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	HookEvent("weapon_fire", EventWeaponFire, EventHookMode_Pre);
	
	RegAdminCmd("sm_aimbot", aimbotcmd, ADMFLAG_ROOT);
	
	if(GetEngineVersion() == Engine_CSGO) csgo = true;
	else csgo = false;
	
	
	for (new client = 1; client <= MaxClients; client++) 
        if (IsClientInGame(client))
				OnClientPutInServer(client);
			
}

public OnClientPutInServer(client)
{
	aimbot[client] = false;
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public Action:aimbotcmd(client, args)
{
	if(args < 1)
	{
		if(!aimbot[client]) aimbot[client] = true;
		else aimbot[client] = false;
	
		ReplyToCommand(client, "AIMBOT %s on you", aimbot[client] ? "ENABLED":"DISABLED");
	}
	else
	{
	
		decl String:strTarget[32]; GetCmdArg(1, strTarget, sizeof(strTarget)); 
	
		// Process the targets 
		decl String:strTargetName[MAX_TARGET_LENGTH]; 
		decl TargetList[MAXPLAYERS], TargetCount; 
		decl bool:TargetTranslate; 
	
		if ((TargetCount = ProcessTargetString(strTarget, 0, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
					strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
		{ 
			ReplyToCommand(client, "Target not found");
			return Plugin_Handled; 
		} 
	
		// Apply to all targets 
		for (new i = 0; i < TargetCount; i++) 
		{ 
			new iClient = TargetList[i]; 
			if (IsClientInGame(iClient)) 
			{ 
				if(!aimbot[iClient]) aimbot[iClient] = true;
				else aimbot[iClient] = false;
				
				ReplyToCommand(client, " AIMBOT %s on %N", aimbot[iClient] ? "ENABLED":"DISABLED",iClient);
			} 
		}   
	}
	return Plugin_Handled;
}

public Action:EventWeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!aimbot[client]) return;
	
	new objetivo = GetClosestClient(client);
	if(objetivo > 0)
		LookAtClient(client, objetivo);
}

public OnPostThinkPost(client)
{
	if(!aimbot[client]) return;
	
	new ActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if (!IsValidEdict(ActiveWeapon) || (ActiveWeapon == -1))
	{
		return;
	}
	
	new Float:NoRecoil[3];
	if(!csgo)
	{
		SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", NoRecoil);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
		SetEntPropVector(client, Prop_Send, "m_viewPunchAngle", NoRecoil);
		SetEntPropVector(client, Prop_Send, "m_aimPunchAngle", NoRecoil);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3])
{
	if(!IsClientInGame(client) || !aimbot[client] || !IsPlayerAlive(client)) return;
	
	if(buttons & IN_ATTACK)
	{
	
		new objetivo = GetClosestClient(client);
		if(objetivo > 0)
			LookAtClient(client, objetivo);
	}
}

stock LookAtClient(client, target)
{
	new Float:TargetPos[3], Float:TargetAngles[3], Float:ClientPos[3], Float:Result[3], Float:Final[3];

	GetClientEyePosition(client, ClientPos);
	GetClientEyePosition(target, TargetPos);
	
	GetClientEyeAngles(target, TargetAngles);
    
	decl Float:vecFinal[3];
	AddInFrontOf(TargetPos, TargetAngles, 8.0, vecFinal);

	MakeVectorFromPoints(ClientPos, vecFinal, Result);
	GetVectorAngles(Result, Result);
    
	Final[0] = Result[0];
	Final[1] = Result[1];
	Final[2] = Result[2];
    
	TeleportEntity(client, NULL_VECTOR, Final, NULL_VECTOR);
}

AddInFrontOf(Float:vecOrigin[3], Float:vecAngle[3], Float:units, Float:output[3])
{
    new Float:vecView[3];
    GetViewVector(vecAngle, vecView);

    output[0] = vecView[0] * units + vecOrigin[0];
    output[1] = vecView[1] * units + vecOrigin[1];
    output[2] = vecView[2] * units + vecOrigin[2];
}
 
GetViewVector(Float:vecAngle[3], Float:output[3])
{
    output[0] = Cosine(vecAngle[1] / (180 / FLOAT_PI));
    output[1] = Sine(vecAngle[1] / (180 / FLOAT_PI));
    output[2] = -Sine(vecAngle[0] / (180 / FLOAT_PI));
}

/* stock LookAtClient(any:client, any:target){ 

 	//new weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	//if (weapon != -1 && IsValidEntity(weapon))
	//{
	//	SetEntPropFloat(weapon, Prop_Send, "m_fAccuracyPenalty", 0.0);
	//} 
	//new Float:NoRecoil[3];
	//SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
	//SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", NoRecoil);
	//SetEntPropVector(client, Prop_Send, "m_viewPunchAngle", NoRecoil);
	//SetEntPropVector(client, Prop_Send, "m_aimPunchAngle", NoRecoil);

	
    new Float:angles[3], Float:clientEyes[3], Float:targetEyes[3], Float:resultant[3]; 
    GetClientEyePosition(client, clientEyes); 
    GetClientEyePosition(target, targetEyes); 
    MakeVectorFromPoints(targetEyes, clientEyes, resultant); 
    GetVectorAngles(resultant, angles); 
    if(angles[0] >= 270){ 
        angles[0] -= 270; 
        angles[0] = (90-angles[0]); 
    }else{ 
        if(angles[0] <= 90){ 
            angles[0] *= -1; 
        } 
    } 
    angles[1] -= 180; 
    TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR); 
} */

stock GetClosestClient(iClient)
{
	decl Float:fClientLocation[3];
	GetClientAbsOrigin(iClient, fClientLocation);
	decl Float:fEntityOrigin[3];

	new clientteam = GetClientTeam(iClient);
	new iClosestEntity = -1;
	new Float:fClosestDistance = -1.0;
	new Float:fEntityDistance;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) != clientteam && IsPlayerAlive(i) && i != iClient)
		{
			GetClientAbsOrigin(i, fEntityOrigin);
			fEntityDistance = GetVectorDistance(fClientLocation, fEntityOrigin);
			if((fEntityDistance < fClosestDistance) || fClosestDistance == -1.0)
			{
				if(PuedeVerAlOtro(iClient, i))
				{
					fClosestDistance = fEntityDistance;
					iClosestEntity = i;
				}
			}
		}
	}
	return iClosestEntity;
}

stock bool:PuedeVerAlOtro(visionario, es_visto, Float:distancia = 0.0, Float:altura_visionario = 50.0)
{

		new Float:vMonsterPosition[3], Float:vTargetPosition[3];
		
		GetEntPropVector(visionario, Prop_Send, "m_vecOrigin", vMonsterPosition);
		vMonsterPosition[2] += altura_visionario;
		
		GetClientEyePosition(es_visto, vTargetPosition);
		
		if (distancia == 0.0 || GetVectorDistance(vMonsterPosition, vTargetPosition, false) < distancia)
		{
			new Handle:trace = TR_TraceRayFilterEx(vMonsterPosition, vTargetPosition, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter);

			if(TR_DidHit(trace))
			{
				CloseHandle(trace);
				return (false);
			}
			
			CloseHandle(trace);

			return (true);
		}
		return false;
}

public bool:Base_TraceFilter(entity, contentsMask, any:data)
{
	if(entity != data)
		return (false);

	return (true);
}