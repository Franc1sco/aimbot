/****************************************************************************************************
	AIMBOT
*****************************************************************************************************
Credits: 
		Franc1sco franug 
						http://steamcommunity.com/id/franug
						Intial plugin / idea / improvements.
		
		SM9();  			
						http://steamcommunity.com/id/sm91337/
						Rewrite / improvements.
					
****************************************************************************************************
CHANGELOG
****************************************************************************************************
	1.0 ~ 
		- First release.
	1.0.1 ~ 
		- Added public cvar.
	1.1 ~
		- Added support for giving aimbot to other players.
	1.2 / 1.3 ~ 
		- Improvements to aimbot.
		- Improvements to CSGO NoRecoil.
	1.4 ~ 
		- Cleaned & rewrote plugin in new Syntax.
		- Much improved NoRecoil for CSGO.
		- Added NoSpread (Not pefect)
		- Send ConVars to client to improve prediction.
	1.4.1 ~ 
		- Fixed incompatbility issue with some games.
	1.5 ~
		- Added Cvar sm_aimbot_everyone (0/1)
					When this Cvar is on, aimbot is auto toggled on everyone including players that join the server.		
		- Added Cvar sm_aimbot_autoaim
					When this Cvar is on the aimbot will auto aim but not auto-fire, this feature will come later.
		- Improved aimbot toggling.
					New usage: sm_aimbot <Player> <0/1> or sm_aimbot will enable for you only.	
		- Fixed Error spam on Weapon_Fire.
		- Further improved clientside prediction for much better No Spread!
		- Protection to prevent SMAC bans.
		- Improved aimbot accuracy slightly.
	1.6 ~
		- Credits to Zipcore + Addicted
		- Added Cvar sm_aimbot_fov (20.0)
					Will only activate aimbot if target is within this fov of client
	 	- Added Cvar sm_aimbot_distance (8000.0)
	 				Will only activate aimbot if target is within this distance of client
	 	- Added Cvar sm_aimbot_flashed (1)
	 				Block aimbot when player is flashed
	 				
	1.7 ~
		- Credits to Poheart
		- Added Cvar sm_aimbot_norecoil (0/1/2)
					Allow which recoil control mode the aimbot should be used.
					0 = Disable recoil control
					1 = Server recoil remove
					2 = Auto-Spray control (Recoil Control System)

****************************************************************************************************
Planned: 
****************************************************************************************************
- Add auto shoot feature.
- Improve No Spread / No Recoil  / Client prediction further.
- Maybe add Wallhack?.
- Suggestions?

****************************************************************************************************
INCLUDES
***************************************************************************************************/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Protection for SMAC users.
#undef REQUIRE_PLUGIN
#tryinclude <smac>

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
bool g_bAimbotFlashed = true;
bool g_bFlashed[MAXPLAYERS + 1] = false;
/****************************************************************************************************
INTEGERS.
*****************************************************************************************************/
int g_iRecoilMode = 1;
/****************************************************************************************************
FLOATS.
*****************************************************************************************************/
float g_fMaxAimFov = 0.0;
float g_fMaxAimDistance = 0.0;

/****************************************************************************************************
CONVARS.
*****************************************************************************************************/
Handle g_hPredictionConVars[9] = null;
Handle g_hCvarAimbotEveryone = null;
Handle g_hCvarAimbotAutoAim = null;
Handle g_hCvarFov = null;
Handle g_hCvarDistance = null;
Handle g_hCvarFlashbang = null;
Handle g_hCvarRecoilMode = null;

#define VERSION "1.7"
#define LoopValidClients(%1) for(int %1 = 1; %1 < MaxClients; %1++) if(IsClientValid(%1))

public Plugin myinfo = 
{
	name = "SM Aimbot", 
	author = "Franc1sco franug, SM9", 
	description = "Give you a legal aimbot made by sourcemod", 
	version = VERSION, 
	url = "https://github.com/Franc1sco/aimbot"
};

