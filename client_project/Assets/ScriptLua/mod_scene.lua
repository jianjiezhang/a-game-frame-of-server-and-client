--- mod_scene：场景协议处理（纯协议转发，不含业务逻辑）
mod_scene = {}

-- ============================================================
-- 协议回调
-- ============================================================

function mod_scene.m_scene_enter_toc(args)
    print("[mod_scene] recv enter:", vardump(args))
    local pos = args.pos or {tx = 0, tz = 0}
    scene_panel.EnterScene(pos, args.objs, args.troops, args.tank)
    local troop = scene_panel.get_troop(1)
    if troop then
        scene_panel.TrySendMarch(troop.index, 0, {tx=500,tz=500})
    end
end

function mod_scene.m_scene_leave_toc(args)
    print("[mod_scene] recv leave:", vardump(args))
    scene_panel.LeaveScene()
end

function mod_scene.m_scene_slices_toc(args)
    print("[mod_scene] recv slices:", vardump(args))
    if args.pos then
        scene_panel.SetScenePos(args.pos.tx, args.pos.tz)
    end
    scene_panel.UpdateSlices(args.objs)
    --scene_panel.TrySendSlices()
end

function mod_scene.m_scene_obj_toc(args)
    print("[mod_scene] recv obj:", vardump(args))
    if args.obj then
        scene_panel.AddObj(args.obj)
    end
end

function mod_scene.m_scene_gen_tank_toc(args)
    print("[mod_scene] recv gen_tank:", vardump(args))
    if args.error ~= 0 or not args.obj then
        return
    end

    proto_panel.OnTankGenerated()
    scene_panel.AddTank(args.obj)
end

function mod_scene.m_scene_tank_move_toc(args)
    print("[mod_scene] recv tank_move:", vardump(args))
    if args.obj then
        scene_panel.SyncTank(args.obj)
    end
end

function mod_scene.m_scene_slice_leave_toc(args)
    print("[mod_scene] recv slice_event:", vardump(args))
    if args.obj then
        scene_panel.OnSliceLeave(args.obj)
    end
end

function mod_scene.m_scene_march_toc(args)
    print("[mod_scene] recv march_toc:", vardump(args))
end

return mod_scene
