struct Constants {
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
	@location(0) @interpolate(flat)                   rounding:     vec4<f32>,
	@location(1) @interpolate(flat)                   color:        vec4<f32>,
	@location(2)                    local_pos:    vec2<f32>,
	@location(3) @interpolate(flat)                   size:         vec2<f32>,
	@location(4) @interpolate(flat)                    border_width: vec4<f32>,
	@location(5)                     world_pos:    vec2<f32>,
	// @location(5) @interpolate(flat) t:            u32,
};

@vertex 
fn vs(@builtin(vertex_index) vertex_index: u32, @builtin(instance_index) instance_index: u32) -> Vertex_Output {
	let shape = shapes[instance_index];

	// // TODO: adjust this to actual size instead of just making it 2*the size of the shape.
	// let local_poss = array<vec2<f32>, 4>(
	// 	vec2(-1, -1),
	// 	vec2(-1, 2),
	// 	vec2(2, -1),
	// 	vec2(2, 2),
	// );
	let local_poss = array<vec2<f32>, 4>(
		vec2(0, 0),
		vec2(0, 1),
		vec2(1, 0),
		vec2(1, 1),
	);
	let local_pos = local_poss[vertex_index];

	let pos = shape.position;

	let world_pos = pos + local_pos * shape.size;

	var out: Vertex_Output;

	out.position = constants.mvp * vec4(world_pos, 0, 1);

	out.rounding = shape.rounding;
	out.local_pos = local_pos;
	out.size = shape.size;
	out.border_width = shape.border_width;
	out.world_pos = world_pos;

	out.color = shape.color;
	// out.t = u32(-shape.border_width.x);
	return out;
}

@fragment 
fn ps(in: Vertex_Output) -> @location(0) vec4<f32> {
	var d: f32;

	let pixel_pos = (in.local_pos - vec2(0.5)) * in.size;

	let t = u32(-in.border_width.x);
	if t == 1 {
		// NOTE: a circle is a capsule where p1 == p2
		d = sdf_circle(pixel_pos, in.size.x * .5);
	} else if t == 4 {
		d = sdf_circle_outline(pixel_pos, in.size.x * .5, in.rounding.x);
	} else if t == 2 {
		let c = cos(in.border_width.y);
		let s = sin(in.border_width.y);
		d = sdf_rectangle(
			vec2<f32>(
				c * pixel_pos.x + s * pixel_pos.y,
				c * pixel_pos.y - s * pixel_pos.x,
			),
			in.size,
			in.rounding,
		);
	} else if t == 3 {
		let p1 = in.rounding.xy;
		let p2 = in.rounding.zw;
		let radius = in.border_width.y;
		d = sdf_capsule(in.world_pos, p1, p2, radius);
	} else if t == 5 {
		let p1 = in.rounding.xy;
		let p2 = in.rounding.zw;
		let thickness = in.border_width.y;
		d = sdf_segment(in.world_pos, p1, p2, thickness);
	} else {
		d = sdf_rectangle_outline(pixel_pos, in.size, in.rounding, in.border_width);
	}

	// let fw = fwidth(d) * .1;
	// d *= -1.;
	// d += fw * .5;
	// d /= fw;
	// d = saturate(d);

	// TODO: anti aliasing.
	d *= -1.;
	d = ceil(d);
	d = saturate(d);

	return d * in.color;
}

fn sdf_circle(position: vec2<f32>, radius: f32) -> f32 {
	return length(position) - radius;
}

fn sdf_circle_outline(position: vec2<f32>, radius: f32, thickness: f32) -> f32 {
	let ht = thickness * .5;
	let dist = abs(sdf_circle(position, radius - ht));
	return dist - ht;
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

fn sdf_capsule(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, radius: f32) -> f32 {
	let ba = b-a;
	let pa = p-a;
	let h = clamp(dot(pa, ba)/dot(ba, ba), 0., 1.);
	return length(pa-h*ba) - radius;
}

fn sdf_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, thickness: f32) -> f32 {
    let ba = b - a;
    let pa = p - a;
    let ba_length = length(ba);
    let ba_dir = ba / ba_length;

    // Project point onto line segment direction
    let h = clamp(dot(pa, ba_dir), 0.0, ba_length);
    let closest = a + ba_dir * h;

    // Distance to rectangle edge (thickness on both sides)
    let dist = length(p - closest) - thickness * .5;

    return dist;
}
