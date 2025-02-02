#include <sourcemod>
#include <cstrike>
#include <connect>

#undef REQUIRE_PLUGIN
#include <AFKManager>
#tryinclude <EntWatch>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

bool g_Plugin_AFKManager;
bool g_Plugin_entWatch;
bool g_Plugin_Events;

ConVar g_cvEventEnabled;

int g_Client_Reservation[MAXPLAYERS + 1] = {0, ...};

public Plugin myinfo =
{
	name = "Reserved Slot",
	author = "BotoX, .Rushaway",
	description = "Provides extended reserved slots",
	version = "1.2.4",
	url = ""
};

public void OnPluginStart()
{
	/* Late load */
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && IsClientAuthorized(client))
			OnClientPostAdminCheck(client);
	}
}

public void OnAllPluginsLoaded()
{
	g_Plugin_AFKManager = LibraryExists("AFKManager");
	g_Plugin_entWatch = LibraryExists("EntWatch");
	g_Plugin_Events = LibraryExists("Events");

	LogMessage("ReservedSlots capabilities:\nAFKManager: %s \nEntWatch: %s \nEvents: %s",
		(g_Plugin_AFKManager ? "loaded" : "not loaded"),
		(g_Plugin_entWatch ? "loaded" : "not loaded"),
		(g_Plugin_Events ? "loaded" : "not loaded"));
}

public void OnConfigsExecuted()
{
	if (g_Plugin_Events)
	{
		g_cvEventEnabled = FindConVar("sm_events_enable");
		if (g_cvEventEnabled == null)
			g_Plugin_Events = false;
	}
}

public void OnClientPostAdminCheck(int client)
{
	AdminId admin = GetUserAdmin(client);
	if(admin == INVALID_ADMIN_ID)
		return;

	if(GetAdminFlag(admin, Admin_Reservation))
	{
		g_Client_Reservation[client] = GetAdminImmunityLevel(admin);
		if(!g_Client_Reservation[client])
			g_Client_Reservation[client] = 1;
	}
}

public void OnClientDisconnect(int client)
{
	g_Client_Reservation[client] = 0;
}

public bool OnClientPreConnectEx(const char[] sName, char sPassword[255], const char[] sIP, const char[] sSteam32ID, char sRejectReason[255])
{
	if(GetClientCount(false) < MaxClients)
		return true;

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteam32ID);
	int Immunity = 0;

	if(admin != INVALID_ADMIN_ID && GetAdminFlag(admin, Admin_Reservation))
	{
		Immunity = GetAdminImmunityLevel(admin);

		if(!KickValidClient(sName, sSteam32ID, admin, Immunity))
		{
			Format(sRejectReason, sizeof(sRejectReason), "No reserved slot available yet, sorry.");
			return false;
		}
		return true;
	}

	return true;
}

stock bool KickValidClient(const char[] sName, const char[] sSteam32ID, AdminId admin, int Immunity)
{
	int HighestValue[4] = {0, ...};
	int HighestValueClient[4] = {0, ...};
	
	bool bAFKManager_Native = GetFeatureStatus(FeatureType_Native, "GetClientIdleTime") == FeatureStatus_Available;
	bool bEntWatch_Native = GetFeatureStatus(FeatureType_Native, "EntWatch_HasSpecialItem") == FeatureStatus_Available;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client))
			continue;

		int flags = GetUserFlagBits(client);

		if(flags & ADMFLAG_ROOT)
			continue;

		//  Event is active, don't kick Event Managers
		if(g_Plugin_Events && g_cvEventEnabled.IntValue == 1 && flags & ADMFLAG_CONVARS)
			continue;

		int iTeam = GetClientTeam(client);
		int Donator = g_Client_Reservation[client];
		int ConnectionTime = RoundToNearest(GetClientTime(client));
		int IdleTime;

		if(g_Plugin_AFKManager && bAFKManager_Native)
			IdleTime = GetClientIdleTime(client);
		else // Fall back to highest connection time.
			IdleTime = ConnectionTime;

#if defined _EntWatch_include
		bool HasItem = false;
		if(g_Plugin_entWatch && bEntWatch_Native)
			HasItem = EntWatch_HasSpecialItem(client);
#endif
		/* Spectators
		 * Sort by idle time and also kick donators if IdleTime > 30
		 */
		if(iTeam <= CS_TEAM_SPECTATOR)
		{
			if(!Donator || IdleTime > 30)
			{
				if(IdleTime > HighestValue[0])
				{
					HighestValue[0] = IdleTime;
					HighestValueClient[0] = client;
				}
			}
		}
		/* Spectators */

		/* Dead non-donator with IdleTime > 30
		 * Sort by idle time and don't kick donators.
		 */
		if(!Donator && iTeam > CS_TEAM_SPECTATOR && !IsPlayerAlive(client))
		{
			if(IdleTime > 30 && IdleTime > HighestValue[1])
			{
				HighestValue[1] = IdleTime;
				HighestValueClient[1] = client;
			}
		}
		/* Dead non-donator with IdleTime > 30 */

		/* Alive non-donator with IdleTime > 30
		 * Sort by idle time and don't kick donators and item owners.
		 *
		if(!Donator && IsPlayerAlive(client) && !HasItem)
		{
			if(IdleTime > 30 && IdleTime > HighestValue[2])
			{
				HighestValue[2] = IdleTime;
				HighestValueClient[2] = client;
			}
		}
		* Alive non-donator with IdleTime > 30 */
	}

	// Check if any condition was met in the correct order and perform kick
	for(int i = 0; i < sizeof(HighestValue); i++)
	{
		if(HighestValue[i])
		{
			ExecuteKickValidClient(HighestValueClient[i], sName, sSteam32ID, admin, Immunity);
			return true;
		}
	}

	return false;
}

stock void ExecuteKickValidClient(int client, const char[] sName, const char[] sSteam32ID, AdminId admin, int Immunity)
{
	KickClientEx(client, "Kicked for reserved slot. (%s joined).", sName);
}
