extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	var ui=game.touch_controls
	var lobby=game.lobby
	game.clerk.customers.set_physics_process(false)
	ui.show_start_menu()
	assert(paused and ui.menu.get_parent().visible)
	assert(not game.clerk.shift.started)
	ui.play_solo()
	assert(not paused and game.clerk.shift.started)
	assert(lobby.is_playing())
	lobby.start()
	var other:=PacketPeerUDP.new()
	assert(other.set_dest_address("127.0.0.1",39166)==OK)
	var id:="abcd1234abcd1234abcd1234"
	var packet={"magic":"VideoClubLobby/1","sender":id,"type":"presence","name":"Quest réseau","playing":false,"available":true}
	other.put_packet(JSON.stringify(packet).to_utf8_buffer())
	await create_timer(.25).timeout
	assert(lobby.peers.has(id) and lobby.list_players().is_empty())
	packet.playing=true
	other.put_packet(JSON.stringify(packet).to_utf8_buffer())
	await create_timer(.25).timeout
	assert(lobby.list_players().size()==1)
	packet.available=false
	other.put_packet(JSON.stringify(packet).to_utf8_buffer())
	await create_timer(.25).timeout
	assert(lobby.list_players().is_empty())
	packet.available=true
	other.put_packet(JSON.stringify(packet).to_utf8_buffer())
	await create_timer(.25).timeout
	var invitation={"magic":"VideoClubLobby/1","sender":id,"to":lobby.device_id,"type":"join","ticket":"abcdabcdabcdabcd"}
	other.put_packet(JSON.stringify(invitation).to_utf8_buffer())
	await create_timer(.25).timeout
	assert(lobby.incoming.get("from")==id)
	print("SOLO068_OK first menu opens, solo starts without a peer")
	print("P2P068_OK loopback UDP, playing and availability filtered, direct join request delivered")
	quit()
