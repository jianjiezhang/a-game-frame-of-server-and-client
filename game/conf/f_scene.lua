

f_scene={
    [1] = {
        id=1,
        width=2000,
        height=2000,
        width_x = 50,
        width_z = 50,
        troop_born = {tx = 200, tz = 200},
        monster_count = 2000,
        boss_count = 500,
        march = {
            speed = 5,
            stop_dist = 3,
            arrive_dist = 1,
            tick_ms = 100,
        },
        collision_radius = 3,
    },
    [100] = {
        id = 100,
        width = 50,
        height = 50,
        width_x = 10,
        width_z = 10,
        blue_born = {tx = 10, tz = 25},
        red_born  = {tx = 40, tz = 25},
    }
}


return f_scene