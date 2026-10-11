# Build profile for a smaller Godot Android export template.
# Used by .github/workflows/android.yml:  scons platform=android profile=<this file> ...
# Only features the game does not use are switched off. If a new feature needs one
# of these modules (e.g. navigation or video), re-enable it here.

# Note: target and arch are passed on the scons command line (profiles can't set them).
optimize = "size"
lto = "thin"
debug_symbols = "no"

# The game uses the Compatibility (OpenGL) renderer, so Vulkan is not needed.
vulkan = "no"
module_glslang_enabled = "no"

# Simpler text server: enough for English-style scripts, much smaller.
module_text_server_adv_enabled = "no"
module_text_server_fb_enabled = "yes"
module_msdfgen_enabled = "no"

# Unused features
module_openxr_enabled = "no"
module_webxr_enabled = "no"
module_mobile_vr_enabled = "no"
module_mono_enabled = "no"
module_webrtc_enabled = "no"
module_websocket_enabled = "no"
module_upnp_enabled = "no"
module_enet_enabled = "no"
module_multiplayer_enabled = "no"
module_jsonrpc_enabled = "no"
module_theora_enabled = "no"
module_mp3_enabled = "no"
module_interactive_music_enabled = "no"
module_csg_enabled = "no"
module_gridmap_enabled = "no"
module_navigation_2d_enabled = "no"
module_navigation_3d_enabled = "no"
module_lightmapper_rd_enabled = "no"
module_xatlas_unwrap_enabled = "no"
module_vhacd_enabled = "no"
module_raycast_enabled = "no"
module_camera_enabled = "no"
module_gltf_enabled = "no"
module_fbx_enabled = "no"
module_visual_shader_enabled = "no"
module_objectdb_profiler_enabled = "no"
module_meshoptimizer_enabled = "no"
module_basis_universal_enabled = "no"
module_ktx_enabled = "no"
module_tinyexr_enabled = "no"
module_hdr_enabled = "no"
module_tga_enabled = "no"
module_svg_enabled = "no"
module_cvtt_enabled = "no"
module_betsy_enabled = "no"
module_etcpak_enabled = "no"
