extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	var clerk=game.clerk
	clerk.set_physics_process(false)
	clerk.customers.set_physics_process(false)
	clerk.customers.spawn_customer()
	var customer:Dictionary=clerk.customers.customers[0]
	clerk.max_basket=1
	clerk.select_film(customer)
	clerk.customer_ready(customer)
	var item:Dictionary=clerk.active.items[0]
	var node:RigidBody3D=item.node
	clerk.locks.set_locked(node,false)
	assert(not node.get_meta("antitheft") and not item.record.locked)
	clerk.abandon_customer(customer)
	assert(node.get_meta("antitheft") and item.record.locked)
	assert(node.get_meta("customer_animating",false))
	await create_timer(.8).timeout
	assert(not node.get_meta("customer_animating",false))
	game.touch_controls.pick_touch_case(item)
	assert(game.held==node and node.get_meta("antitheft"))
	var bar:MeshInstance3D=node.get_node("Antitheft")
	assert(bar.is_visible_in_tree() and bar.position.x>node.get_node("MoldedPlasticOnly").get_aabb().end.x)
	print("CHUTE088_OK")
	quit()
