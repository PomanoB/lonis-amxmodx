#include <amxmodx>
#include <sqlx>
#include "lonis"
#include "colorchat"

#define PLUGIN "Lonis"
#define VERSION "1.1"
#define AUTHOR "GmStaff"
#define DATE "13:46 29.12.2010"

#define LOCK_IP (1<<0)
#define LOCK_STEAM_ID (1<<1)

enum fail
{
	fail_password,
	fail_steam_id,
	fail_ip
}

enum _:LNS_SETTINGS
{
	SETTING_ID,
	SETTING_KEY[50],
	SETTING_VALUE[512]
}

enum _:THREAD_QUERY_PARAMS
{
	THREAD_FUNC,
	THREAD_PLUGIN,
	THREAD_DATA[20],
	THREAD_LEN
}

new g_settingsCount

new g_CvarHost, g_CvarUser, g_CvarPassword, g_CvarDB, g_CvarPrefix
new Handle:g_SQL_Connection, Handle:g_SQL_Tuple

new Array:g_lnsSettings

new g_prefix[10]

new g_CvarFails[fail]
new g_CvarFail_Kick
new g_CvarFail_Tag
new g_CvarUnreg_Kick
new g_CvarUnreg_Tag
new g_CvarUnreg_KickReason

new g_CvarAMXXFlag

new g_CvarDebug

new g_fwd_player_login
new g_fwd_close_bd

new g_user_bd_id[33]

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_dictionary ( "lonis.txt" );

	register_clcmd("say", "cmdSay")
	register_clcmd("say_team", "cmdSay")
	
	g_CvarFails[fail_password] = register_cvar("lonis_fail_password", "Invalid password!")
	g_CvarFails[fail_steam_id] = register_cvar("lonis_fail_steamid", "Invalid steam id!")
	g_CvarFails[fail_ip] = register_cvar("lonis_fail_ip", "Invalid IP adress!")

	g_CvarFail_Kick = register_cvar("lonis_fail_kick", "1")
	g_CvarFail_Tag = register_cvar("lonis_fail_tag", "[Error]")

	g_CvarUnreg_Kick = register_cvar("lonis_unreg_kick", "0")
	g_CvarUnreg_KickReason = register_cvar("lonis_unreg_kickreason", "You must be registered on this server")
	g_CvarUnreg_Tag = register_cvar("lonis_unreg_tag", "")

	g_CvarAMXXFlag = register_cvar("lonis_reg_flag", "")
	
	g_fwd_player_login = CreateMultiForward("lonis_player_login", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwd_close_bd = CreateMultiForward("lonis_close_bd", ET_IGNORE)
	
	log_amx("^n^nGm# Loaded %s, %s^n^n", PLUGIN, DATE)
	
}

public plugin_precache()
{
	g_CvarHost = register_cvar("lonis_host", "127.0.0.1")
	g_CvarDB = register_cvar("lonis_db", "achievement")
	g_CvarUser = register_cvar("lonis_user", "")
	g_CvarPassword = register_cvar("lonis_password", "")
	g_CvarPrefix = register_cvar("lonis_prefix", "unr")
	
	g_CvarDebug = register_cvar("lonis_debug", "1")
	
	g_lnsSettings = ArrayCreate(LNS_SETTINGS, 32)
	
	new cfgdir[32]
	get_localinfo("amxx_configsdir", cfgdir, charsmax(cfgdir))
	server_cmd("exec %s/lonis.cfg", cfgdir)
	server_exec()
	
	new host[32], db[32], user[32], password[32]
	get_pcvar_string(g_CvarHost, host, 31)
	get_pcvar_string(g_CvarDB, db, 31)
	get_pcvar_string(g_CvarUser, user, 31)
	get_pcvar_string(g_CvarPassword, password, 31)
	
	get_pcvar_string(g_CvarPrefix, g_prefix, 9)
	
	g_SQL_Tuple = SQL_MakeDbTuple(host,user,password,db)
	
	new err, error[256]
	g_SQL_Connection = SQL_Connect(g_SQL_Tuple, err, error, charsmax(error))
	
	if ( g_SQL_Connection )
	{
		log_amx("[Lonis] Conected to DataBase: OK")
		
		new Handle:q = lonis_mysql_query("SELECT `id`, `key`, `value` FROM `{prefix}_settings`")
		new lnsSet[LNS_SETTINGS]
		while(SQL_MoreResults(q))
		{
			lnsSet[SETTING_ID] = SQL_ReadResult(q, 0)
			SQL_ReadResult(q, 1, lnsSet[SETTING_KEY], 49)
			SQL_ReadResult(q, 2, lnsSet[SETTING_VALUE], 511)
			
			ArrayPushArray(g_lnsSettings, lnsSet)
			
			SQL_NextRow(q)
			
			g_settingsCount++
		}
		
	}
	else
		log_amx("[Lonis] Conected to DataBase: ERROR %d (%s)", err, error)
	
}

