require 'gosu'
require 'chipmunk'

require_relative 'particles.rb'
require_relative 'projectiles.rb'
require_relative 'modules.rb'
require_relative 'deprecated_player.rb' #FIXME

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
    
    p "Battery#{__id__} set: #{capacity} (#{level})"
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
  def initialize(window, anchr_a, anchr_b)
    @window = window
    
    @constraints = []
    
    @anchr_a = anchr_a
    @anchr_b = anchr_b
    
    constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(0, 10), CP::Vec2.new(10, 0))
    @constraints << constraint
    @window.space.add_constraint(constraint)
    
    constraint = CP::Constraint::PinJoint.new(anchr_a.shape.body, anchr_b.shape.body, CP::Vec2.new(0, -10), CP::Vec2.new(-10, 10))
    @constraints << constraint
    @window.space.add_constraint(constraint)
  end
  
  def trigger(trigger_code, trigger_value)
    @anchr_b.trigger(trigger_code, trigger_value)
    @window.connection_manager.connections_from(@anchr_b).each do |connection|
      connection.trigger(trigger_code, trigger_value)
    end
  end
  
  def test_loop(id=nil)
    if id==nil
      id = @anchr_a.__id__
      @window.connection_manager.connections_from(@anchr_b).each do |connection|
        connection.test_loop(id)
      end
      #p "Starting for #{id}"
    elsif id && id != @anchr_a.__id__
      @window.connection_manager.connections_from(@anchr_b).each do |connection|
        connection.test_loop(id)
      end
      #p "#{@anchr_a.__id__} clean for #{id}"
    else
      p "Loop detected at #{self.to_s}"
    end
  end
  
  def remove    
    @constraints.each do |constraint|
      @window.space.remove_constraint(constraint)
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
  
  def to? object
    (@anchr_b == object)
  end
  
  def to_s
    "#<Connection:#{__id__} a:#{@anchr_a.to_s} b:#{@anchr_b.to_s}>"
  end
end

