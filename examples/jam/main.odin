package main

import "core:image/png"
import "core:fmt"
import "core:math/linalg"
import "core:image"
import "core:slice"
import "core:math/rand"
import "core:math"
import nais "../.."

// MVP:
// - bird (sprite, follow player (last known loc))
// - grain
// - play area bounds
// - slower underground
// - points (grain collected)
// - timer
// - menus
// - better character controller

SPRITE_SIZE :: 16
SPRITE_OFF  :: SPRITE_SIZE + 1

MAP_WIDTH  :: 16
MAP_HEIGHT :: 33

MAP_WIDTH_PIXELS  :: MAP_WIDTH  * SPRITE_SIZE
MAP_HEIGHT_PIXELS :: MAP_HEIGHT * SPRITE_SIZE

MOVE_CD :: .25

MAP := [MAP_HEIGHT][MAP_WIDTH]Tile_Type{
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{.Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass, .Grass},
	{},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
	{.Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt, .Dirt},
}

v2  :: [2]f32
v2i :: [2]int

Input :: struct {
	up, right, down, left: bool,
	jump: bool,
}

State :: struct {
	tiles:   #sparse [Tile_Type]nais.Sprite,
	player:  Entity,
	input:   Input,
}

Entity :: struct {
	sprite:      nais.Sprite,
	position:    v2,
	move_cd:     f32,
	idle_cd:     f32,
	jump_charge: f32,
}

Tile_Type :: enum {
	None,

	Player_Left = -1,
	Player_Right = -2,
	Player_Crouch = -3,
	Player_Crouch_Up = -4,
	Player_Up = -5,

	Dig_One = -6,
	Dig_Two = -7,
	Dig_Three = -8,
	Dig_Four = -9,

	Grass = 5,
	Dirt = 6,
	Pebbled_Grass = 66,

	// Water_Top_Left = 2,
	// Water_Top = 3,
	// Water_Top_Right = 4,
	// Water_Left = 59,
	// Water_Center = 60,
	// Water_Right = 61,
	// Water_Bottom_Left = 116,
	// Water_Bottom = 117,
	// Water_Bottom_Right = 118,
	// Water_Bottom_Right_Corner = 57,
	// Water_Top_Left_Corner = 115,
	// Water_Bottom_Left_Corner = 58,

	// Board = 851,
}

g: State

main :: proc() {
	nais.run("Jam", {800, 800}, {.VSync, .Windowed_Fullscreen}, proc(event: nais.Event) {
		#partial switch e in event {
		case nais.Initialized: initialize()
		case nais.Frame:       frame(e.dt)
		case nais.Input:       input(e.key, e.action)
		case nais.Resize:      update_camera()
		}
	})
}

initialize :: proc() {

	load_sprite :: proc(img: ^png.Image, x, y: int) -> nais.Sprite {
		sprite, merr := make([dynamic][4]u8, 0, SPRITE_SIZE * SPRITE_SIZE)
		assert(merr == nil)

		for i in 0..<SPRITE_SIZE {
			start := (x*4)+((y+i)*img.width*4)
			row   := img.pixels.buf[start:][:SPRITE_SIZE*4]
			pxs   := slice.reinterpret([][4]u8, row)
			for &px in pxs { px = px.bgra }

			append(&sprite, ..pxs)
		}

		return nais.load_sprite_from_pixels(sprite[:], SPRITE_SIZE)
	}

	// uerr := json.unmarshal(#load("resources/map.ldtk"), &g.ldtk)
	// fmt.assertf(uerr == nil, "map unmarshal: %v", uerr)

	ground := #load("resources/ground.png")
	img, err := png.load_from_bytes(ground)
	assert(err == nil)
	assert(img.channels == 4)
	ok := image.premultiply_alpha(img)
	assert(ok)

	player := #load("resources/player.png")
	pimg, perr := png.load_from_bytes(player)
	assert(perr == nil)
	assert(pimg.channels == 4)
	image.premultiply_alpha(pimg)

	dig := #load("resources/dig.png")
	dimg, derr := png.load_from_bytes(dig)
	assert(derr == nil)
	assert(dimg.channels == 4)
	image.premultiply_alpha(dimg)

	g.tiles = {
		.None = {},

		.Dig_One   = load_sprite(dimg, 0*SPRITE_OFF, 0*SPRITE_OFF),
		.Dig_Two   = load_sprite(dimg, 1*SPRITE_OFF, 0*SPRITE_OFF),
		.Dig_Three = load_sprite(dimg, 2*SPRITE_OFF, 0*SPRITE_OFF),
		.Dig_Four  = load_sprite(dimg, 3*SPRITE_OFF, 0*SPRITE_OFF),

		.Player_Left      = load_sprite(pimg, 0*SPRITE_OFF, 0*SPRITE_OFF),
		.Player_Right     = load_sprite(pimg, 1*SPRITE_OFF, 0*SPRITE_OFF),
		.Player_Crouch    = load_sprite(pimg, 2*SPRITE_OFF, 0*SPRITE_OFF),
		.Player_Crouch_Up = load_sprite(pimg, 3*SPRITE_OFF, 0*SPRITE_OFF),
		.Player_Up        = load_sprite(pimg, 4*SPRITE_OFF, 0*SPRITE_OFF),

		.Grass         = load_sprite(img, 1*SPRITE_OFF, 0*SPRITE_OFF),
		.Dirt          = load_sprite(img, 0*SPRITE_OFF, 0*SPRITE_OFF),
		.Pebbled_Grass = load_sprite(img, 2*SPRITE_OFF, 0*SPRITE_OFF),
	}

	g.player = {
		sprite   = g.tiles[.Player_Right],
		position = SPRITE_SIZE/2,
	}

	update_camera()
}