public plugin_natives()
{
	register_library("lonis")
	
	register_native("lonis_mysql_query", "_mysql_query")
	register_native("lonis_mysql_thread_query", "native_mysql_thread_query")
	register_native("lonis_get_sql_connection", "_get_sql_connection")
	
	register_native("lonis_get_player_db_id", "native_get_player_db_id")
	
	register_native("lonis_get_player_var", "native_get_player_var")
	register_native("lonis_set_player_var", "native_set_player_var")
	
	register_native("lonis_get_settings", "native_get_settings")
}

public plugin_end()
{
	if (g_SQL_Connection)
	{
		new r
		ExecuteForward(g_fwd_close_bd, r)
		SQL_FreeHandle(g_SQL_Connection)
	}
	SQL_FreeHandle(g_SQL_Tuple)
	
	ArrayDestroy(g_lnsSettings)
}

public cmdSay(id)
{
	new cmd[64]
	read_args(cmd, 63)
	remove_quotes(cmd)
	
	new args[32]
	parse(cmd, cmd, 31, args, 31)
	
	if (equali(cmd, "/register"))
	{
		if (lonis_get_player_db_id(id))
		{
			client_print(id, print_chat, "You already registred user!")
			return PLUGIN_CONTINUE
		}
		else if (args[0])
		{
			
			
		}
	}
	return PLUGIN_CONTINUE
}

public client_connect(id)
{
	g_user_bd_id[id] = 0
}

public client_putinserver(id)
{
	if (g_SQL_Connection)
	{
		remove_task(id)
		set_task(2.0, "checkName", id)
	}
}

