#if defined LONIS_INCLUDED
  #endinput
#endif
#define LONIS_INCLUDED

#pragma library lonis

forward lonis_player_login(id, bdId);
forward lonis_close_bd();

native Handle:lonis_get_sql_connection();
native Handle:lonis_mysql_query(query[], any:...);
native lonis_mysql_thread_query(query[], func[] = "", data[] = "", len = 0);

native lonis_get_player_db_id(id);

native lonis_get_player_var(id, key[], value[], size);
native lonis_set_player_var(id, key[], value[]);

native any:lonis_get_settings(key[], prev_id = 0, any:...)
