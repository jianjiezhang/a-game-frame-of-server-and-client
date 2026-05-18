role_hook = {}









function role_hook.post_connect(sock)

end




function role_hook.role_stop()
    mod_scene.auto_leave("role_stop")
end







return role_hook