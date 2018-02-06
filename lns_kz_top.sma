#include <amxmodx>
#include "lonis"
#include <sqlx>
#include <kzarg>

#define PLUGIN "Gm # KZ Top"
#define VERSION "2.0.1"
#define AUTHOR "PomanoB"

new g_player_bd_id[33]

new g_mapname[64]

new g_cvar_anonce_connect
new g_cvar_base_url

new g_top_item_id

new g_topMenu, g_typeMenu
new g_topMode[33]

new g_playerRecords[33][3]

new const g_types[3][] = 
{
	"Pro",
	"Noob",
	"All"
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say", "cmdSay")
	register_clcmd("say_team", "cmdSay")
	
	get_mapname(g_mapname, charsmax(g_mapname))
	
	g_cvar_anonce_connect = register_cvar("kz_unr_top_anonce_time", "4.0")
	g_cvar_base_url = register_cvar("kz_unr_top_base_url", "http://127.0.0.1/unr/")
	
	g_topMenu = menu_create("Top Menu", "topMenuHandler")
	menu_setprop(g_topMenu, MPROP_EXITNAME, "Main Menu")
	menu_additem(g_topMenu, "Map Top", "1")
	menu_additem(g_topMenu, "Players Top", "2")
	menu_additem(g_topMenu, "My Top", "3")
	menu_additem(g_topMenu, "Help", "4")
	
	g_typeMenu = menu_create("Type", "typeMenuHandler")
	menu_setprop(g_typeMenu, MPROP_EXITNAME, "Back")
	menu_additem(g_typeMenu, "Pro Top", "pro")
	menu_additem(g_typeMenu, "Noob Top", "noob")
	menu_additem(g_typeMenu, "All Top", "all")
}

public lonis_player_login(id, bdid)
{
	
	g_player_bd_id[id] = bdid
	
	
	g_playerRecords[id][0] = -1
	g_playerRecords[id][1] = -1
	g_playerRecords[id][2] = -1
	
	if (bdid)
		loadPlayerData(id)

}

public loadPlayerData(id)
{
	new data[3]
	data[0] = id
	data[1] = g_player_bd_id[id]
	
	
	static query[256]
	
	data[2] = 0
	formatex(query, charsmax(query), "SELECT COUNT(DISTINCT `map`) FROM `kz_map_top` WHERE `player` = %d AND `go_cp` = 0 AND (`weapon` = 16 OR `weapon` = 29)", g_player_bd_id[id])
	lonis_mysql_thread_query(query, "loadDataHandler", data, 3)
	
	data[2] = 1
	formatex(query, charsmax(query), "SELECT COUNT(DISTINCT `map`) FROM `kz_map_top` WHERE `player` = %d AND (`go_cp` != 0 OR (`weapon` != 16 AND `weapon` != 29))", g_player_bd_id[id])
	lonis_mysql_thread_query(query, "loadDataHandler", data, 3)
	
	data[2] = 2
	formatex(query, charsmax(query), "SELECT COUNT(DISTINCT `map`) FROM `kz_map_top` WHERE `player` = %d", g_player_bd_id[id])
	lonis_mysql_thread_query(query, "loadDataHandler", data, 3)
}

public loadDataHandler(failstate, Handle:query, error[], errnum, data[], len, Float:queuetime)
{
	new id = data[0]
	if (g_player_bd_id[id] != data[1])
		return
		
	if (failstate == TQUERY_SUCCESS)
	{	
		if (SQL_NumResults(query))
			g_playerRecords[id][data[2]] = SQL_ReadResult(query, 0)
		else
			g_playerRecords[id][data[2]] = 0
			
		SQL_FreeHandle(query)
	}
	else
		g_playerRecords[id][data[2]] = 0
	
	new i
	for(i = 0; i < 3; i++)
	{
		if (g_playerRecords[id][i] == -1)
			return
	}
	
	new Float:anonceTime = get_pcvar_float(g_cvar_anonce_connect)
	if (anonceTime)
	{
		set_task(anonceTime, "anoncePlayer", id)
	}
	
}

