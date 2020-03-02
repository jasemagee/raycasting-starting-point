class RayCastingStartingPoint
  attr_accessor :inputs, :state, :outputs

  def tick
    init
    render_game
    process_inputs
  end

  def render_game
    render_above_below

    TINY_SCALE_X.times do |x|
      #calculate ray position and direction
      cameraX = 2.0 * x / TINY_SCALE_X - 1.0 #x-coordinate in camera space
      ray_dir_x = state.dir_x + state.plane_x * cameraX
      ray_dir_y = state.dir_y + state.plane_y * cameraX
      #which box of the map we're in
      mapX = state.pos_x.to_i
      mapY = state.pos_y.to_i

      #length of ray from current position to next x or y-side
      side_dist_x = 0.0
      side_dist_y = 0.0

      #length of ray from one x or y-side to next x or y-side
      delta_dist_x = (1 / ray_dir_x).abs
      delta_dist_y = (1 / ray_dir_y).abs
      perp_wall_dist = 0.0

      #what direction to step in x or y-direction (either +1 or -1)
      stepX = 0
      stepY = 0

      hit = 0  #was there a wall hit?
      side = 0  #was a NS or a EW wall hit?
      #calculate step and initial sideDist
      if ray_dir_x < 0
        stepX = -1
        side_dist_x = (state.pos_x - mapX) * delta_dist_x
      else
        stepX = 1
        side_dist_x = (mapX + 1.0 - state.pos_x) * delta_dist_x
      end

      if ray_dir_y < 0
        stepY = -1
        side_dist_y = (state.pos_y - mapY) * delta_dist_y
      else
        stepY = 1
        side_dist_y = (mapY + 1.0 - state.pos_y) * delta_dist_y
      end

      #perform DDA
      while hit == 0

        #jump to next map square, OR in x-direction, OR in y-direction
        if side_dist_x < side_dist_y
          side_dist_x += delta_dist_x
          mapX += stepX
          side = 0
        else
          side_dist_y += delta_dist_y
          mapY += stepY
          side = 1
        end

        #Check if ray has hit a wall
        if state.map[mapX][mapY] > 0
          hit = 1
        end
      end

      #Calculate distance projected on camera direction (Euclidean distance will give fisheye effect!)
      if side == 0
        perp_wall_dist = (mapX - state.pos_x + (1.0 - stepX) / 2.0) / ray_dir_x
      else
        perp_wall_dist = (mapY - state.pos_y + (1.0 - stepY) / 2.0) / ray_dir_y
      end

      #Calculate height of line to draw on screen
      line_height = (TINY_SCALE_Y / perp_wall_dist).to_i

      #calculate lowest and highest pixel to fill in current stripe
      draw_start = (-line_height / 2 + TINY_SCALE_Y / 2).to_i
      if draw_start < 0
        draw_start = 0
      end

      draw_end = (line_height / 2 + TINY_SCALE_Y / 2).to_i
      if draw_end >= TINY_SCALE_Y
        draw_end = TINY_SCALE_Y - 1
      end

      # calculate value of wall_x
      wall_x = 0.0 # where exactly the wall was hit
      if side == 0
        wall_x = state.pos_y + perp_wall_dist * ray_dir_y
      else
        wall_x = state.pos_x + perp_wall_dist * ray_dir_x
      end

      wall_x -= wall_x.floor # floor

      color = colour_from_index(state.map[mapX][mapY])

      #give x and y sides different brightness
      if side == 1
        color = [color[0] / 2, color[1] / 2, color[2] / 2]
      end

      outputs.lines << [
        x, draw_start,
        x, draw_end,
        color,
      ]
    end
  end

  def render_above_below
    outputs.solids << [0, 0, TINY_SCALE_X, TINY_SCALE_Y / 2, [80, 80, 80]]
    outputs.solids << [0, TINY_SCALE_Y / 2, TINY_SCALE_X, TINY_SCALE_Y / 2, 0, 0, 0]
    outputs.solids << state.stars
  end

  def process_inputs
    if inputs.keyboard.key_held.w || inputs.keyboard.key_held.up
      if state.map[(state.pos_x + state.dir_x * MOVE_SPEED)][(state.pos_y)] == 0
        state.pos_x += state.dir_x * MOVE_SPEED
      end
      if state.map[(state.pos_x)][(state.pos_y + state.dir_y * MOVE_SPEED)] == 0
        state.pos_y += state.dir_y * MOVE_SPEED
      end
    end
    #move backwards if no wall behind you
    if inputs.keyboard.key_held.s || inputs.keyboard.key_held.down
      if state.map[(state.pos_x - state.dir_x * MOVE_SPEED)][(state.pos_y)] == 0
        state.pos_x -= state.dir_x * MOVE_SPEED
      end
      if state.map[(state.pos_x)][(state.pos_y - state.dir_y * MOVE_SPEED)] == 0
        state.pos_y -= state.dir_y * MOVE_SPEED
      end
    end

    #rotate to the right
    if inputs.keyboard.key_held.e
      #both camera direction and camera plane must be rotated
      olddir_x = state.dir_x
      state.dir_x = state.dir_x * Math.cos(-ROT_SPEED) - state.dir_y * Math.sin(-ROT_SPEED)
      state.dir_y = olddir_x * Math.sin(-ROT_SPEED) + state.dir_y * Math.cos(-ROT_SPEED)
      oldplane_x = state.plane_x
      state.plane_x = state.plane_x * Math.cos(-ROT_SPEED) - state.plane_y * Math.sin(-ROT_SPEED)
      state.plane_y = oldplane_x * Math.sin(-ROT_SPEED) + state.plane_y * Math.cos(-ROT_SPEED)
    end

    #rotate to the left
    if inputs.keyboard.key_held.q

      #both camera direction and camera plane must be rotated
      olddir_x = state.dir_x
      state.dir_x = state.dir_x * Math.cos(ROT_SPEED) - state.dir_y * Math.sin(ROT_SPEED)
      state.dir_y = olddir_x * Math.sin(ROT_SPEED) + state.dir_y * Math.cos(ROT_SPEED)
      oldplane_x = state.plane_x
      state.plane_x = state.plane_x * Math.cos(ROT_SPEED) - state.plane_y * Math.sin(ROT_SPEED)
      state.plane_y = oldplane_x * Math.sin(ROT_SPEED) + state.plane_y * Math.cos(ROT_SPEED)
    end

    if inputs.keyboard.key_held.d || inputs.keyboard.key_held.right
      if state.map[(state.pos_x + state.plane_x * MOVE_SPEED)][(state.pos_y)] == 0
        state.pos_x += state.plane_x * MOVE_SPEED
      end
      if state.map[(state.pos_x)][(state.pos_y + state.plane_y * MOVE_SPEED)] == 0
        state.pos_y += state.plane_y * MOVE_SPEED
      end
    end

    if inputs.keyboard.key_held.a || inputs.keyboard.key_held.left
      if state.map[(state.pos_x - state.plane_x * MOVE_SPEED)][(state.pos_y)] == 0
        state.pos_x -= state.plane_x * MOVE_SPEED
      end
      if state.map[(state.pos_x)][(state.pos_y - state.plane_y * MOVE_SPEED)] == 0
        state.pos_y -= state.plane_y * MOVE_SPEED
      end
    end
  end

  def init
    state.stars ||= 20.map do
      [rand(TINY_SCALE_X), TINY_SCALE_Y.half + rand(TINY_SCALE_Y.half), 1, 1,
       200, 200, 200]
    end

    state.dir_x ||= -1.0
    state.dir_y ||= 0.0

    state.plane_x ||= 0.0
    state.plane_y ||= 0.66

    state.map ||= [
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      [1, 2, 0, 2, 0, 2, 0, 2, 0, 2, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 2, 0, 5, 0, 2, 0, 2, 0, 2, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 2, 0, 2, 0, 2, 0, 2, 0, 2, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 2, 0, 2, 0, 2, 0, 2, 0, 2, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 2, 0, 2, 0, 2, 0, 2, 0, 0, 1],
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    ]
    state.pos_x ||= 9.5
    state.pos_y ||= 9.5

    state.map_w ||= 11
    state.map_h ||= 11
  end

  def colour_from_index(index)
    color = RGB_Yellow
    case index
    when 1
      color = RGB_Red
    when 2
      color = RGB_Green
    when 3
      color = RGB_Blue
    when 4
      color = RGB_White
    when 5
      color = RGB_Goal
    end
    return color
  end

  TINY_RESOLUTION = 4
  TINY_SCALE_X = 1280 / TINY_RESOLUTION
  TINY_SCALE_Y = 720 / TINY_RESOLUTION

  MOVE_SPEED = 0.1
  ROT_SPEED = 0.05

  RGB_Yellow = [217, 197, 161]
  RGB_Red = [246, 32, 14]
  RGB_Green = [65, 115, 90]
  RGB_Blue = [164, 68, 57]
  RGB_White = [222, 172, 78]
  RGB_Goal = [0, 0, 255]
  RGB_Player = [255, 0, 255]
end

$ray_casting_starting_point = RayCastingStartingPoint.new

def tick(args)
  $ray_casting_starting_point.inputs = args.inputs
  $ray_casting_starting_point.state = args.state
  $ray_casting_starting_point.outputs = args.render_target(:game_view)
  $ray_casting_starting_point.tick

  args.outputs.sprites << [0, 0, RayCastingStartingPoint::TINY_RESOLUTION * 1280, RayCastingStartingPoint::TINY_RESOLUTION * 720, :game_view]
end
