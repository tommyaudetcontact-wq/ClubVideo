extends Node

const QUEST_VERSION := "0.9.7"
const ANDROID_VERSION := "0.9.7"
const REPOSITORY := "https://github.com/tommyaudetcontact-wq/ClubVideo"
const RELEASES := "https://api.github.com/repos/tommyaudetcontact-wq/ClubVideo/releases?per_page=12"
const STAGING := "user://updates/download.apk"
const READY := "user://updates/verified.apk"
const RECORD := "user://updates/version.cfg"
var game
var prefix: String
var http: HTTPRequest
var installer
var pending: Dictionary = {}
var worker: Thread
var permission_requested := false
var installer_requested := false

func setup(owner_game):
	game=owner_game
	if not OS.has_feature("android") or OS.get_cmdline_args().has("--script"):
		queue_free()
		return
	process_mode=Node.PROCESS_MODE_ALWAYS
	prefix="VideoClub-Android-Jeu-v" if game.touch_profile else "VideoClub-VR-Quest3S-v"
	if Engine.has_singleton("ClubUpdate"):installer=Engine.get_singleton("ClubUpdate")
	http=HTTPRequest.new()
	http.use_threads=true
	http.timeout=15
	http.body_size_limit=1024*1024
	add_child(http)
	http.request_completed.connect(on_releases,CONNECT_ONE_SHOT)
	http.request(RELEASES,["Accept: application/vnd.github+json","User-Agent: VideoClub-Updater"])

static func version_parts(tag:String)->Array[int]:
	var parts:=tag.trim_prefix("v").split(".")
	if parts.size()!=3:return []
	var result:Array[int]=[]
	for part in parts:
		if not part.is_valid_int() or int(part)<0:return []
		result.append(int(part))
	return result

static func is_newer(a:String,b:String)->bool:
	var left:=version_parts(a)
	var right:=version_parts(b)
	if left.size()!=3 or right.size()!=3:return false
	for i in range(3):
		if left[i]!=right[i]:return left[i]>right[i]
	return false

static func select_asset(releases:Array,asset_prefix:String,current:String)->Dictionary:
	var best:Dictionary={}
	for release in releases:
		if not release is Dictionary or release.get("draft",true):continue
		var version:=str(release.get("tag_name","")).trim_prefix("v")
		if not is_newer(version,str(best.get("version",current))):continue
		var expected_name:=asset_prefix+version+".apk"
		var expected_url:=REPOSITORY+"/releases/download/v"+version+"/"+expected_name
		for asset in release.get("assets",[]):
			var checksum:=str(asset.get("digest","")).trim_prefix("sha256:")
			var size:=int(asset.get("size",0))
			if asset.get("name")!=expected_name or asset.get("browser_download_url")!=expected_url:continue
			if asset.get("state")!="uploaded" or checksum.length()!=64 or size<=0 or size>2_000_000_000:continue
			best={"version":version,"url":expected_url,"sha256":checksum,"size":size}
			break
	return best

func on_releases(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:return
	var releases:Variant=JSON.parse_string(body.get_string_from_utf8())
	if not releases is Array:return
	pending=select_asset(releases,prefix,ANDROID_VERSION if game.touch_profile else QUEST_VERSION)
	if pending.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STAGING))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(READY))
		return
	var directory:=ProjectSettings.globalize_path("user://updates")
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return
	var config:=ConfigFile.new()
	if config.load(RECORD)==OK and config.get_value("apk","digest","")==pending.sha256 and FileAccess.file_exists(READY):
		verify_file(READY)
		return
	http.timeout=0
	http.body_size_limit=int(pending.size)
	http.download_file=STAGING
	http.request_completed.connect(on_download,CONNECT_ONE_SHOT)
	game._message("Téléchargement de la version "+pending.version+" en cours.")
	if http.request(pending.url)!=OK:game._message("Impossible de télécharger la mise à jour.")

func on_download(result:int,code:int,_headers:PackedStringArray,_body:PackedByteArray):
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STAGING))
		game._message("Mise à jour interrompue. Réessaie en rouvrant le jeu.")
		return
	verify_file(STAGING)

func verify_file(path:String):
	worker=Thread.new()
	if worker.start(read_digest.bind(path))!=OK:worker=null

static func read_digest(path:String)->Dictionary:
	return {"path":path,"digest":FileAccess.get_sha256(path)}

func _process(_delta:float):
	if not worker or worker.is_alive():return
	var checked:Dictionary=worker.wait_to_finish()
	worker=null
	if checked.digest!=pending.sha256:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(checked.path))
		game._message("Le téléchargement n’a pas passé la vérification. Rouvre le jeu pour réessayer.")
		return
	if checked.path==STAGING:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(READY))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(STAGING),ProjectSettings.globalize_path(READY))!=OK:return
		var config:=ConfigFile.new()
		config.set_value("apk","digest",pending.sha256)
		config.save(RECORD)
	launch_installer()

func launch_installer():
	if pending.is_empty() or installer_requested:return
	if not installer:
		OS.shell_open(pending.url)
		installer_requested=true
	elif installer.canInstall():
		if game.clerk.shift.started:game.session.save_game(false)
		installer_requested=installer.installApk()
		if not installer_requested:OS.shell_open(pending.url)
	elif not permission_requested:
		permission_requested=true
		installer.requestInstallPermission()

func _notification(what:int):
	if what==NOTIFICATION_APPLICATION_RESUMED and permission_requested and not installer_requested:
		call_deferred("launch_installer")

func _exit_tree():
	if worker:worker.wait_to_finish()
