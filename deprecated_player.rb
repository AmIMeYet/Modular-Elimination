require 'gosu'

# This game will have one Player in the form of a ship
class Player
  attr_reader :shape, :mount_points
  
  MOUNT_POINTS = []

  def initialize(window, shape)
    @mount_points = MOUNT_POINTS
  
    @window = window
    
    @image = Gosu::Image.new(window, "media/Starfighter.bmp", false)
    @shape = shape
    @shape.body.p = CP::Vec2.new(0.0, 0.0) # position
    @shape.body.v = CP::Vec2.new(0.0, 0.0) # velocity
    
    # Keep in mind that down the screen is positive y, which means that PI/2 radians,
    # which you might consider the top in the traditional Trig unit circle sense is actually
    # the bottom; thus 3PI/2 is the top
    #@shape.body.a = (3*Math::PI/2.0) # angle in radians; faces towards top of screen
    
    @states = {:thrust => 0.0}
  end
  
  # Directly set the position of our Player
  def warp(vect)
    @shape.body.p = vect
  end
  
  # Apply forward force; Chipmunk will do the rest
  # SUBSTEPS is used as a divisor to keep acceleration rate constant
  # even if the number of steps per update are adjusted
  # Here we must convert the angle (facing) of the body into
  # forward momentum by creating a vector in the direction of the facing
  # and with a magnitude representing the force we want to apply
  def accelerate
    #@shape.body.apply_impulse(@shape.body.a.radians_to_vec2, CP::Vec2.new(0.0, 0.0))#(@shape.body.a.radians_to_vec2 * (3000.0/SUBSTEPS))
    @shape.body.apply_impulse((@shape.body.a.radians_to_vec2 * 4), CP::Vec2.new(0.0, 0.0))#(@shape.body.a.radians_to_vec2 * (3000.0/SUBSTEPS))
    @states[:thrust] = 1.0
  end
  
  # Apply even more forward force
  # See accelerate for more details
  def boost
    @shape.body.apply_impulse((@shape.body.a.radians_to_vec2 * 8), CP::Vec2.new(0.0, 0.0))
    @states[:thrust] = 2.0
  end
  
  # Apply reverse force
  # See accelerate for more details
  def reverse
    @shape.body.apply_impulse(-(@shape.body.a.radians_to_vec2 * 4), CP::Vec2.new(0.0, 0.0))
  end
  
  # Wrap to the other side of the screen when we fly off the edge
  def validate_position
    l_position = CP::Vec2.new(@shape.body.p.x % SCREEN_WIDTH, @shape.body.p.y % SCREEN_HEIGHT)
    @shape.body.p = l_position
  end
  
  def update
    # Wrap around the screen to the other side
    validate_position
    
    if @window.button_down? Gosu::KbUp
      if ((@window.button_down? Gosu::KbRightShift) || (@window.button_down? Gosu::KbLeftShift))
        boost
      else
        accelerate
      end
    elsif @window.button_down? Gosu::KbDown
      reverse
    end
  
    if @states[:thrust] >= 0.1
      @states[:thrust] -= 0.1
    else
      @states[:thrust] = 0.0
    end
  end
  
  def draw
    @image.draw_rot(@shape.body.p.x, @shape.body.p.y, ZOrder::Player, @shape.body.a.radians_to_gosu, 0.5, 0.5, 1, 1,
      Gosu::Color.new(255, 255, (255 - (100 * @states[:thrust])).to_i, (255 - (100 * @states[:thrust])).to_i))
  end
end

class GameWindow < Gosu::Window
  def add_player
    # Create the Body for the Player
    body = CP::Body.new(10.0, 150.0)
    
    # In order to create a shape, we must first define it
    # Chipmunk defines 3 types of Shapes: Segments, Circles and Polys
    # We'll use s simple, 4 sided Poly for our Player (ship)
    # You need to define the vectors so that the "top" of the Shape is towards 0 radians (the right)
    shape_array = [CP::Vec2.new(-25.0, -25.0), CP::Vec2.new(-25.0, 25.0), CP::Vec2.new(25.0, 1.0), CP::Vec2.new(25.0, -1.0)]
    shape = CP::Shape::Poly.new(body, shape_array, CP::Vec2.new(0,0))
    
    # The collision_type of a shape allows us to set up special collision behavior
    # based on these types.  The actual value for the collision_type is arbitrary
    # and, as long as it is consistent, will work for us; of course, it helps to have it make sense
    shape.collision_type = :ship
    
    @space.add_body(body)
    @space.add_shape(shape)

    @player = Player.new(self, shape)
    @player.shape.body.object = @player
    @player.warp(CP::Vec2.new(320, 50)) # move to the center of the window
  end
end