public checkName(id)
{
	static name[32], unquoted_name[32], steamid[32], steamid2[32], ip[32]
	
	get_user_name(id, unquoted_name,31)
	
	if (!unquoted_name[0])
		return
		
	g_user_bd_id[id] = 0
	
	SQL_QuoteString(g_SQL_Connection, name, 31, unquoted_name)
	get_user_authid(id, steamid, 31)
	copy(steamid2, charsmax(steamid2), steamid)
	if (steamid2[6] == '4')
		steamid2[6] = '0'
	get_user_ip(id, ip, 31, 1)

	new data[2]
	data[0] = id
	data[1] = get_user_userid(id)
	
	static query[512]
	
	formatex(query, charsmax(query), "SELECT `password`, `ip`, `steam_id`, `flags`, `amxx_flags`, `id`, `auth`, `name` FROM `{prefix}_players` WHERE ((`name` = '%s' AND `auth` = 0) OR ((`steam_id` = '%s' OR `steam_id` = '%s') AND `auth` = 1))  AND `active` = 1", name, steamid, steamid2)
//	server_print("^nLOGIN QUERY ^n%s", query)
	lonis_mysql_thread_query(query, "login_query_handler", data, 2)
	
	/*
	static name[32], unquoted_name[32], steamid[32], ip_int, unreg_tag[32], amx_flags[33]
	static password[32], user_password[40], bd_ip[32], bd_ip_int, reg_flag[32], auth
	static flags, steam_id[32], ip[32], subnet[32], mask[10], mask_int, md5p[34], bdId
	static login[32]
	
	get_pcvar_string(g_CvarUnreg_Tag, unreg_tag, 31)
	
	get_user_name(id, unquoted_name,31)
	
	if (!unquoted_name[0])
		return
	
	SQL_QuoteString(g_SQL_Connection, name, 31, unquoted_name)
	get_user_info(id, "_pw", password, 33)
	md5(password, md5p)
	get_user_authid(id, steamid, 31)
	get_user_ip(id, ip, 31, 1)
	
	g_user_bd_id[id] = 0
	
	new data[2]
	data[0] = id
	data[1] = get_user_userid(id)
	
	static query[256]
	
	new Handle:query = lonis_mysql_query("SELECT `password`, `ip`, `steam_id`, `flags`, `amxx_flags`, `id`, `auth`, `name` FROM `{prefix}_players` WHERE ((`name` = '%s' AND `auth` = 0) OR (`steam_id` = '%s' AND `auth` = 1))  AND `active` = 1", name, steamid)
	if (query != Empty_Handle && SQL_NumResults(query))
	{
		flags = SQL_ReadResult(query, 3)
		SQL_ReadResult(query, 0, user_password, 39)
		SQL_ReadResult(query, 1, subnet, 31)
		SQL_ReadResult(query, 2, steam_id, 31)
		SQL_ReadResult(query, 4, amx_flags, 32)
		bdId = SQL_ReadResult(query, 5)
		auth = SQL_ReadResult(query, 6)
		SQL_ReadResult(query, 7, login, 31)
		
		strtok(subnet, bd_ip, 31, mask, 8, '/', 1)
		bd_ip_int = ip_to_num(bd_ip)
		ip_int = ip_to_num(ip)
		mask_int = str_to_num(mask)
		
		if (auth)
		{
			if (!equal(steam_id, steamid))
			{
				loginFailed(id, fail_steam_id)
				SQL_FreeHandle(query)
				return
			}
		}
		else
		if (!equal(md5p, user_password))
		{
			loginFailed(id, fail_password)
			
			g_user_bd_id[id] = 0
			ExecuteForward(g_fwd_player_login, flags, id, 0)
			
			SQL_FreeHandle(query)
			return
		}
			
		if (!auth && (flags & LOCK_STEAM_ID) && !equal(steam_id, steamid))
		{
			loginFailed(id, fail_steam_id)
			
			g_user_bd_id[id] = 0
			ExecuteForward(g_fwd_player_login, flags, id, 0)
			
			SQL_FreeHandle(query)
			return
		}
		if ((flags & LOCK_IP) && (apply_mask(ip_int, mask_int) != apply_mask(bd_ip_int, mask_int)))
		{
			loginFailed(id, fail_ip)
			
			g_user_bd_id[id] = 0
			ExecuteForward(g_fwd_player_login, flags, id, 0)
			
			SQL_FreeHandle(query)
			return
		
		}
		SQL_FreeHandle(query)
		
		get_pcvar_string(g_CvarAMXXFlag, reg_flag, 31)
		set_user_flags(id, get_user_flags(id)|read_flags(reg_flag)|read_flags(amx_flags))
		
		client_print(id, print_console, "%L", id, "LOGIN_OK", login)
		ColorChat(id, GREEN, "%L", id, "LOGIN_CHAT", login)

		g_user_bd_id[id] = bdId
		ExecuteForward(g_fwd_player_login, flags, id, bdId)
	}
	else
	if (get_pcvar_num(g_CvarUnreg_Kick))
	{
		new kick_reason[128]
		get_pcvar_string(g_CvarUnreg_KickReason, kick_reason, 127)
		
		message_begin(MSG_ONE_UNRELIABLE, SVC_DISCONNECT, _, id)
		write_string(kick_reason)
		message_end()	
	}
	else
	{
		if (unreg_tag[0])
		{
			add(unreg_tag, 31, unquoted_name)
			client_cmd(id, "setinfo name ^"%s^"", unreg_tag)
		}
		
		ExecuteForward(g_fwd_player_login, flags, id, 0)
			
		g_user_bd_id[id] = 0
	}
	*/
}