public void OnPluginStart()
{
	CreateConVar("sm_aimbot_version", VERSION, "", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	HookConVarChange(g_hCvarAimbotEveryone = CreateConVar("sm_aimbot_everyone", "0", "Aimbot everyone"), OnCvarChanged);
	HookConVarChange(g_hCvarAimbotAutoAim = CreateConVar("sm_aimbot_autoaim", "1", "Aimbot auto aim"), OnCvarChanged);
	HookConVarChange(g_hCvarRecoilMode = CreateConVar("sm_aimbot_norecoil", "1", "Aimbot recoil control - 0 = disable, 1 = remove recoil, 2 = recoil control system"), OnCvarChanged);
	HookConVarChange(g_hCvarFov = CreateConVar("sm_aimbot_fov", "20.0", "Will only activate aimbot if target is within this fov of client (1.0 to disable)"), OnCvarChanged);
	HookConVarChange(g_hCvarDistance = CreateConVar("sm_aimbot_distance", "8000.0", "Will only activate aimbot if target is within this distance of client (1.0 to disable)"), OnCvarChanged);
	HookConVarChange(g_hCvarFlashbang = CreateConVar("sm_aimbot_flashed", "1", "Block aimbot when player is flashed"), OnCvarChanged);
	
	g_fMaxAimFov = GetConVarFloat(g_hCvarFov);
	g_fMaxAimDistance = GetConVarFloat(g_hCvarDistance);
	g_bAimbotFlashed = GetConVarBool(g_hCvarFlashbang);
	
	HookEventEx("weapon_fire", Event_WeaponFire, EventHookMode_Pre);
	HookEventEx("player_blind", Event_PlayerBlind, EventHookMode_Pre);
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
	} else if (hConvar == g_hCvarFov) {
		g_fMaxAimFov = GetConVarFloat(g_hCvarFov);
	} else if (hConvar == g_hCvarDistance) {
		g_fMaxAimDistance = GetConVarFloat(g_hCvarDistance);
	} else if (hConvar == g_hCvarFlashbang) {
		g_bAimbotFlashed = GetConVarBool(g_hCvarFlashbang);
	} else if (hConvar == g_hCvarRecoilMode) {
		g_iRecoilMode = GetConVarInt(g_hCvarRecoilMode);
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
			
			if (iClient != iClient2) {
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
	
	if (iTarget > 0) {
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
		if (g_iRecoilMode == 1) {
			SetEntPropVector(iClient, Prop_Send, "m_aimPunchAngle", NULL_VECTOR);
			SetEntPropVector(iClient, Prop_Send, "m_aimPunchAngleVel", NULL_VECTOR);
			SetEntPropVector(iClient, Prop_Send, "m_viewPunchAngle", NULL_VECTOR);
		}
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
	
	
	//Recoil Control System
	if (g_iRecoilMode == 2) {
		float vecPunchAngle[3];
		GetEntPropVector(iClient, Prop_Send, "m_aimPunchAngle", vecPunchAngle);
		fFinalPos[0] -= vecPunchAngle[0] * GetConVarFloat(g_hPredictionConVars[5]);
		fFinalPos[1] -= vecPunchAngle[1] * GetConVarFloat(g_hPredictionConVars[5]);
	}
	
	
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
		
		if (GetEntPropFloat(i, Prop_Send, "m_fImmuneToGunGameDamageTime") > 0.0) {
			continue;
		}
		
		if (g_fMaxAimDistance != 0.0 && fTargetDistance > g_fMaxAimDistance) {
			continue;
		}
		
		if (g_fMaxAimFov != 0.0 && !IsTargetInSightRange(iClient, i, g_fMaxAimFov, g_fMaxAimDistance)) {
			continue;
		}
		
		if (g_bAimbotFlashed && g_bFlashed[iClient]) {
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

#if defined _smac_included
public Action SMAC_OnCheatDetected(int iClient, const char[] chModule, DetectionType dType)
{
	if (!g_bAimbot[iClient]) {
		return Plugin_Continue;
	}
	
	if (dType == Detection_Aimbot || dType == Detection_Eyeangles) {
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
#endif

stock bool IsClientValid(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients) {
		return false;
	}
	
	return IsClientInGame(iClient);
}

stock bool IsTargetInSightRange(int client, int target, float angle = 90.0, float distance = 0.0, bool heightcheck = true, bool negativeangle = false)
{
	if (angle > 360.0)
		angle = 360.0;
	
	if (angle < 0.0)
		return false;
	
	float clientpos[3];
	float targetpos[3];
	float anglevector[3];
	float targetvector[3];
	float resultangle;
	float resultdistance;
	
	GetClientEyeAngles(client, anglevector);
	anglevector[0] = anglevector[2] = 0.0;
	GetAngleVectors(anglevector, anglevector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(anglevector, anglevector);
	if (negativeangle)
		NegateVector(anglevector);
	
	GetClientAbsOrigin(client, clientpos);
	GetClientAbsOrigin(target, targetpos);
	
	if (heightcheck && distance > 0)
		resultdistance = GetVectorDistance(clientpos, targetpos);
	
	clientpos[2] = targetpos[2] = 0.0;
	MakeVectorFromPoints(clientpos, targetpos, targetvector);
	NormalizeVector(targetvector, targetvector);
	
	resultangle = RadToDeg(ArcCosine(GetVectorDotProduct(targetvector, anglevector)));
	
	if (resultangle <= angle / 2)
	{
		if (distance > 0)
		{
			if (!heightcheck)
				resultdistance = GetVectorDistance(clientpos, targetpos);
			
			if (distance >= resultdistance)
				return true;
			else return false;
		}
		else return true;
	}
	
	return false;
}

public Action Event_PlayerBlind(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha") >= 180.0)
	{
		float duration = GetEntPropFloat(client, Prop_Send, "m_flFlashDuration");
		if (duration >= 1.5)
		{
			g_bFlashed[client] = true;
			CreateTimer(duration, UnFlashed_Timer, client);
		}
	}
}

public Action UnFlashed_Timer(Handle timer, int client)
{
	g_bFlashed[client] = false;
} 