update_camera :: proc() {
	wsz := nais.window_size()

	pxy := v2{MAP_WIDTH_PIXELS, MAP_HEIGHT_PIXELS}

	zoom_xy := wsz / pxy
	zoom := min(zoom_xy.x, zoom_xy.y)

	off := (wsz - pxy * zoom) / 2

	c := nais.Camera{zoom=zoom, target=off}

	nais.camera_set(c)
}

input :: proc(key: nais.Key, action: nais.Key_Action) {
	fmt.println(key, action)

	state := action == .Pressed
	#partial switch key {
	case .Up:    g.input.up    = state
	case .Right: g.input.right = state
	case .Down:  g.input.down  = state
	case .Left:  g.input.left  = state
	case .Space: g.input.jump  = state
	}
}

opposite_tile :: proc(y: f32) -> f32 {
	middle := f32(MAP_HEIGHT) / 2
	if y > middle {
		return y - math.round(middle)
	} else {
		return y + math.round(middle)
	}
}

update_player :: proc(dt: f32) {
	if g.player.move_cd <= 0 {
		if g.input.jump {
			g.player.jump_charge += dt

			if g.player.idle_cd <= 0 {
				g.player.sprite = rand.choice([]nais.Sprite{g.tiles[.Player_Up], g.tiles[.Player_Crouch_Up]})
				g.player.idle_cd = .1
			} else {
				g.player.idle_cd -= dt
			}

			if g.player.jump_charge >= 1 {
				g.input.jump = true
				g.player.jump_charge = 0
				g.player.position.y = opposite_tile(g.player.position.y)
			}
		} else {
			g.player.jump_charge = 0

			if g.player.idle_cd <= 0 {
				g.player.sprite = rand.choice([]nais.Sprite{g.tiles[.Player_Right], g.tiles[.Player_Crouch]})
				g.player.idle_cd = .2
			} else {
				g.player.idle_cd -= dt
			}

			if g.input.up {
				g.player.position.y -= 1
				g.player.move_cd = MOVE_CD
				g.input.up = false
			} else if g.input.right {
				g.player.position.x += 1
				g.player.move_cd = MOVE_CD
				g.player.sprite = g.tiles[.Player_Right]
				g.input.right = false
			} else if g.input.down {
				g.player.position.y += 1
				g.player.move_cd = MOVE_CD
				g.input.down = false
			} else if g.input.left {
				g.player.position.x -= 1
				g.player.move_cd = MOVE_CD
				g.player.sprite = g.tiles[.Player_Left]
				g.input.left = false
			}
		}
	} else {
		g.player.move_cd -= dt
	}
}

draw_player :: proc() {
	// Shadow.
	nais.draw_rectangle(g.player.position*SPRITE_SIZE + {2, SPRITE_SIZE-1}, {SPRITE_SIZE-4, 3}, 0x33000000)
	nais.draw_rectangle(g.player.position*SPRITE_SIZE + {1, SPRITE_SIZE}, {1, 1}, 0x33000000)
	nais.draw_rectangle(g.player.position*SPRITE_SIZE + {SPRITE_SIZE-2, SPRITE_SIZE}, {1, 1}, 0x33000000)

	// Player.
	nais.draw_sprite(g.player.sprite, g.player.position*SPRITE_SIZE)

	// Dig indicator on opposite side.
	opposite := v2i{int(g.player.position.x), int(opposite_tile(g.player.position.y))}
	spos := linalg.to_f32(opposite)*SPRITE_SIZE
	if g.player.jump_charge > .75 {
		nais.draw_sprite(g.tiles[.Dig_Four], spos)
	} else if g.player.jump_charge > .50 {
		nais.draw_sprite(g.tiles[.Dig_Three], spos)
	} else if g.player.jump_charge > .25 {
		nais.draw_sprite(g.tiles[.Dig_Two], spos)
	} else {
		nais.draw_sprite(g.tiles[.Dig_One], spos)
	}
}

draw_map :: proc() {
	for row, y in MAP {
		for tile, x in row {
			if tile == .None do continue

			nais.draw_sprite(g.tiles[tile], v2{f32(x), f32(y)}*SPRITE_SIZE)
		}
	}
}

frame :: proc(dt: f32) {
	update_player(dt)

	draw_map()
	draw_player()
}