public login_query_handler(failstate, Handle:query, error[], errnum, data[], len, Float:queuetime)
{
	static id
	id = data[0]
	
	if (!is_user_connected(id) || get_user_userid(id) != data[1])
		return
	
	static flags, password[20], md5p[34] , user_password[39], subnet[32],
		steam_id[31], amx_flags[32], bdId, auth, login[32], mask[8], 
		bd_ip_int, ip_int, mask_int, steamid[32], bd_ip[32], ip[32],
		reg_flag[32], unreg_tag[32]
	
	if (failstate != TQUERY_SUCCESS)
	{
		server_print("^nLOGIN QUERY FAIL^n%s", error)
	}
	
	if (failstate == TQUERY_SUCCESS && SQL_NumResults(query))
	{
		get_user_info(id, "_pw", password, 19)
		md5(password, md5p)
		get_user_authid(id, steamid, 31)
		get_user_ip(id, ip, 31)
		
		flags = SQL_ReadResult(query, 3)
		SQL_ReadResult(query, 0, user_password, 39)
		SQL_ReadResult(query, 1, subnet, 31)
		SQL_ReadResult(query, 2, steam_id, 31)
		SQL_ReadResult(query, 4, amx_flags, 32)
		bdId = SQL_ReadResult(query, 5)
		auth = SQL_ReadResult(query, 6)
		SQL_ReadResult(query, 7, login, 31)
		
		strtok(subnet, bd_ip, 31, mask, 8, '/', 1)
		bd_ip_int = ip_to_num(bd_ip)
		ip_int = ip_to_num(ip)
		mask_int = str_to_num(mask)
		
		if (auth)
		{
			if (!equal(steam_id, steamid))
			{
				g_user_bd_id[id] = 0
				
				loginFailed(id, fail_steam_id)
				
				SQL_FreeHandle(query)
				return
			}
		}
		else
		if (!equal(md5p, user_password))
		{
			g_user_bd_id[id] = 0
			
			loginFailed(id, fail_password)
			
			SQL_FreeHandle(query)
			return
		}
			
		if (!auth && (flags & LOCK_STEAM_ID) && !equal(steam_id, steamid))
		{
			g_user_bd_id[id] = 0
			
			loginFailed(id, fail_steam_id)
			
			SQL_FreeHandle(query)
			return
		}
		if (!auth && (flags & LOCK_IP) && (apply_mask(ip_int, mask_int) != apply_mask(bd_ip_int, mask_int)))
		{
			g_user_bd_id[id] = 0
			
			loginFailed(id, fail_ip)
			
			SQL_FreeHandle(query)
			return
		
		}
		SQL_FreeHandle(query)
		
		get_pcvar_string(g_CvarAMXXFlag, reg_flag, 31)
		set_user_flags(id, get_user_flags(id)|read_flags(reg_flag)|read_flags(amx_flags))
		
		client_print(id, print_console, "%L", id, "LOGIN_OK", login)
		ColorChat(id, GREEN, "%L", id, "LOGIN_CHAT", login)

		g_user_bd_id[id] = bdId
		ExecuteForward(g_fwd_player_login, flags, id, bdId)
	}
	else
	if (get_pcvar_num(g_CvarUnreg_Kick))
	{
		new kick_reason[128]
		get_pcvar_string(g_CvarUnreg_KickReason, kick_reason, 127)
		
		message_begin(MSG_ONE_UNRELIABLE, SVC_DISCONNECT, _, id)
		write_string(kick_reason)
		message_end()	
	}
	else
	{
		get_pcvar_string(g_CvarUnreg_Tag, unreg_tag, 31)
	
		if (unreg_tag[0])
		{
			new unquoted_name[32]
			get_user_name(id, unquoted_name, 31)
			add(unreg_tag, 31, unquoted_name)
			client_cmd(id, "setinfo name ^"%s^"", unreg_tag)
		}
		
		ExecuteForward(g_fwd_player_login, flags, id, 0)
			
		g_user_bd_id[id] = 0
	}
}

public client_infochanged(id)
{
	if (g_SQL_Connection)
	{
		new oldname[32], newname[32], unreg_tag[32], error_tag[32]
		
		get_user_name(id, oldname, 31)
		get_user_info(id, "name", newname, 31)
		
		get_pcvar_string(g_CvarUnreg_Tag, unreg_tag, 31)
		get_pcvar_string(g_CvarFail_Tag, error_tag, 31)
		
		if (!equal(newname, oldname) && !( contain(newname, unreg_tag) == 0 || contain(newname, error_tag) == 0))
		{
			remove_task(id)
			set_task(0.2, "checkName", id)
		}
	}
}

