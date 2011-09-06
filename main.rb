require 'gosu'
require 'chipmunk'
require 'yaml'

require_relative 'particles.rb'
require_relative 'projectiles.rb'
require_relative 'modules.rb'
require_relative 'ship.rb'
require_relative 'scene_basic.rb'
require_relative 'scene_space.rb'
require_relative 'scene_ship_editor.rb'
#require_relative 'deprecated_player.rb' #FIXME

SCREEN_WIDTH = 640
SCREEN_HEIGHT = 480

# The number of steps to process every Gosu update
# The Player ship can get going so fast as to "move through" a
# star without triggering a collision; an increased number of
# Chipmunk step calls per update will effectively avoid this issue
SUBSTEPS = 3

$debug = 1

# Convenience method for converting from radians to a Vec2 vector.
class Numeric
  def radians_to_vec2
    CP::Vec2.new(Math::cos(self), Math::sin(self))
  end
  
  def cap(max)
    return max if self > max
    return self
  end
end

# Layering of sprites
module ZOrder
  Background, Particles, Player, UI = *0..4
end

class Battery
  attr_reader :level, :capacity

  def initialize(capacity, level=nil)
    set(capacity, level)
  end
  
  def set(capacity, level=nil)
    @capacity = capacity
    
    @level = level
    @level ||= @capacity # Set battery to full if not specified otherwise
  end
  
  def add_power(power)
    if @level + power <= @capacity
      @level = @level + power
    else
      @level = @capacity
    end
  end
  
  def draw_power(power, priority=0)
    npower = power * (1.0/(priority+1))
    if @level - npower >= 0 # If we have any power to give
      @level -= npower # Give it!
      #p "#{power}->#{npower} : #{priority}"
      return npower
    else # There's not enough power
      #p "LOW POWER draw #{npower} (#{@capacity})"
      return nil
    end
  end
  
  def full?
    (@level >= @capacity)
  end
  
  def percentage
    ((@level.to_f/@capacity.to_f)*100.0).to_i
  end
end

class Connection
  def initialize(scene, anchr_a, anchr_b)
    @scene = scene
    
    @constraints = []
    
    @anchr_a = anchr_a
    @anchr_b = anchr_b
    
    ##constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(0, 0), CP::Vec2.new(10, 0))
    ##@constraints << constraint
    ##@scene.space.add_constraint(constraint)
    
    ##constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(10, 0), CP::Vec2.new(0, 0))
    ##@constraints << constraint
    ##@scene.space.add_constraint(constraint)
    
    ##constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(0, 0), CP::Vec2.new(0, 10))
    ##@constraints << constraint
    ##@scene.space.add_constraint(constraint)
=begin    
    constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(0, 10), CP::Vec2.new(10, 0))
    @constraints << constraint
    @scene.space.add_constraint(constraint)
    
    constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(0, -10), CP::Vec2.new(-10, 10))
    @constraints << constraint
    @scene.space.add_constraint(constraint)
=end
    
    #constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(0, 0), CP::Vec2.new(0, 0))
    #@constraints << constraint
    #@scene.space.add_constraint(constraint)
    
    #constraint = CP::Constraint::GearJoint.new(anchr_a.shape.body, anchr_b.shape.body,  @anchr_b.shape.body.a - @anchr_a.shape.body.a, 1.0)
    #@constraints << constraint
    #@scene.space.add_constraint(constraint)
  end
  
  def trigger(trigger_code, trigger_value)
    @anchr_b.trigger(trigger_code, trigger_value)
    @scene.connection_manager.connections_from(@anchr_b).each do |connection|
      connection.trigger(trigger_code, trigger_value)
    end
  end
  
  def test_loop(id=nil)
    if id==nil
      id = @anchr_a.__id__
      @scene.connection_manager.connections_from(@anchr_b).each do |connection|
        connection.test_loop(id)
      end
      #p "Starting for #{id}"
    elsif id && id != @anchr_a.__id__
      @scene.connection_manager.connections_from(@anchr_b).each do |connection|
        connection.test_loop(id)
      end
      #p "#{@anchr_a.__id__} clean for #{id}"
    else
      p "Loop detected at #{self.to_s}"
    end
  end
  
  def remove    
    @constraints.each do |constraint|
      @scene.space.remove_constraint(constraint)
    end
    @constraints.clear
  end
  
  def uses? object
    (@anchr_a == object || @anchr_b == object)
  end
  
  def connects? object_a, object_b
    (@anchr_a == object_a && @anchr_b == object_b)
  end
  
  def from? object
    (@anchr_a == object)
  end
  
  def from
    @anchr_a
  end
  
  def to? object
    (@anchr_b == object)
  end
  
  def to
    @anchr_b
  end
  
  def to_s
    "#<Connection:#{__id__} a:#{@anchr_a.to_s} b:#{@anchr_b.to_s}>"
  end
