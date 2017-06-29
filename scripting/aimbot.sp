/*  SM Aimbot
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Protection for SMAC users.
#undef REQUIRE_PLUGIN
#include <smac>

/****************************************************************************************************
ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required
#pragma semicolon 1

/****************************************************************************************************
BOOLS.
*****************************************************************************************************/
bool g_bAimbot[MAXPLAYERS + 1] = false;
bool g_bCSGO = false;
bool g_bAimbotEveryone = false;
bool g_bAimbotAutoAim = false;

/****************************************************************************************************
CONVARS.
*****************************************************************************************************/
Handle g_hPredictionConVars[9] = null;
Handle g_hCvarAimbotEveryone = null;
Handle g_hCvarAimbotAutoAim = null;

#define VERSION "1.6"
#define LoopValidClients(%1) for(int %1 = 1; %1 < MaxClients; %1++) if(IsClientValid(%1))

public Plugin myinfo = 
{
	name = "SM Aimbot", 
	author = "Franc1sco franug", 
	description = "Give you a legal aimbot made by sourcemod", 
	version = VERSION, 
	url = "https://github.com/Franc1sco/aimbot"
};

public void OnPluginStart()
{
	CreateConVar("sm_aimbot_version", VERSION, "", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	HookConVarChange(g_hCvarAimbotEveryone = CreateConVar("sm_aimbot_everyone", "0", "Aimbot everyone"), OnCvarChanged);
	HookConVarChange(g_hCvarAimbotAutoAim = CreateConVar("sm_aimbot_autoaim", "1", "Aimbot auto aim"), OnCvarChanged);
	
	HookEventEx("weapon_fire", Event_WeaponFire, EventHookMode_Pre);
	RegAdminCmd("sm_aimbot", Cmd_Aimbot, ADMFLAG_CHEATS);
	
	g_bCSGO = GetEngineVersion() == Engine_CSGO ? true : false;
	
	if (g_bCSGO) {
		g_hPredictionConVars[0] = FindConVar("weapon_accuracy_nospread");
		g_hPredictionConVars[1] = FindConVar("weapon_recoil_cooldown");
		g_hPredictionConVars[2] = FindConVar("weapon_recoil_decay1_exp");
		g_hPredictionConVars[3] = FindConVar("weapon_recoil_decay2_exp");
		g_hPredictionConVars[4] = FindConVar("weapon_recoil_decay2_lin");
		g_hPredictionConVars[5] = FindConVar("weapon_recoil_scale");
		g_hPredictionConVars[6] = FindConVar("weapon_recoil_suppression_shots");
		g_hPredictionConVars[7] = FindConVar("sv_usercmd_custom_random_seed");
	}
	
	OnConfigsExecuted();
	
	LoopValidClients(iClient) {
		OnClientPutInServer(iClient);
	}
	
	g_bAimbotEveryone = GetConVarInt(g_hCvarAimbotEveryone) >= 1;
	g_bAimbotAutoAim = GetConVarInt(g_hCvarAimbotAutoAim) >= 1;
}

public void OnConfigsExecuted() {
	AutoExecConfig();
}

public void OnCvarChanged(Handle hConvar, char[] chOldValue, char[] chNewValue)
{
	if (hConvar == g_hCvarAimbotEveryone) {
		g_bAimbotEveryone = GetConVarInt(g_hCvarAimbotEveryone) >= 1;
		
		LoopValidClients(iClient) {
			ToggleAim(iClient, g_bAimbotEveryone);
		}
	} else if (hConvar == g_hCvarAimbotAutoAim) {
		g_bAimbotAutoAim = GetConVarInt(g_hCvarAimbotAutoAim) >= 1;
	}
}

public void OnClientPutInServer(int iClient) {
	g_bAimbot[iClient] = g_bAimbotEveryone;
	
	SDKHook(iClient, SDKHook_PreThink, OnClientThink);
	SDKHook(iClient, SDKHook_PreThinkPost, OnClientThink);
	SDKHook(iClient, SDKHook_PostThink, OnClientThink);
	SDKHook(iClient, SDKHook_PostThinkPost, OnClientThink);
}

public Action Cmd_Aimbot(int iClient, int iArgs)
{
	if (iArgs < 1) {
		ToggleAim(iClient, g_bAimbot[iClient] ? false:true);
	}
	
	else {
		if (iArgs < 2) {
			ReplyToCommand(iClient, "Usage: sm_aimbot <Player> <0/1>");
			return Plugin_Handled;
		}
		
		char chTarget[32]; GetCmdArg(1, chTarget, sizeof(chTarget));
		char chEnable[10]; GetCmdArg(2, chEnable, sizeof(chEnable));
		
		int iEnable = StringToInt(chEnable);
		
		if (iEnable > 1 || iEnable < 0) {
			ReplyToCommand(iClient, "Usage: sm_aimbot <Player> <0/1>");
			return Plugin_Handled;
		}
		
		bool bEnable = iEnable == 1 ? true:false;
		
		// Process the targets 
		char chTargetName[MAX_TARGET_LENGTH]; int iTargetList[MAXPLAYERS];
		int iTargetCount; bool bTargetTranslate;
		
		if ((iTargetCount = ProcessTargetString(chTarget, 0, iTargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, chTargetName, sizeof(chTargetName), bTargetTranslate)) <= 0) {
			ReplyToCommand(iClient, "Player not found");
			return Plugin_Handled;
		}
		
		// Apply to all targets 
		for (int i = 0; i < iTargetCount; i++) {
			int iClient2 = iTargetList[i];
			
			if (!IsClientValid(iClient2)) {
				continue;
			}
			
			if (bEnable == g_bAimbot[iClient]) {
				continue;
			}
			
			ToggleAim(iClient2, bEnable);
			
			if(iClient != iClient2) {
				ReplyToCommand(iClient, "Aimbot has been %s for %N.", bEnable ? "Enabled":"Disabled", iClient2);
			}
		}
	}
	
	return Plugin_Handled;
}

stock void ToggleAim(int iClient, bool bEnabled = false)
{
	// Toggle aimbot.
	g_bAimbot[iClient] = bEnabled;
	
	// Print client message.
	PrintToChat(iClient, "[SM] Aimbot has been %s for you.", g_bAimbot[iClient] ? "Enabled":"Disabled");
	
	// Fix some prediction issues. (Tested only in CSGO)
	if (!g_bCSGO) {
		return;
	}
	
	char chValues[10];
	IntToString(g_bAimbot[iClient] ? 1:GetConVarInt(g_hPredictionConVars[0]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[0], chValues);
	
	IntToString(g_bAimbot[iClient] ? 0:GetConVarInt(g_hPredictionConVars[1]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[1], chValues);
	
	IntToString(g_bAimbot[iClient] ? 99999:GetConVarInt(g_hPredictionConVars[2]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[2], chValues);
	
	IntToString(g_bAimbot[iClient] ? 99999:GetConVarInt(g_hPredictionConVars[3]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[3], chValues);
	
	IntToString(g_bAimbot[iClient] ? 99999:GetConVarInt(g_hPredictionConVars[4]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[4], chValues);
	
	IntToString(g_bAimbot[iClient] ? 0:GetConVarInt(g_hPredictionConVars[5]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[5], chValues);
	
	IntToString(g_bAimbot[iClient] ? 500:GetConVarInt(g_hPredictionConVars[6]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[6], chValues);
	
	IntToString(g_bAimbot[iClient] ? 0:GetConVarInt(g_hPredictionConVars[7]), chValues, 10);
	SendConVarValue(iClient, g_hPredictionConVars[7], chValues);
}

public Action Event_WeaponFire(Handle hEvent, const char[] chName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (!g_bAimbot[iClient]) {
		return Plugin_Continue;
	}
	
	int iTarget = GetClosestClient(iClient);
	
	if(iTarget > 0) {
		LookAtClient(iClient, iTarget);
	}
	return Plugin_Continue;
}

public void OnClientThink(int iClient)
{
	if (!g_bAimbot[iClient] || !IsPlayerAlive(iClient)) {
		return;
	}
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if (!IsValidEdict(iActiveWeapon) || iActiveWeapon == -1) {
		return;
	}
	
	// NoSpread Addition
	SetEntPropFloat(iActiveWeapon, Prop_Send, "m_fAccuracyPenalty", 0.0);
	
	// Not sure which Props exist in other games.
	if (g_bCSGO) {
		SetEntPropVector(iClient, Prop_Send, "m_aimPunchAngle", NULL_VECTOR);
		SetEntPropVector(iClient, Prop_Send, "m_aimPunchAngleVel", NULL_VECTOR);
		SetEntPropVector(iClient, Prop_Send, "m_viewPunchAngle", NULL_VECTOR);
	} else {
		SetEntPropVector(iClient, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
	}
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAngles[3], int &iWeapon, int &iSubType, int &iCmdNum, int &iTickCount, int &iSeed)
{
	if (!IsClientValid(iClient) || !g_bAimbot[iClient] || !IsPlayerAlive(iClient)) {
		return Plugin_Continue;
	}
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if (!IsValidEdict(iActiveWeapon) || iActiveWeapon == -1) {
		return Plugin_Continue;
	}
	
	if (iButtons & IN_ATTACK || (g_bAimbotAutoAim)) {
		int iTarget = GetClosestClient(iClient);
		int iClipAmmo = GetEntProp(iActiveWeapon, Prop_Send, "m_iClip1");
		
		if (iClipAmmo > 0 && iTarget > 0) {
			LookAtClient(iClient, iTarget);
		}
	}
	
	// NoSpread Addition
	iSeed = -1;
	return Plugin_Changed;
}

stock void LookAtClient(int iClient, int iTarget)
{
	float fTargetPos[3]; float fTargetAngles[3]; float fClientPos[3]; float fFinalPos[3];
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyePosition(iTarget, fTargetPos);
	GetClientEyeAngles(iTarget, fTargetAngles);
	
	float fVecFinal[3];
	AddInFrontOf(fTargetPos, fTargetAngles, 7.0, fVecFinal);
	MakeVectorFromPoints(fClientPos, fVecFinal, fFinalPos);
	
	GetVectorAngles(fFinalPos, fFinalPos);
	TeleportEntity(iClient, NULL_VECTOR, fFinalPos, NULL_VECTOR);
}

stock void AddInFrontOf(float fVecOrigin[3], float fVecAngle[3], float fUnits, float fOutPut[3])
{
	float fVecView[3]; GetViewVector(fVecAngle, fVecView);
	
	fOutPut[0] = fVecView[0] * fUnits + fVecOrigin[0];
	fOutPut[1] = fVecView[1] * fUnits + fVecOrigin[1];
	fOutPut[2] = fVecView[2] * fUnits + fVecOrigin[2];
}

stock void GetViewVector(float fVecAngle[3], float fOutPut[3])
{
	fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

stock int GetClosestClient(int iClient)
{
	float fClientOrigin[3]; float fTargetOrigin[3];
	GetClientAbsOrigin(iClient, fClientOrigin);
	
	int iClientTeam = GetClientTeam(iClient);
	int iClosestTarget = -1;
	
	float fClosestDistance = -1.0;
	float fTargetDistance;
	
	LoopValidClients(i) {
		if (iClient == i || GetClientTeam(i) == iClientTeam || !IsPlayerAlive(i)) {
			continue;
		}
		
		GetClientAbsOrigin(i, fTargetOrigin); fTargetDistance = GetVectorDistance(fClientOrigin, fTargetOrigin);
		
		if (fTargetDistance > fClosestDistance && fClosestDistance > -1.0) {
			continue;
		}
		
		if (!ClientCanSeeTarget(iClient, i)) {
			continue;
		}
		
		fClosestDistance = fTargetDistance;
		iClosestTarget = i;
	}
	
	return iClosestTarget;
}

stock bool ClientCanSeeTarget(int iClient, int iTarget, float fDistance = 0.0, float fHeight = 50.0)
{
	float fClientPosition[3]; float fTargetPosition[3];
	
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", fClientPosition);
	fClientPosition[2] += fHeight;
	
	GetClientEyePosition(iTarget, fTargetPosition);
	
	if (fDistance == 0.0 || GetVectorDistance(fClientPosition, fTargetPosition, false) < fDistance) {
		Handle hTrace = TR_TraceRayFilterEx(fClientPosition, fTargetPosition, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter);
		
		if (TR_DidHit(hTrace)) {
			CloseHandle(hTrace);
			return false;
		}
		
		CloseHandle(hTrace);
		return true;
	}
	
	return false;
}

public bool Base_TraceFilter(int iEntity, int iContentsMask, int iData) {
	return iEntity == iData;
}

public Action SMAC_OnCheatDetected(int iClient, const char[] chModule, DetectionType dType)
{
	if(!g_bAimbot[iClient]) {
		return Plugin_Continue;
	}
	
	if(dType == Detection_Aimbot || dType == Detection_Eyeangles) {
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

stock bool IsClientValid(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients) {
		return false;
	}
	
	return IsClientInGame(iClient);
} 