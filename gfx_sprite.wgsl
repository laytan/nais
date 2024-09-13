struct Constants {
	r_texturesize:  vec2<f32>,
    transformation: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> constants: Constants;

struct Sprite_Data {
	location: vec2<f32>,
	size:     vec2<f32>,
	anchor:   vec2<f32>,
	position: vec2<f32>,
	scale:    vec2<f32>,
	rotation: f32,
	color:    u32,
}

struct Pixel_Data {
	@builtin(position)              position: vec4<f32>,
	@location(0)                    location: vec2<f32>,
	@location(1) @interpolate(flat) color:    vec4<f32>,
}

@group(0) @binding(1) var<storage, read> spritebatch: array<Sprite_Data>;

@group(0) @binding(2) var spritesheet: texture_2d<f32>;

@group(0) @binding(3) var aaptsampler: sampler;

@vertex
fn vs(@builtin(instance_index) spriteid: u32, @builtin(vertex_index) vertexid: u32) -> Pixel_Data {
	let sprite = spritebatch[spriteid];

	let idx = vec2<u32>( vertexid & 2, ((vertexid << 1) & 2) ^ 3 );

	let piv = vec4<f32>( 0, 0, sprite.size + 1) * sprite.scale.xyxy - (sprite.size * sprite.scale * sprite.anchor).xyxy;
	let pos = vec2<f32>(
		piv[idx.x] * cos(sprite.rotation) - piv[idx.y] * sin(sprite.rotation),
		piv[idx.y] * cos(sprite.rotation) + piv[idx.x] * sin(sprite.rotation)
	) + sprite.position - 0.5;

	let loc = vec4<f32>(sprite.location, sprite.location + sprite.size + 1);

	var output: Pixel_Data;

	// output.position = constants.transformation * vec4<f32>(pos * constants.rn_screensize - vec2<f32>(1, -1), 0, 1);
	output.position = constants.transformation * vec4<f32>(pos, 0, 1);
	output.location = vec2<f32>(loc[idx.x], loc[idx.y]);
	output.color    = vec4<f32>(
		f32((sprite.color >> 16) & 0xff) / 255,
		f32((sprite.color >> 8 ) & 0xff) / 255,
		f32((sprite.color >> 0 ) & 0xff) / 255,
		f32((sprite.color >> 24) & 0xff) / 255,
	);

	return output;
}

@fragment
fn ps(pixel: Pixel_Data) -> @location(0) vec4<f32> {
	let color = textureSample(
		spritesheet, aaptsampler,
		(floor(pixel.location) + min(fract(pixel.location) / fwidth(pixel.location), vec2<f32>(1)) - 0.5) * constants.r_texturesize
	) * pixel.color.a * vec4<f32>(pixel.color.rgb, 1);

	if (color.a == 0) {
		discard;
	}

	return color;
}
