extends SceneTree

func _initialize():
	var u=preload("res://club_update.gd")
	var quest="VideoClub-VR-Quest3S-v"
	var android="VideoClub-Android-Jeu-v"
	var releases:Array=[]
	for v in ["0.6.10","0.6.9","1.0.0"]:
		var assets:Array=[]
		for prefix in [quest,android]:
			var n:String=prefix+v+".apk"
			assets.append({"name":n,"browser_download_url":u.REPOSITORY+"/releases/download/v"+v+"/"+n,"digest":"sha256:"+"a".repeat(64),"size":123,"state":"uploaded"})
		releases.append({"tag_name":"v"+v,"draft":v=="1.0.0","assets":assets})
	assert(u.select_asset(releases,quest,"0.6.9").url.ends_with(quest+"0.6.10.apk"))
	assert(u.select_asset(releases,android,"0.6.9").url.ends_with(android+"0.6.10.apk"))
	assert(u.select_asset(releases,quest,"0.6.10").is_empty())
	releases[0].assets[0].digest=""
	assert(u.select_asset(releases,quest,"0.6.9").is_empty())
	assert(u.select_asset(releases,android,"0.6.9").version=="0.6.10")
	print("UPDATE069_OK")
	quit()
