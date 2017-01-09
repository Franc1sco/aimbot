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
	1.7.1 ~
		- Improved No Recoil when sm_aimbot_norecoil 1 (No more screen shaking)
		- Prevent trying to send ConVars to Fake clients (Should fix some errors)
		- Only send recoil convars if sm_aimbot_norecoil 1 otherwise let RCS do its magic.
		- Removed sending a ConVar which does not work.
	
	1.7.2 ~
		- Improved support for other games.
		- Improved ConVar change hooks.
		- Improved No recoil on other games (Maybe)
	1.7.3 ~
		- Fix error on TF2 related to a netprop not existing.
		- Further improve support on games other than CSGO.
		

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
bool g_bFlashed[MAXPLAYERS + 1] = false;
/****************************************************************************************************
INTEGERS.
*****************************************************************************************************/
int g_iRecoilMode = 1;
EngineVersion g_iEngineVersion = Engine_Unknown;

/****************************************************************************************************
CONVARS.
*****************************************************************************************************/
ConVar g_cvPredictionConVars[9] = {null, ...};
ConVar g_cvCvarAimbotEveryone = null;
ConVar g_cvCvarAimbotAutoAim = null;
ConVar g_cvCvarFov = null;
ConVar g_cvCvarDistance = null;
ConVar g_cvCvarFlashbang = null;
ConVar g_cvCvarRecoilMode = null;

#define VERSION "1.7.3"

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
	CreateConVar("sm_aimbot_version", VERSION, "", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	g_cvCvarAimbotEveryone = CreateConVar("sm_aimbot_everyone", "0", "Aimbot everyone");
	g_cvCvarAimbotAutoAim = CreateConVar("sm_aimbot_autoaim", "1", "Aimbot auto aim");
	g_cvCvarRecoilMode = CreateConVar("sm_aimbot_norecoil", "1", "Aimbot recoil control - 0 = disable, 1 = remove recoil, 2 = recoil control system");
	g_cvCvarFov = CreateConVar("sm_aimbot_fov", "20.0", "Will only activate aimbot if target is within this fov of client (1.0 to disable)");
	g_cvCvarDistance = CreateConVar("sm_aimbot_distance", "8000.0", "Will only activate aimbot if target is within this distance of client (1.0 to disable)");
	g_cvCvarFlashbang = CreateConVar("sm_aimbot_flashed", "1", "Block aimbot when player is flashed");
	
	HookEventEx("weapon_fire", Event_WeaponFire, EventHookMode_Pre);
	HookEventEx("player_blind", Event_PlayerBlind, EventHookMode_Pre);
	
	RegAdminCmd("sm_aimbot", Cmd_Aimbot, ADMFLAG_CHEATS);
	
	g_cvPredictionConVars[0] = FindConVar("weapon_accuracy_nospread");
	g_cvPredictionConVars[1] = FindConVar("weapon_recoil_cooldown");
	g_cvPredictionConVars[2] = FindConVar("weapon_recoil_decay1_exp");
	g_cvPredictionConVars[3] = FindConVar("weapon_recoil_decay2_exp");
	g_cvPredictionConVars[4] = FindConVar("weapon_recoil_decay2_lin");
	g_cvPredictionConVars[5] = FindConVar("weapon_recoil_scale");
	g_cvPredictionConVars[6] = FindConVar("weapon_recoil_suppression_shots");
	g_cvPredictionConVars[7] = FindConVar("weapon_recoil_variance");
	g_cvPredictionConVars[8] = FindConVar("weapon_recoil_view_punch_extra");
	
	OnConfigsExecuted();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
	
	g_iEngineVersion = GetEngineVersion();
}


public void OnConfigsExecuted() {
	AutoExecConfig();
}


public void OnClientPostAdminCheck(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, OnClientThink);
	SDKHook(iClient, SDKHook_PreThinkPost, OnClientThink);
	SDKHook(iClient, SDKHook_PostThink, OnClientThink);
	SDKHook(iClient, SDKHook_PostThinkPost, OnClientThink);
	
	ToggleAim(iClient, g_cvCvarAimbotEveryone.BoolValue);
}