public anoncePlayer(id)
{
	new name[32]
	get_user_name(id, name, 31)
	new message[128]
	new steamId[32]
	get_user_authid(id, steamId, 31)
	
//	formatex(message, charsmax(message), "!t%s !gput in server,!t%d !gpro recrods, current pro rank is !t%d", name, getPlayerRecords(g_player_bd_id[id], 0), getPlayerRank(g_player_bd_id[id], 0))
	if (equal(steamId, "STEAM_0:0:65840632"))
		formatex(message, charsmax(message), "!t%s !gput in server, she has !t%d !gpro recrods", name, g_playerRecords[id][0])
	else
		formatex(message, charsmax(message), "!t%s !gput in server, he has !t%d !gpro recrods", name, g_playerRecords[id][0])
	kz_colorchat(0, message)
}

public kz_pluginload()
{
	g_top_item_id = kz_mainmenu_item_register("Top", "")
}

public kz_finishclimb(id, Float:tiempo, CheckPoints, GoChecks, Weapon)
{
	if (g_player_bd_id[id])
	{
		new bdid = g_player_bd_id[id]
		
		new data[2]
		data[0] = id
		data[1] = g_player_bd_id[id]
		
		static query[256]
		
		formatex(query, charsmax(query), 
			"INSERT INTO `kz_map_top` (`map`, `player`, `time`, `cp`, `go_cp`, `weapon`) VALUES ('%s', %d, %.5f, %d, %d, %d)",
			g_mapname, bdid, tiempo, CheckPoints, GoChecks, Weapon)
		lonis_mysql_thread_query(query, "finishClimbHandler", data, 2)
		
		/*
		SQL_FreeHandle(lonis_mysql_query())
	
		new type
		if (GoChecks == 0 && (Weapon == CSW_KNIFE || Weapon == CSW_USP))
			type = 0
		else
			type = 1
		
		new topRank = getPlayerMapRank(bdid, g_mapname, type)
		new allRank = getPlayerMapRank(bdid, g_mapname, 2)
		
		new message[64]
		format(message, charsmax(message), "You now !t%d!g in !t%s!g top, !t%d!g in all top", 
			topRank, g_types[type], allRank)
			
		kz_colorchat(id, message)	
		*/
	}
}


public finishClimbHandler(failstate, Handle:query, error[], errnum, data[], len, Float:queuetime)
{
//	if (failstate == TQUERY_SUCCESS)
//	{
		
//	}
	
	//getPlayerMapRankAsync();
}

public kz_itemmainmenu(id, item, page)
{
	if (item == g_top_item_id)
	{
		menu_display(id, g_topMenu)
	}
}

public topMenuHandler(id, menu, item)
{
	if( item < 0) 
	{
		kz_open_mainmenu(id)
		return
	}
 
	new cmd[4]
	new acs, callback
 
	menu_item_getinfo(menu, item,  acs, cmd, 3, _, _, callback)
	
	new command = str_to_num(cmd)
	
	if (command == 3 && !g_player_bd_id[id])
	{
		kz_set_hud_overtime(id, "You not register playre!")
		menu_display(id, g_topMenu)
	}
	else if (command == 4)
	{
		new url[128]
		get_pcvar_string(g_cvar_base_url, url, charsmax(url))
		format(url, charsmax(url), "%skz_help.html", url)
		show_motd(id, url)
		menu_display(id, g_topMenu)
	}
	else
	{
		g_topMode[id] = command
		menu_display(id, g_typeMenu)
	}
}

public typeMenuHandler(id, menu, item)
{
	if( item < 0) 
	{
		menu_display(id, g_topMenu)
		return
	}
 
	new type[6]
	new acs, callback
 
	menu_item_getinfo(menu, item,  acs, type, 5, _, _, callback)
	
	new url[128]
	get_pcvar_string(g_cvar_base_url, url, charsmax(url))
	
	switch (g_topMode[id])
	{
		case 1:
		{
			format(url, charsmax(url), "%s?action=kz_map&map=%s&type=%s&cs=1&lang=ru", url, g_mapname, type)
		}
		case 2:
		{
			format(url, charsmax(url), "%s?action=kz_players&type=%s&cs=1&lang=ru", url, type)
		}
		default:
		{
			format(url, charsmax(url), "%s?action=kz_player&id=%d&type=%s&cs=1&lang=ru", url, g_player_bd_id[id], type)
		}
	}
	show_motd(id, url)
	menu_display(id, g_typeMenu)
}

