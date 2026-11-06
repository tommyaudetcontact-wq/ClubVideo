extends RefCounted

# Apply before the loading screen's first XR frame and again on scene handoff.
# Mobile's memory/render scale profile must never leak into the Quest viewport.
static func apply(viewport:Viewport,xr:XRInterface)->void:
	viewport.scaling_3d_scale=1.0
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.use_taa=false
	viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.texture_mipmap_bias=-.35
	if not xr:return
	xr.set("render_target_size_multiplier",1.4)
	if xr.has_method("set_foveation_level"):xr.call("set_foveation_level",0)
	if xr.has_method("set_foveation_dynamic"):xr.call("set_foveation_dynamic",false)