public void OnClientDisconnect(int iClient) {
	ToggleAim(iClient, g_cvCvarAimbotEveryone.BoolValue);
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
		
		bool bEnable = view_as<bool>(iEnable);
		
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
			
			if (!IsValidClient(iClient2)) {
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
	
	// Ignore bots or clients that are not ingame from here.
	if (IsFakeClient(iClient) || !IsClientInGame(iClient)) {
		return;
	}
	
	// Print client message.
	PrintToChat(iClient, "[SM] Aimbot has been %s for you.", g_bAimbot[iClient] ? "Enabled":"Disabled");
	
	// Fix some prediction issues.
	char chValues[10];
	
	if (g_cvPredictionConVars[0] != null) {
		IntToString(((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1)) ? 1 : g_cvPredictionConVars[0].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[0], chValues);
	}
	
	if (g_cvPredictionConVars[1] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 0 : g_cvPredictionConVars[1].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[1], chValues);
	}
	
	if (g_cvPredictionConVars[2] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 99999 : g_cvPredictionConVars[2].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[2], chValues);
	}
	
	if (g_cvPredictionConVars[3] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 99999 : g_cvPredictionConVars[3].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[3], chValues);
	}
	
	if (g_cvPredictionConVars[4] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 99999 : g_cvPredictionConVars[4].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[4], chValues);
	}
	
	if (g_cvPredictionConVars[5] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 0 : g_cvPredictionConVars[5].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[5], chValues);
	}
	
	if (g_cvPredictionConVars[6] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 500 : g_cvPredictionConVars[6].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[6], chValues);
	}
	
	if (g_cvPredictionConVars[7] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 0 : g_cvPredictionConVars[7].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[7], chValues);
	}
	
	if (g_cvPredictionConVars[8] != null) {
		IntToString((g_bAimbot[iClient] && g_cvCvarRecoilMode.IntValue == 1) ? 0 : g_cvPredictionConVars[8].IntValue, chValues, 10);
		SendConVarValue(iClient, g_cvPredictionConVars[8], chValues);
	}
}

public Action Event_WeaponFire(Event hEvent, const char[] chName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if (!g_bAimbot[iClient])
	{
		return Plugin_Continue;
	}
	
	int iTarget = GetClosestClient(iClient);
	
	if (iTarget > 0)
	{
		LookAtClient(iClient, iTarget);
	}
	
	return Plugin_Continue;
}