public getPlayerRank(id, type)
{
	SQL_FreeHandle(lonis_mysql_query("SET @rank = 0"))
	new Handle:query
	switch (type)
	{
		case 0:
		{
			query = lonis_mysql_query("SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` FROM `{prefix}_players` RIGHT JOIN (SELECT `player`, COUNT(DISTINCT `map`) AS `records` FROM `kz_map_top` WHERE `go_cp` = 0 AND (`weapon` = 16 OR `weapon` = 29) GROUP BY `player`) AS `tmp` ON `{prefix}_players`.`id` = `tmp`.`player` ORDER BY `records` DESC) AS `tmp2` WHERE `player` = %d", id)
		}
		case 1:
		{
			query = lonis_mysql_query("SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` FROM `{prefix}_players` RIGHT JOIN (SELECT `player`, COUNT(DISTINCT `map`) AS `records` FROM `kz_map_top` WHERE `go_cp` != 0 OR (`weapon` != 16 AND `weapon` != 29) GROUP BY `player`) AS `tmp` ON `{prefix}_players`.`id` = `tmp`.`player` ORDER BY `records` DESC) AS `tmp2` WHERE `player` = %d", id)
		}
		default:
		{
			query = lonis_mysql_query("SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` FROM `{prefix}_players` RIGHT JOIN (SELECT `player`, COUNT(DISTINCT `map`) AS `records` FROM `kz_map_top` GROUP BY `player`) AS `tmp` ON `{prefix}_players`.`id` = `tmp`.`player` ORDER BY `records` DESC) AS `tmp2` WHERE `player` = %d", id)
		}
	}
	new rank = 0
	if (SQL_NumResults(query))
		rank = SQL_ReadResult(query,0 )
	SQL_FreeHandle(query)
	
	return rank
}

public getPlayerMapRank(id, map[], type)
{
	SQL_FreeHandle(lonis_mysql_query("SET @rank = 0"))
	new Handle:query
	switch (type)
	{
		case 0:
		{
			query = lonis_mysql_query("SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` FROM (SELECT * FROM `kz_map_top` WHERE `map` = '%s' AND `go_cp` = 0 AND (`weapon` = 16 OR `weapon` = 29) ORDER BY `time`) AS `tmp` GROUP BY `player` ORDER BY `time`) AS `tmp2` WHERE `player` = %d", map, id)
		}
		case 1:
		{
			query = lonis_mysql_query("SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` FROM (SELECT * FROM `kz_map_top` WHERE `map` = '%s' AND (`go_cp` != 0 OR (`weapon` != 16 AND `weapon` != 29)) ORDER BY `time`) AS `tmp` GROUP BY `player` ORDER BY `time`) AS `tmp2` WHERE `player` = %d", map, id)
		}
		default:
		{
			query = lonis_mysql_query("SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` FROM (SELECT * FROM `kz_map_top` WHERE `map` = '%s' ORDER BY `time`) AS `tmp` GROUP BY `player` ORDER BY `time`) AS `tmp2` WHERE `player` = %d", map, id)
		}
	}
	new rank = 0
	if (SQL_NumResults(query))
		rank = SQL_ReadResult(query,0 )
	SQL_FreeHandle(query)
	
	return rank
}

public getPlayerMapRankAsync(id, map[], type, handler[])
{
	new data[30]
	data[0] = id
	data[1] = type
	data[2] = get_func_id(handler)
	copy(data[3], charsmax(data) - 3, map)
	
	static query[512]
	switch (type)
	{
		case 0:
		{
			formatex(query, charsmax(query),
				"SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` \
					FROM (SELECT * FROM `kz_map_top` \
					WHERE `map` = '%s' AND `go_cp` = 0 AND \
						(`weapon` = 16 OR `weapon` = 29) \
					ORDER BY `time`) AS `tmp` \
					GROUP BY `player` ORDER BY `time`) AS `tmp2` \
					WHERE `player` = %d", map, id)
		}
		case 1:
		{
			formatex(query, charsmax(query),
				"SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` \
					FROM (SELECT * FROM `kz_map_top` WHERE `map` = '%s' AND \
					(`go_cp` != 0 OR (`weapon` != 16 AND `weapon` != 29)) \
					ORDER BY `time`) AS `tmp` GROUP BY `player` ORDER BY `time`) \
					AS `tmp2` WHERE `player` = %d", map, id)
		}
		default:
		{
			formatex(query, charsmax(query),
				"SELECT `rank` FROM (SELECT *, (@rank := @rank + 1) AS `rank` FROM \
					(SELECT * FROM `kz_map_top` WHERE `map` = '%s' ORDER BY `time`) \
					AS `tmp` GROUP BY `player` ORDER BY `time`) AS `tmp2` \
					WHERE `player` = %d", map, id)
		}
	}
	
	lonis_mysql_thread_query(query, "getPlayerMapRankAsyncHandler", data, 30)
}

