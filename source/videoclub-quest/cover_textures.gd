extends RefCounted
# Shared full-resolution paper textures: held covers and near-shelf overlays
# reference the same GPU texture. Normalize RGB mipchains before upload.
static var cache:Dictionary={}
static func get_cover(path:String)->Texture2D:
 if cache.has(path):return cache[path]
 var source:Texture2D=load(path)
 if not source:return null
 var pixels:Image=source.get_image()
 if pixels.is_compressed():pixels.decompress()
 pixels.clear_mipmaps()
 pixels.convert(Image.FORMAT_RGBA8)
 pixels.generate_mipmaps()
 var texture=ImageTexture.create_from_image(pixels)
 cache[path]=texture
 return texture
