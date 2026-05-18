



create table if not exists `t_account`
(
    `id` int unsigned not null default 0,
    `name` char(32) not null default "",
    `password` char(32) not null default "",
    `create_time` int unsigned not null default 0,
    `ban` tinyint unsigned not null default 0,
    `lock` tinyint unsigned not null default 0,
    primary key(`id`),
    unique key(`name`)
)engine=innodb;

create table if not exists `t_role`
(
    `id` bigint unsigned not null auto_increment,
    `name` char(32) not null default "",
    `account_id` int unsigned not null default 0,
    `channel` char(32) not null default "",
    `device` char(16) not null default "",
    `server_id` int unsigned not null default 0,
    `sex` tinyint unsigned not null default 0,
    `age` tinyint unsigned not null default 0,
    `lv` tinyint unsigned not null default 0,
    `vip_lv` tinyint unsigned not null default 0,
    `login_time` int unsigned not null default 0,
    `logout_time` int unsigned not null default 0,
    `create_time` int unsigned not null default 0,
    primary key(`id`),
    unique key(`name`)
)engine=innodb auto_increment=1;













