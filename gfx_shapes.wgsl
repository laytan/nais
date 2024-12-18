@group(0) @binding(0) var<uniform> transform: mat4x4<f32>;

struct Vertex_Input {
	@location(0) pos: vec2<f32>,
	@location(1) color: u32,
}

struct Vertex_Output {
	@builtin(position) pos: vec4<f32>,
	@location(0) color: vec4<f32>,
}

@vertex 
fn vs(in: Vertex_Input) -> Vertex_Output {
	var out: Vertex_Output;
	out.pos = transform * vec4<f32>(in.pos, 0, 1);
	out.color = vec4<f32>(
		f32((in.color >> 16) & 0xff) / 255,
		f32((in.color >> 8 ) & 0xff) / 255,
		f32((in.color >> 0 ) & 0xff) / 255,
		f32((in.color >> 24) & 0xff) / 255,
	);
	return out;
}

@fragment 
fn ps(in: Vertex_Output) -> @location(0) vec4<f32> {
	return in.color;
}
