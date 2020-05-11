/*
 * SourceMod Entity Projects
 * by: Entity
 *
 * Copyright (C) 2020 Kőrösfalvi "Entity" Martin
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

Database DB = null;

public Plugin myinfo = 
{
	name = "[CSGO] MySQL Player information", 
	author = "Entity", 
	description = "Saves player SteamID, Name and IP.", 
	version = "0.1"
};

public void OnPluginStart()
{
	if(DB == null)
		SQL_DBConnect();
}

public void OnConfigsExecuted() 
{
	if(DB == null)
		SQL_DBConnect();
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client))
	{
		char steamid[32], query[1024];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		
		FormatEx(query, sizeof(query), "SELECT name FROM firstjoin WHERE auth = '%s';", steamid);
		DB.Query(CheckPlayer_Callback, query, GetClientSerial(client));
	}
}

public void CheckPlayer_Callback(Database db, DBResultSet result, char[] error, any data)
{
	if(result == null)
	{
		LogError("[FirstJoin] Query Fail: %s", error);
		return;
	}

	int id = GetClientFromSerial(data);

	if(!id)
		return;
		
	while(result.FetchRow())
	{
		updateName(id);
		return;
	}
	
	char userName[MAX_NAME_LENGTH], steamid[32], ip[32];
	GetClientName(id, userName, sizeof(userName));
	GetClientAuthId(id, AuthId_Steam2, steamid, sizeof(steamid));
	GetClientIP(id, ip, sizeof(ip));
	
	int len = strlen(userName) * 2 + 1;
	char[] escapedName = new char[len];
	DB.Escape(userName, escapedName, len);

	len = strlen(steamid) * 2 + 1;
	char[] escapedSteamId = new char[len];
	DB.Escape(steamid, escapedSteamId, len);
	
	char query[512];
	Format(query, sizeof(query), "INSERT INTO `firstjoin` (auth, name, ip) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE name = '%s';", escapedSteamId, escapedName, ip, escapedName);
	DB.Query(Nothing_Callback, query, id);
}

void updateName(int client)
{
	char userName[MAX_NAME_LENGTH], steamid[32];
	GetClientName(client, userName, sizeof(userName));
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	int len = strlen(userName) * 2 + 1;
	char[] escapedName = new char[len];
	DB.Escape(userName, escapedName, len);

	len = strlen(steamid) * 2 + 1;
	char[] escapedSteamId = new char[len];
	DB.Escape(steamid, escapedSteamId, len);

	char query[128];
	FormatEx(query, sizeof(query), "UPDATE `firstjoin` SET name = '%s' WHERE auth = '%s';", escapedName, escapedSteamId);
	DB.Query(Nothing_Callback, query, client);
}

void SQL_DBConnect()
{
	if(DB != null)
		delete DB;
		
	if(SQL_CheckConfig("firstjoin"))
	{
		Database.Connect(SQLConnection_Callback, "firstjoin");
	}
	else
	{
		LogError("[FirstJoin] Startup failed. Error: %s", "\"firstjoin\" is not a specified entry in databases.cfg.");
	}
}


public void SQLConnection_Callback(Database db, char[] error, any data)
{
	if(db == null)
	{
		LogError("[FirstJoin] Can't connect to server. Error: %s", error);
		return;
	}		
	DB = db;
	DB.Query(Nothing_Callback, "CREATE TABLE IF NOT EXISTS `firstjoin` (`auth` varchar(32) NOT NULL, `name` varchar(64) NOT NULL, `ip` varchar(32) NOT NULL) ENGINE=MyISAM DEFAULT CHARSET=utf8;", DBPrio_High);
}

public void Nothing_Callback(Database db, DBResultSet result, char[] error, any data)
{
	if(result == null)
		LogError("[FirstJoin] Error: %s", error);
}

stock bool IsValidClient(int client)
{
	if((1 <= client <= MaxClients) && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
		return true;
	return false;
}