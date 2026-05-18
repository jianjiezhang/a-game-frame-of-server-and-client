k_scene = {}

k_scene.KSCENE_WORLD = 1
k_scene.KSCENE_BATTLE = 100

--场景对象类型
k_scene.KSCENE_TYPE_ROLE = 1
k_scene.KSCENE_TYPE_NPC = 2
k_scene.KSCENE_TYPE_MONSTER = 3
k_scene.KSCENE_TYPE_BOSS = 4
k_scene.KSCENE_TYPE_TROOP = 5
k_scene.KSCENE_TYPE_TANK = 6

--战斗场景对象类型
k_scene.KSCENE_TYPE_BATTLE_TROOP = 101
k_scene.KSCENE_TYPE_BATTLE_TANK = 102
k_scene.KSCENE_TYPE_BATTLE_BOSS = 103
k_scene.KSCENE_TYPE_BATTLE_MONSTER = 104


--场景对象状态
k_scene.KSCENE_STATE_IDLE = 1
k_scene.KSCENE_STATE_MARCH = 2
k_scene.KSCENE_STATE_BATTLE = 3

--组件类型
k_scene.KSCENE_COMPONENT_TYPE_MARCH = 1
k_scene.KSCENE_COMPONENT_TYPE_BATTLE = 2

--场景事件 typeid
k_scene.KSCENE_EVENT_COLLISION = 1

--战斗场景 typeid（对应 f_scene[100]）
k_scene.KSCENE_BATTLE_MAP_TYPEID = 100

return k_scene