class ConnectionManager
  def initialize(window)
    @window = window
    
    @connections = []
  end
  
  def connect(object_a, object_b)
    add_connection(Connection.new(@window, object_a, object_b))
  end
  
  def disconnect(object_a, object_b)
    @connections.each do |connection|
      connection.remove if connection.connects? object_a, object_b
    end
  end
  
  def add_connection(connection)
    @connections << connection
  end
  
  def remove_connection(connection)
    connection.remove
    @connections.delete(connection)
  end
  
  def remove_for_object(object)
    @connections.each do |connection|
      remove_connection(connection) if connection.uses? object
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
  def initialize(window)
    @window = window
    
    @gfx = {
      :rocket => Gosu::Image.new(window, "media/rocket.png", false)
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
  
  def add_constraint(constraint)
    @cp_constraints ||= []
    @cp_constraints << constraint
    add_constraint_old(constraint)
  end
  
  def remove_constraint(constraint)
    @cp_constraints.delete(constraint) if @cp_constraints && @cp_constraints.include?(constraint)
    remove_constraint_old(constraint)
  end
end

class GameWindow < Gosu::Window
  attr_reader :space, :particle_system, :connection_manager, :modules, :font
  
  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 16)
    self.caption = "Modular Elimination"
    
    @mount_point_image = Gosu::Image.new(self, "media/mount_point.png", false)

    @font = Gosu::Font.new(self, Gosu::default_font_name, 20)
    
    # Time increment over which to apply a physics "step" ("delta t")
    @dt = (1.0/60.0)
    
    # Create our Space and set its damping
    # A damping of 0.8 causes the ship bleed off its force and torque over time
    # This is not realistic behavior in a vacuum of space, but it gives the game
    # the feel I'd like in this situation
    @space = CP::Space.new
    @space.damping = 1.0 # 0.8
    
    @particle_system = ParticleSystem.new(self)
    @connection_manager = ConnectionManager.new(self)
    
    @space.add_collision_func(:rocket, :module) do |rocket_shape, ship_shape|
      (@modules+[@player]).each do |mod|
        next if mod.shape == rocket_shape # Don't collide with self!
        force_multiplier = 1000.0
        diff = mod.shape.body.p - rocket_shape.body.p
        length = diff.length
        dir = diff.normalize_safe
        
        mod.shape.body.apply_impulse(dir * ((1.0/length) * force_multiplier), CP::Vec2.new(0.0, 0.0))
      end
      
      schedule_remove(rocket_shape.body.object) # I'm gone!
      schedule_remove(ship_shape.body.object) #lol! FIXME
      
      false # Don't do any physics here!
    end
    
    add_player
    
    @modules = []
    @remove_queue = []

    # TODO:
    # Mini thrusters maken
    # En die dan bijvoorbeeld links boven en recht onder doen (om naar rechts te keren)
    #     ^
    #   >| |<
    #    | |
    #  v | | v
    # >==| |==<
    #   ^^^^^
    
    scheme = {
      :type => :Cockpit, 
      :mounts => {
        2 => {
          :mount_on => 3,
          :type => :Tube,
          :mounts => {
            1 => {
              :mount_on => 2,
              :type => :Thruster,
              :angle => 180,
              :triggers => {Gosu::KbD => :thrust}
            },
            0 => {
              :mount_on => 2,
              :type => :Thruster,
              :angle => 0,
              :triggers => {Gosu::KbA => :thrust}
            }
          }
        },
        0 => {
          :mount_on => 1,
          :type => :Thruster,
          :angle => -90,
          :triggers => {Gosu::KbW => :thrust},
          :mounts => {
            0 => {
              :mount_on => 2,
              :type => :Thruster,
              :angle => 0,
              :triggers => {Gosu::KbD => :thrust}
            }
          }
        },
        1 => {
          :mount_on => 0,
          :type => :Thruster,
          :angle => -90,
          :triggers => {Gosu::KbW => :thrust},
          :mounts => {
            1 => {
              :mount_on => 2,
              :type => :Thruster,
              :angle => 180,
              :triggers => {Gosu::KbA => :thrust}
            }
          }
        },
        3 => {
          :mount_on => 2,
          :type => :Cannon,
          :angle => 90,
          :triggers => {Gosu::KbS => :fire}
        }
      },
      :x => 180,
      :y => 300
    }
    
    @cockpit = build_from_scheme(scheme)
    
    @modules.each do |mod|
      @connection_manager.connections_from(mod).each do |con| con.test_loop end
    end
  end
  
  def build_from_scheme(scheme, parent=nil, mount_point=nil)
    module_class = Modules.const_get(scheme[:type].to_s)
    
    if(scheme[:x])
      module_x = scheme[:x]
    elsif parent
      module_x = parent.shape.body.p.x
    else
      module_x = SCREEN_WIDTH / 2
    end
    
    if(scheme[:y])
      module_y = scheme[:y]
    elsif parent
      module_y = parent.shape.body.p.y
    else
      module_y = SCREEN_HEIGHT / 2
    end
    
    if(scheme[:angle])
      module_angle = scheme[:angle]
    else
      module_angle = 0
    end
    
    if(scheme[:triggers])
      module_triggers = {}
      scheme[:triggers].each_pair do |trigger, function|
        module_triggers[trigger] = {:function => function}
      end
    else
      module_triggers = {} #Gosu::KbW
    end
    
    module_entity = module_class.new(self, module_x, module_y, module_angle, module_triggers)
    
    if parent != nil and mount_point != nil and scheme[:mount_on] != nil
      parent_loc = parent.shape.body.local2world(parent.mount_points[mount_point])
      module_entity.shape.body.p = parent_loc - module_entity.mount_points[scheme[:mount_on]].rotate(module_entity.shape.body.rot)
    end
    
    if scheme[:mounts]
      scheme[:mounts].each_pair do |mount_point, child_scheme|
        child = build_from_scheme(child_scheme, module_entity, mount_point)
        @connection_manager.connect(module_entity, child)
      end
    end
    
    #module_entity.shape.group = 2
    
    @modules << module_entity
    
    return module_entity
  end

  def update
    # Step the physics environment SUBSTEPS times each update
    SUBSTEPS.times do     
      clean_remove_queue
      
      (@modules+[@player]).each do |mod|
        mod.update
      end
      
      # Perform the step over @dt period of time
      # For best performance @dt should remain consistent for the game
      @space.step(@dt)
    end
    
    @particle_system.update
  end

  def draw
    @modules.each do |mod|
      mod.draw
    end
    
    @player.draw
    
    @font.draw("Particles: #{particle_system.particle_count}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xffffff00)
    
    @font.draw("#{@modules[0].shape.body.p}", 10, 24, ZOrder::UI, 1.0, 1.0, 0xffffff00)
    
    @font.draw("X", mouse_x, mouse_y, ZOrder::UI, 1.0, 1.0, 0xffffff00)
    
    @particle_system.draw
    draw_debug if $debug != 0
  end
  
  def schedule_remove(object)
    @remove_queue << object
  end
  
  def clean_remove_queue
    @remove_queue.each do |object|
      #TODO: When it is time to remove, remove all objects equally, not just Rocket!
      if object.is_a? Projectiles::Rocket
        @modules.delete object
        
        @space.remove_body(object.shape.body)
        @space.remove_shape(object.shape)
      end
      
      @connection_manager.remove_for_object(object)
    end
    
    @remove_queue.clear
  end

  def button_down(id)
    if id == Gosu::KbEscape
      close
    elsif id == Gosu::KbV
      @modules.each do |mod|
        mod.shape.body.velocity_func() { |body, gravity, damping, dt|
          body.update_velocity(gravity, 0.995, dt)
        }
      end
    elsif id == Gosu::KbZ
      $debug = ($debug + 1) % 3
    elsif id == Gosu::MsLeft
      @modules << Projectiles::Rocket.new(self, mouse_x, mouse_y, 0)
    else
      @cockpit.start_trigger(id, true)
    end
  end
  
  def button_up(id)
    if id == Gosu::KbV
      @modules.each do |mod|
        mod.shape.body.velocity_func()
      end
    else
      @cockpit.start_trigger(id, false)
    end
  end
  
  def draw_debug
    (@modules+[@player]).each do |mod|
      rotate(mod.shape.body.a.radians_to_degrees, mod.shape.body.p.x, mod.shape.body.p.y) do
        num_verts = mod.shape.num_verts
        (0...num_verts).each do |vert_i|
          x = mod.shape.body.p.x
          y = mod.shape.body.p.y
          cur = mod.shape.vert(vert_i)
          nxt = mod.shape.vert((vert_i+1)%num_verts)
          draw_line(x+cur.x, y+cur.y, 0xffffff00, x+nxt.x, y+nxt.y, 0xffff00ff, ZOrder::UI)
        end
        
        if $debug == 2
          mod.mount_points.each_with_index do |mount_point, index|
            vec = mod.shape.body.p + mount_point
            @mount_point_image.draw_rot(vec.x, vec.y, ZOrder::UI, 0)
            @font.draw(index.to_s, vec.x, vec.y, ZOrder::UI, 0.7, 0.7, 0xff0000ff)
          end
        end
      end
    end
  
    @space.cp_constraints.each do |cons|vector_a = cons.body_a.p+(cons.anchr1.rotate(cons.body_a.rot))
      vector_b = cons.body_b.p+(cons.anchr2.rotate(cons.body_b.rot))
      draw_line(vector_a.x, vector_a.y, 0xffff0000, vector_b.x, vector_b.y, 0xff00ff00, ZOrder::UI)
    end
  end
end

window = GameWindow.new
window.show