public void OnClientThink(int iClient)
{
	if (!g_bAimbot[iClient] || !IsPlayerAlive(iClient))
	{
		return;
	}
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if (!IsValidEdict(iActiveWeapon) || iActiveWeapon == -1) 
	{
		return;
	}
	
	// Not sure which Props exist in other games.
	if (g_iEngineVersion == Engine_CSGO || g_iEngineVersion == Engine_CSS)
	{
		
		// No Spread Addition
		SetEntPropFloat(iActiveWeapon, Prop_Send, "m_fAccuracyPenalty", 0.0);
		
		if (g_iRecoilMode == 1) {
			SetEntPropVector(iClient, Prop_Send, "m_aimPunchAngle", NULL_VECTOR);
			SetEntPropVector(iClient, Prop_Send, "m_aimPunchAngleVel", NULL_VECTOR);
			SetEntPropVector(iClient, Prop_Send, "m_viewPunchAngle", NULL_VECTOR);
		}
	}
	else
	{
		SetEntPropVector(iClient, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
		SetEntPropVector(iClient, Prop_Send, "m_vecPunchAngleVel", NULL_VECTOR);
	}
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAngles[3], int &iWeapon, int &iSubType, int &iCmdNum, int &iTickCount, int &iSeed)
{
	if (!IsValidClient(iClient) || !g_bAimbot[iClient] || !IsPlayerAlive(iClient))
	{
		return Plugin_Continue;
	}
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if (!IsValidEdict(iActiveWeapon) || iActiveWeapon == -1)
	{
		return Plugin_Continue;
	}
	
	if (iButtons & IN_ATTACK || g_cvCvarAimbotAutoAim.BoolValue)
	{
		int iTarget = GetClosestClient(iClient);
		int iClipAmmo = GetEntProp(iActiveWeapon, Prop_Send, "m_iClip1");
		
		if (iClipAmmo > 0 && iTarget > 0) {
			LookAtClient(iClient, iTarget);
		}
	}
	
	// No Spread Addition
	iSeed = 0;
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
	if (g_iRecoilMode == 2)
	{
		float vecPunchAngle[3];
		
		if (g_iEngineVersion == Engine_CSGO || g_iEngineVersion == Engine_CSS) {
			GetEntPropVector(iClient, Prop_Send, "m_aimPunchAngle", vecPunchAngle);
		}
		else
		{
			GetEntPropVector(iClient, Prop_Send, "m_vecPunchAngle", vecPunchAngle);
		}
		
		if(g_cvPredictionConVars[5] != null) {
			fFinalPos[0] -= vecPunchAngle[0] * GetConVarFloat(g_cvPredictionConVars[5]);
			fFinalPos[1] -= vecPunchAngle[1] * GetConVarFloat(g_cvPredictionConVars[5]);
		}
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
	float fClientOrigin[3], fTargetOrigin[3];
	
	GetClientAbsOrigin(iClient, fClientOrigin);
	
	int iClientTeam = GetClientTeam(iClient);
	int iClosestTarget = -1;
	
	float fClosestDistance = -1.0;
	float fTargetDistance;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (iClient == i || GetClientTeam(i) == iClientTeam || !IsPlayerAlive(i))
			{
				continue;
			}
			
			GetClientAbsOrigin(i, fTargetOrigin);
			fTargetDistance = GetVectorDistance(fClientOrigin, fTargetOrigin);
			
			if (fTargetDistance > fClosestDistance && fClosestDistance > -1.0)
			{
				continue;
			}
			
			if (!ClientCanSeeTarget(iClient, i))
			{
				continue;
			}
			
			if (g_iEngineVersion == Engine_CSGO)
			{
				if (GetEntPropFloat(i, Prop_Send, "m_fImmuneToGunGameDamageTime") > 0.0)
				{
					continue;
				}
			}
			
			if (g_cvCvarDistance.FloatValue != 0.0 && fTargetDistance > g_cvCvarDistance.FloatValue)
			{
				continue;
			}
			
			if (g_cvCvarFov.FloatValue != 0.0 && !IsTargetInSightRange(iClient, i, g_cvCvarFov.FloatValue, g_cvCvarDistance.FloatValue))
			{
				continue;
			}
			
			if (g_cvCvarFlashbang.BoolValue && g_bFlashed[iClient])
			{
				continue;
			}
			
			fClosestDistance = fTargetDistance;
			iClosestTarget = i;
		}
	}
	
	return iClosestTarget;
}

stock bool ClientCanSeeTarget(int iClient, int iTarget, float fDistance = 0.0, float fHeight = 50.0)
{
	float fClientPosition[3]; float fTargetPosition[3];
	
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", fClientPosition);
	fClientPosition[2] += fHeight;
	
	GetClientEyePosition(iTarget, fTargetPosition);
	
	if (fDistance == 0.0 || GetVectorDistance(fClientPosition, fTargetPosition, false) < fDistance)
	{
		Handle hTrace = TR_TraceRayFilterEx(fClientPosition, fTargetPosition, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter);
		
		if (TR_DidHit(hTrace))
		{
			delete hTrace;
			return false;
		}
		
		delete hTrace;
		return true;
	}
	
	return false;
}

public bool Base_TraceFilter(int iEntity, int iContentsMask, int iData)
{
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

stock bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
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