public loginFailed(id, fail:reason)
{
	new error_string[128], tag[32]
	get_pcvar_string(g_CvarFails[reason], error_string, charsmax(error_string))
	get_pcvar_string(g_CvarFail_Tag, tag, 31)
	client_print(id, print_console, "%L", id, "LOGIN_FAILED", error_string)
	
	if (get_pcvar_num(g_CvarFail_Kick))
	{
		message_begin(MSG_ONE_UNRELIABLE, SVC_DISCONNECT, _, id)
		write_string(error_string)
		message_end()
	}
	else if (tag[0])
	{
		new name[32]
		get_user_name(id, name, 31)
		add(tag, 31, name)
		set_user_info(id, "name", tag)
		
		new ret
		ExecuteForward(g_fwd_player_login, ret, id, 0)
	}
	
}

public client_disconnect(id)
{
	if (g_user_bd_id[id] && g_SQL_Connection)
	{
		new ip[20], user_online
		
		new timestamp = get_systime()	
		user_online = get_user_time(id, 1)
		get_user_ip(id, ip, 19, 1)
		
		SQL_FreeHandle(lonis_mysql_query("UPDATE {prefix}_players SET `lastIp` = '%s', lastTime = '%i', `onlineTime` = onlineTime+%i WHERE `id` = %d", ip, timestamp, user_online, g_user_bd_id[id]))
	}
}

public Handle:_mysql_query(iPlugin, iParams)
{
	if (g_SQL_Connection)
	{
		static query[4024]
		vdformat(query, charsmax(query),  1, 2)
		replace_all(query, charsmax(query), "{prefix}", g_prefix)
		
		if (get_pcvar_num(g_CvarDebug))
		{
			log_to_file("lonis_sql.log", "QUERY: %s", query)
			get_pcvar_num(g_CvarDebug)
		}
		new Handle:q = SQL_PrepareQuery(g_SQL_Connection, query)
		new error[256]
		if (!SQL_Execute(q))
		{
			SQL_QueryError(q, error, charsmax(error))
			log_amx("[LONIS] Query Error^n^nError: %s", error)
			SQL_FreeHandle(q)
			return Empty_Handle
		}
		
		return q
	}
	return Empty_Handle
}

public native_mysql_thread_query(iPlugin, iParams)
{
	if (iParams != 4)
		return 0
		
	new param[THREAD_QUERY_PARAMS]
	static query[4024]
		
	param[THREAD_PLUGIN] = iPlugin
	
	get_string(1, query, charsmax(query))
	replace_all(query, charsmax(query), "{prefix}", g_prefix)
	
	if (get_pcvar_num(g_CvarDebug))
	{
		log_to_file("lonis_sql.log", "THREAD QUERY: %s", query)
	}
	
	new func[64]
	get_string(2, func, 63)
	param[THREAD_FUNC] = get_func_id(func, iPlugin)
	
	param[THREAD_LEN] = clamp(get_param(4), 0, 19)
	if ((param[THREAD_LEN]))
		get_array(3, param[THREAD_DATA], param[THREAD_LEN])
		
	return SQL_ThreadQuery(g_SQL_Tuple, "thread_query_handler", query, param, THREAD_QUERY_PARAMS)
}

public thread_query_handler(failstate, Handle:query, error[], errnum, data[], len, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_amx("[LONIS] Thread Query Error (%d): %s", errnum, error)
		return
	}
	new fID = data[THREAD_FUNC]
	
	if (fID != -1)
	{
		callfunc_begin_i(fID, data[THREAD_PLUGIN])
		callfunc_push_int(failstate)
		callfunc_push_int(_:query)
		callfunc_push_str(error, false)
		callfunc_push_int(errnum)
		callfunc_push_array(data[THREAD_DATA], data[THREAD_LEN], false)
		callfunc_push_int(data[THREAD_LEN])
		callfunc_push_float(queuetime)
		callfunc_end()
	}
}
	
