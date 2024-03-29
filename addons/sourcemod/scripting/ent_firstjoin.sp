 #include <sourcemod>
#include <cstrike>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

Database DB = null;

public Plugin myinfo = 
{
	name = "[CSGO] MySQL Player information", 
	author = "Entity", 
	description = "Saves player SteamID, Name and IP, Join Date and Lastseen Date", 
	version = "1.1"
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
        
        DB.Format(query, sizeof(query), "SELECT name FROM firstjoin WHERE auth = '%s';", steamid);
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
	
	char query[512], time[32];
	FormatTime(time, sizeof(time), "%d-%m-%Y", GetTime());
	Format(query, sizeof(query), "INSERT INTO `firstjoin` (name, auth, ip, joindate, lastseen) VALUES ('%s', '%s', '%s', '%s', '%s') ON DUPLICATE KEY UPDATE name = '%s';", escapedName, escapedSteamId, ip, time, time, escapedName);
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

	char query[128], time[32];
	FormatTime(time, sizeof(time), "%d-%m-%Y", GetTime());
	FormatEx(query, sizeof(query), "UPDATE `firstjoin` SET name = '%s', lastseen = '%s' WHERE auth = '%s';", escapedName, time, escapedSteamId);
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
	DB.Query(Nothing_Callback, "CREATE TABLE IF NOT EXISTS `firstjoin` (`id` INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,`name` varchar(64) NOT NULL,`auth` varchar(32) NOT NULL,`ip` varchar(32) NOT NULL,`joindate` varchar(32) NOT NULL,`lastseen` varchar(32) NOT NULL) ENGINE = MyISAM DEFAULT CHARSET = utf8;", DBPrio_High);
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
