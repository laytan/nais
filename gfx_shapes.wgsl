@group(0) @binding(0) var<uniform> transform: mat4x4<f32>;

@vertex 
fn vs(@location(0) pos: vec2<f32>) -> @builtin(position) vec4<f32> {
    return transform * vec4<f32>(pos, 0, 1);
}

@fragment 
fn ps() -> @location(0) vec4<f32> {
	return vec4<f32>(1, 0, 0, 1);
}
