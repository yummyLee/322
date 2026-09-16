@tool
extends CompositorEffect
## Copy this camera's depth to a GPU texture; never change its color or lighting.
signal texture_ready(texture: Texture2DRD)

class DepthTexture extends Texture2DRD:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			var handle := texture_rd_rid
			texture_rd_rid = RID()
			if handle.is_valid():
				RenderingServer.get_rendering_device().free_rid(handle)

const COPY_DEPTH := """
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0, binding=0) uniform sampler2D scene_depth;
layout(r32f, set=0, binding=1) uniform writeonly image2D output_depth;
void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(p, imageSize(output_depth)))) return;
    imageStore(output_depth, p, vec4(texelFetch(scene_depth, p, 0).r));
}
"""

var published_texture: Texture2DRD
var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID
var _output: DepthTexture
var _size := Vector2i.ZERO

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true
	_rd = RenderingServer.get_rendering_device()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		if _shader.is_valid():
			_rd.free_rid(_shader)
		if _sampler.is_valid():
			_rd.free_rid(_sampler)

func _publish(texture: Texture2DRD) -> void:
	# Bind a NEW resource on the main thread. Never mutate a texture that a canvas
	# material already uses from inside a render callback (including during resize).
	published_texture = texture
	texture_ready.emit(texture)

func _render_callback(callback_type: int, data: RenderData) -> void:
	if not _rd or callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not buffers:
		return
	var dimensions := buffers.get_internal_size()
	if dimensions.x < 1 or dimensions.y < 1:
		return
	if not _shader.is_valid():
		var source := RDShaderSource.new()
		source.source_compute = COPY_DEPTH
		var spirv := _rd.shader_compile_spirv_from_source(source)
		if not spirv.compile_error_compute.is_empty():
			push_error(spirv.compile_error_compute)
			return
		_shader = _rd.shader_create_from_spirv(spirv)
		_pipeline = _rd.compute_pipeline_create(_shader)
		_sampler = _rd.sampler_create(RDSamplerState.new())
	if dimensions != _size:
		var format := RDTextureFormat.new()
		format.width = dimensions.x
		format.height = dimensions.y
		format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
		format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		_output = DepthTexture.new()
		_output.texture_rd_rid = _rd.texture_create(format, RDTextureView.new())
		_size = dimensions
		_publish.call_deferred(_output)
	var input := RDUniform.new()
	input.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	input.binding = 0
	input.add_id(_sampler)
	input.add_id(buffers.get_depth_layer(0))
	var output := RDUniform.new()
	output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output.binding = 1
	output.add_id(_output.texture_rd_rid)
	var uniforms := UniformSetCacheRD.get_cache(_shader, 0, [input, output])
	var commands := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(commands, _pipeline)
	_rd.compute_list_bind_uniform_set(commands, uniforms, 0)
	_rd.compute_list_dispatch(commands, ceili(dimensions.x/8.0), ceili(dimensions.y/8.0), 1)
	_rd.compute_list_end()
