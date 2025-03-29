struct Constants {
	dpi: f32,
	mvp: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> constants: Constants;

struct Shape {
	position:     vec2<f32>,
	size:         vec2<f32>,
	rounding:     vec4<f32>,
	color:        vec4<f32>,
	border_width: vec4<f32>,
};

@group(0) @binding(1) var<storage, read> shapes: array<Shape>;

struct Vertex_Output {
	@builtin(position)              position:     vec4<f32>,
	@location(0)                    rounding:     vec4<f32>,
	@location(1)                    color:        vec4<f32>,
	@location(2)                    uv:           vec2<f32>,
	@location(3)                    size:         vec2<f32>,
	@location(4)                    border_width: vec4<f32>,
	@location(5) @interpolate(flat) t:            u32,
};

@vertex 
fn vs(@builtin(vertex_index) vertex_index: u32, @builtin(instance_index) instance_index: u32) -> Vertex_Output {
	let shape = shapes[instance_index];

	let local_pos = array<vec2<f32>, 4>(
		vec2(0, 0),
		vec2(0, 1),
		vec2(1, 0),
		vec2(1, 1),
	);

	let screen_pos = shape.position + local_pos[vertex_index] * shape.size;

	var out: Vertex_Output;

	out.position = constants.mvp * vec4(screen_pos, 0, 1);

	out.rounding = shape.rounding * constants.dpi;
	out.uv = shape.position * constants.dpi;
	out.size = shape.size * constants.dpi;
	out.border_width = shape.border_width * constants.dpi;

	out.color = shape.color;
	out.t = u32(-shape.border_width.x);
	return out;
}

@fragment 
fn ps(in: Vertex_Output) -> @location(0) vec4<f32> {
	var d: f32;

	if in.t == 1 {
		d = sdf_circle(in.position.xy - in.uv, in.size.x);
	} else if in.t == 2 {
		let center = in.uv + in.size * .5;
		d = sdf_rectangle(in.position.xy - center, in.size, in.rounding);
	} else {
		let center = in.uv + in.size * .5;
		d = sdf_rectangle_outline(in.position.xy - center, in.size, in.rounding, in.border_width);
	}

	d = smoothstep(0.02, 0.03, d);
	d = saturate(1 - d);
	return d * in.color;
}

fn sdf_circle(position: vec2<f32>, radius: f32) -> f32 {
	return length(position) - radius;
}

fn sdf_rectangle(p: vec2<f32>, dimensions: vec2<f32>, rounding: vec4<f32>) -> f32 {
	let rounding_horizontal = select(rounding.wx, rounding.zy, p.x > 0);
	let rounding_final = select(rounding_horizontal.y, rounding_horizontal.x, p.y > 0);

	let d = abs(p) - dimensions * .5 + rounding_final;
	return length(max(d, vec2(0.))) + min(max(d.x, d.y), 0.) - rounding_final;
}

fn sdf_rectangle_outline(p: vec2<f32>, dimensions: vec2<f32>, rounding: vec4<f32>, thickness: vec4<f32>) -> f32 {
    let rounding_horizontal = select(rounding.wx, rounding.zy, p.x > 0);
    let rounding_final = select(rounding_horizontal.y, rounding_horizontal.x, p.y > 0);

    let d_outer = abs(p) - dimensions * .5 + rounding_final;
    let outer_dist = length(max(d_outer, vec2(0.))) + min(max(d_outer.x, d_outer.y), 0.) - rounding_final;

    let inner_dimensions = dimensions - vec2(
        select(thickness.x, thickness.y, p.x > 0),
        select(thickness.z, thickness.w, p.y > 0)
    );

    let d_inner = abs(p) - inner_dimensions * .5 + rounding_final;
    let inner_dist = length(max(d_inner, vec2(0.))) + min(max(d_inner.x, d_inner.y), 0.) - rounding_final;

    return max(outer_dist, -inner_dist);
}
