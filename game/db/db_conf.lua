

db_conf = {}


db_conf.t_account = {"t_account", {"id"}, {{"id", "uint32", 0}, {"name", "string(32)", ""}, {"password", "string(32)", ""}, {"create_time", "uint32", 0}, {"ban", "uint8", 0}, {"lock", "uint8", 0}}}
db_conf.t_role = {"t_role", {"id"}, {{"id", "uint64", 0}, {"name", "string(32)", ""}, {"account_id", "uint32", 0}, {"channel", "string(32)", ""}, {"device", "string(16)", ""}, {"server_id", "uint32", 0}, {"sex", "uint8", 0}, {"age", "uint8", 0}, {"lv", "uint8", 0}, {"vip_lv", "uint8", 0}, {"login_time", "uint32", 0}, {"logout_time", "uint32", 0}, {"create_time", "uint32", 0}}}

--db_conf.t_role = {"t_role", {"id"}, {{"id", "uint64", 0}, {"name", "string(32)", ""}, {"lv", "uint32", 1}, {"args", "mixed(512)", "{}"}}}
--db_conf.t_mission = {"t_mission", {"role_id", "id"}, {{"role_id", "uint64", 0}, {"id", "uint32", 0}, {"state", "uint8", 0}, {"conds", "mixed(256)", "{}"}, {"args", "mixed(512)", "{}"}}}
--db_conf.t_item = {"t_item", {"id"}, {{"id", "uint64", 0}, {"data", "blob", ""}}}
--db_conf.t_image = {"t_image", {"id"}, {{"id", "uint64", 0}, {"data", "tinyblob", ""}}}










return db_conf