end

class ConnectionManager
  def initialize(scene)
    @scene = scene
    
    @connections = []
  end
  
  def connect(object_a, object_b)
    add_connection(Connection.new(@scene, object_a, object_b))
  end
  
  def disconnect(object_a, object_b)
    remove_connections(@connections.dup.delete_if do |connection|
      !connection.connects? object_a, object_b
    end)
  end
  
  def add_connection(connection)
    @connections << connection
  end
  
  def remove_connection(connection)
    connection.remove
    @connections.delete(connection)
  end
  
  def remove_connections(connections)
    connections.each do |connection|
      remove_connection(connection)
      p "removed connection"
    end
  end
  
  def connections_for(object)
    @connections.reject do |connection|
      (!connection.uses? object)
    end
  end
  
  def remove_for_object(object)
    connections_for(object).each do |connection|
      remove_connection(connection)
    end
  end
  
  def connections_from(object)
    @connections.reject do |connection|
      (!connection.from? object)
    end
  end
end

class ParticleSystem
  attr_reader :gfx
  def initialize(scene)
    @scene = scene
    
    @gfx = {
      :rocket => Gosu::Image.new(scene.window, "media/rocket.png", false),
      :fireball => Gosu::Image.new(scene.window,"media/fireball.png", false)
    }
    
    @particles = []
  end
  
  def add_particle(particle)
    @particles << particle
  end
  
  def remove_particle(particle)
    @particles.delete(particle)
  end
  
  def particle_count
    @particles.length
  end
  
  def update
    @particles.each do |particle|
      particle.update
    end
  end
  
  def draw
    @particles.each do |particle|
      particle.draw
    end
  end
end

class CP::Space
  attr_reader :cp_constraints
  alias :add_constraint_old :add_constraint
  alias :remove_constraint_old :remove_constraint
  attr_reader :cp_shapes
  alias :add_shape_old :add_shape
  alias :remove_shape_old :remove_shape
  
  def add_constraint(constraint)
    @cp_constraints ||= []
    @cp_constraints << constraint
    add_constraint_old(constraint)
  end
  
  def remove_constraint(constraint)
    @cp_constraints.delete(constraint) if @cp_constraints && @cp_constraints.include?(constraint)
    remove_constraint_old(constraint)
  end
  
  def add_shape(shape)
    @cp_shapes ||= []
    @cp_shapes << shape
    add_shape_old(shape)
  end
  
  def remove_shape(shape)
    @cp_shapes.delete(shape) if @cp_shapes && @cp_shapes.include?(shape)
    remove_shape_old(shape)
  end
end

class Camera
  def initialize(scene, x, y, angle=0, scale_x=1, scale_y=1)
    @window = scene.window
    @pos = CP::Vec2.new(x, y)
    #@x = x
    #@y = y
    @angle = angle
    @scale_x = scale_x
    @scale_y = scale_y
    @body = nil
  end
  
  def update
    if @body
      @pos = @pos.lerp(@body.p, 0.05)
    end
  end
  
  def draw(&drawing_code)
    @window.scale(1/@scale_x, 1/@scale_y) do
      @window.translate ((SCREEN_WIDTH/2) * @scale_x) - @pos.x, ((SCREEN_HEIGHT/2) * @scale_y) - @pos.y do
        yield
      end
    end
  end
  
  def track(body)
    @body = body
  end
  
  def x
    @pos.x
  end
  
  def y
    @pos.y
  end
  
  def mouse_x
    (@window.mouse_x * @scale_x) - ((SCREEN_WIDTH/2) * @scale_x) + (@pos.x )
  end
  
  def mouse_y
    (@window.mouse_y * @scale_y) - ((SCREEN_HEIGHT/2) * @scale_y) + (@pos.y )
  end
  
  def zoomout
    @scale_x *= 1.1
    @scale_y *= 1.1
  end
  
  def zoomin(x, y)
    @scale_x *= 0.9
    @scale_y *= 0.9
  end
end

class GameWindow < Gosu::Window  
  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 16)
    self.caption = "Modular Elimination"
    
    @scenes = []
    
    @scenes << Scenes::SpaceScene.new(self)
  end
  
  def update
    @scenes.last.update
  end
  
  def draw
    @scenes.last.draw
  end
  
  def needs_cursor?
    return true
  end
  
  def button_up(id)
    @scenes.last.button_up(id)
  end
  
  def button_down(id)
    @scenes.last.button_down(id)
  end
  
  def start_scene(scene)
    @scenes << scene
    scene.depth = @scenes.length-1
  end
  
  def end_scene
    @scenes.pop
  end
end

window = GameWindow.new
window.show