public Handle:_get_sql_connection(iPlugin, iParams)
{
	return g_SQL_Connection
}

public native_get_player_db_id(iPlugin, iParams)
{
	if (iParams != 1)
		return 0
		
	return g_user_bd_id[get_param(1)]
}
public native_get_player_var(iPlugin, iParams)
{
	if (iParams != 4)
		return 0
		
	new id = get_param(1)
	
	if (!g_user_bd_id[id])
		return 0
	
	new key[50], quoted_key[100]
	get_string(2, key, 49)
	
	SQL_QuoteString(g_SQL_Connection, quoted_key, charsmax(quoted_key), key)
	
	new Handle:query = lonis_mysql_query("SELECT `value` FROM {prefix}_players_var WHERE `playerId` = %d AND `key` = '%s'",
		g_user_bd_id[id], quoted_key)
	if (!SQL_NumResults(query))
		return 0
	
	new value[512]
	SQL_ReadResult(query, 0, value, charsmax(value))
	SQL_FreeHandle(query)
	
	set_string(3, value, get_param(4))
	return 1
}

public native_set_player_var(iPlugin, iParams)
{
	if (iParams != 3)
		return 0
		
	new id = get_param(1)
	
	if (!g_user_bd_id[id])
		return 0
	
	new key[50], quoted_key[100]
	get_string(2, key, 49)
	SQL_QuoteString(g_SQL_Connection, quoted_key, charsmax(quoted_key), key)
	
	new value[50], quoted_value[100]
	get_string(3, value, 49)
	SQL_QuoteString(g_SQL_Connection, quoted_value, charsmax(quoted_value), value)
	
	
	new Handle:query = lonis_mysql_query("INSERT INTO {prefix}_players_var VALUES(%d, '%s', '%s') ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)",
		g_user_bd_id[id], quoted_key, quoted_value)
	SQL_FreeHandle(query)
	
	return 1
}

public native_get_settings(iPlugin, iParams)
{
	new prevId = get_param(2) - 1
	
	static i, lnsSet[LNS_SETTINGS]
	
	new key[50]
	get_string(1, key, 49)
	
	for(i = 0; i < g_settingsCount; i++)
	{
		ArrayGetArray(g_lnsSettings, i, lnsSet)
		
		if (lnsSet[SETTING_ID] <= prevId)
			continue
			
		if (equal(key, lnsSet[SETTING_KEY]))
		{
			if (iParams == 2 )
			{
				if (is_str_num(lnsSet[SETTING_VALUE]))
					return str_to_num(lnsSet[SETTING_VALUE]) 
				else
					return _:str_to_float(lnsSet[SETTING_VALUE])
			}
			else
			if (iParams == 3)
			{
				if (is_str_num(lnsSet[SETTING_VALUE]))
					set_param_byref(3, str_to_num(lnsSet[SETTING_VALUE]))
				else
					set_float_byref(3, str_to_float(lnsSet[SETTING_VALUE]))
					
				return lnsSet[SETTING_ID] + 1
			}
			else
			{
				set_string(3, lnsSet[SETTING_VALUE], get_param(4))
				
				return lnsSet[SETTING_ID] + 1
			}
		}
	}
	return 0
}

stock apply_mask ( const ip, const mask )
{
	new shift = 32 - clamp ( mask, 0 , 32 )
	return ( ip >> shift ) << shift
}

stock ip_to_num ( const ip[] )
{
	static string[16], byte_0[4], byte_A[4], byte_B[4], byte_C[4], _ip

	copy ( string, charsmax ( string ), ip )
	replace_all ( string, charsmax ( string ), ".", " ")

	if ( parse ( string, byte_0, charsmax ( byte_0 ), byte_A, charsmax ( byte_A ), byte_B, charsmax ( byte_B ), byte_C, charsmax ( byte_C ) ) != 4 ) return -1

	_ip =  ( str_to_num ( byte_0 ) & 255 ) << 24
	_ip += ( str_to_num ( byte_A ) & 255 ) << 16
	_ip += ( str_to_num ( byte_B ) & 255 ) << 8
	_ip +=   str_to_num ( byte_C ) & 255

	return _ip
}