public getPlayerMapRankAsyncHandler(failstate, Handle:query, error[], errnum, data[], len, Float:queuetime)
{
	new id = data[0]
	new type = data[1]
	new rank = -1
	
	if (failstate == TQUERY_SUCCESS && SQL_NumResults(query))
		rank = SQL_ReadResult(query, 0)
	
	callfunc_begin_i(data[2])
	callfunc_push_int(id)
	callfunc_push_int(type)
	callfunc_push_str(data[3], false)
	callfunc_push_int(rank)
	callfunc_end()
}

public getPlayerRecords(id, type)
{
	new Handle:query
	switch (type)
	{
		case 0:
		{
			query = lonis_mysql_query("SELECT COUNT(DISTINCT `map`) FROM `kz_map_top` WHERE `player` = %d AND `go_cp` = 0 AND (`weapon` = 16 OR `weapon` = 29)", id)
		}
		case 1:
		{
			query = lonis_mysql_query("SELECT COUNT(DISTINCT `map`) FROM `kz_map_top` WHERE `player` = %d AND (`go_cp` != 0 OR (`weapon` != 16 AND `weapon` != 29))", id)
		}
		default:
		{
			query = lonis_mysql_query("SELECT COUNT(DISTINCT `map`) FROM `kz_map_top` WHERE `player` = %d", id)
		}
	}
	new rank = SQL_ReadResult(query,0 )
	SQL_FreeHandle(query)
	
	return rank
}

public cmdSay(id)
{
	new command[42]
	read_argv(1, command, charsmax(command))
	remove_quotes(command)
	
	new cmd[10], arg[32]
	
	parse(command, cmd, charsmax(cmd), arg, charsmax(arg))
	
	if (equal(cmd, "/top", 4) || equal(cmd, "/pro", 4) || equal(cmd, "/noob", 5))
	{
		menu_display(id, g_topMenu)
	}
	else
	if (equal(cmd, "/maprank"))
	{
		if (g_player_bd_id[id])
		{
			new type
			switch (arg[0])
			{
				case 'p':
					type = 0
				case 'n':
					type = 1
				default:
					type = 2
			}
			new rank = getPlayerMapRank(g_player_bd_id[id], g_mapname, type)
			
			new message[64]
			format(message, charsmax(message), "You now !t%d!g in !t%s!g map top", 
				rank, g_types[type])			
			kz_colorchat(id, message)
		}
		else
			kz_colorchat(id, "You not registered player!")
	}
	else
	if (equal(cmd, "/rank"))
	{
		if (g_player_bd_id[id])
		{
			new type
			switch (arg[0])
			{
				case 'p':
					type = 0
				case 'n':
					type = 1
				default:
					type = 2
			}
			new rank = getPlayerRank(g_player_bd_id[id], type)
			
			new message[64]
			format(message, charsmax(message), "You now !t%d!g in !t%s!g top", 
				rank, g_types[type])			
			kz_colorchat(id, message)
		}
		else
			kz_colorchat(id, "You not registered player!")
	}
	else
	if (equal(cmd, "/stats"))
	{
		new bdid = g_player_bd_id[id]
		if (bdid)
		{
			new prorec = getPlayerRecords(bdid, 0)
			new noobrec = getPlayerRecords(bdid, 1)
			new allrec = getPlayerRecords(bdid, 2)
			new message[128]
			format(message, charsmax(message), "You have !t%d!g pro recs, !t%d!g noob recs and !t%d!g total recs", 
				prorec, noobrec, allrec)			
			kz_colorchat(id, message)
		}
		else
			kz_colorchat(id, "You not register player!")
	}
}
