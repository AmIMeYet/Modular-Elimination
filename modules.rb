module Modules
  class BasicModule
    attr_reader :shape, :mount_points, :battery, :data
    
    def initialize(window, x, y, angle=0, triggers={}, shape_array = [], mount_points = [], mass=10.0, moment=150.0)
      @window = window
      @triggers = triggers
      @data = {:x => x, :y => y, :angle => angle}
      
      @mount_points = mount_points
      @battery = Battery.new(0)
      
      body = CP::Body.new(mass, moment)
      
      @shape = CP::Shape::Poly.new(body, shape_array, CP::Vec2.new(0,0))
      
      @shape.collision_type = :module
      
      @shape.body.p = CP::Vec2.new(x, y) # position
      @shape.body.v = CP::Vec2.new(0.0, 0.0) # velocity
      @shape.body.a = angle.degrees_to_radians
      @shape.body.object = self
      
      window.space.add_body(body)
      window.space.add_shape(shape)
      
      @last_power = 0.0
    end
    
    def set_battery(capacity, level=nil)
      @battery.set(capacity, level)
    end
    
    def trigger(trigger_code, trigger_value)
      if trigger_code == :POWER_SOURCE
        if !@battery.full?
          power = trigger_value.draw_power((@battery.capacity-@battery.level).cap(5), @battery.percentage)
          @battery.add_power(power) if power
          @last_power = power
        end
      else
        if @triggers.has_key? trigger_code
          @triggers[trigger_code][:value] = trigger_value
        end
        
        @window.connection_manager.connections_from(self).each do |connection|
          connection.trigger(trigger_code, trigger_value)
        end
      end
    end
    
    def handle_triggers
      @triggers.each_value do |trig|
        self.send(trig[:function])  if trig[:value] == true
      end
    end
    
    def update
    end
    
    def draw
    end
=begin    
y = {:type => :Cockpit, 
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
                heb nu:
                :triggers => {Gosu::KbA => {:function => :thrust}}
              }
            }
          }
        }
      }
=end
    
    
    def to_scheme
      type = self.class.name.split('::').last || self.class.name
      triggers = @triggers
      mounts_arr = @window.connection_manager.connections_from(self).map do |connection|
        {connection.to.data[:parent_mount_point] => connection.to.to_scheme}
      end
      
      mounts = {}
      
      mounts_arr.each do |hash|
        mounts.merge!(hash)
      end
      
      
      #mount_on
      #angle
      
      @data.delete(:parent_mount_point)
      
      hash = {
        :type => type,
        :triggers => triggers,
        :mounts => mounts
      }.merge(@data)
      
      return hash
      
      #return "#{type} + #{triggers} + #{mounts}"
    end
    
    def add_data(hash)
      @data.merge!(hash)
    end
    
    def to_s
      "#{self.class.to_s}:#{self.__id__}"
    end
  end
  
  class Cockpit < BasicModule
    #attr_reader :battery
    MOUNT_POINTS = [CP::Vec2.new(-25.0, 0.0), CP::Vec2.new(25.0, 0.0), CP::Vec2.new(0.0, 25.0), CP::Vec2.new(0.0, -25.0)]
    SHAPE_ARRAY = [CP::Vec2.new(-25.0, -25.0), CP::Vec2.new(-25.0, 25.0), CP::Vec2.new(25.0, 25.0), CP::Vec2.new(25.0, -25.0)]
    
    def initialize(window, x, y, angle=0, triggers={})
      super(window, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      set_battery(200)
      
      @image = Gosu::Image.new(window, "media/cockpit.png", false)
    end
    
    def start_trigger(trigger_code, trigger_value)
      @window.connection_manager.connections_from(self).each do |connection|
        connection.trigger(trigger_code, trigger_value)
      end
    end
    
    def trigger(trigger_code, trigger_value)
      # It's okay for us to be triggered in a loop, but we just don't act on it.
    end
    
    def update
      generate_power
      distribute_power
    end
    
    def generate_power
      @battery.add_power(2)
    end
    
    def distribute_power
      start_trigger(:POWER_SOURCE, @battery) if @battery.percentage > 2
    end
    
    def draw()
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, ZOrder::Player, @shape.body.a.radians_to_gosu - 90)
      red = Gosu::Color.new(255, 255, 0, 0)
      green = Gosu::Color.new(255, 0, 255, 0)
      @window.draw_quad(@shape.body.p.x, @shape.body.p.y, red, @shape.body.p.x + 10, @shape.body.p.y, red, @shape.body.p.x + 10, @shape.body.p.y + 50, red, @shape.body.p.x, @shape.body.p.y + 50, red, ZOrder::UI)
      @window.draw_quad(@shape.body.p.x, @shape.body.p.y + (50 - (0.5*@battery.percentage)), green, @shape.body.p.x + 10, @shape.body.p.y + (50 - (0.5*@battery.percentage)), green, @shape.body.p.x + 10, @shape.body.p.y + 50, green, @shape.body.p.x, @shape.body.p.y + 50, green, ZOrder::UI)
    end
  end

  class Tube < BasicModule
    MOUNT_POINTS = [CP::Vec2.new(-35.0, 0.0), CP::Vec2.new(35.0, 0.0), CP::Vec2.new(0.0, 25.0), CP::Vec2.new(0.0, -25.0)]
    SHAPE_ARRAY = [CP::Vec2.new(-35.0, -25.0), CP::Vec2.new(-35.0, 25.0), CP::Vec2.new(35.0, 25.0), CP::Vec2.new(35.0, -25.0)]
    
    def initialize(window, x, y, angle=0, triggers={})
      super(window, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      
      @image = Gosu::Image.new(window, "media/tube.png", false)
    end
    
    def draw()
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, ZOrder::Player, @shape.body.a.radians_to_gosu - 90)
    end
  end
  
  class Thruster < BasicModule
    attr_reader :battery
    
    MOUNT_POINTS = [CP::Vec2.new(0, -15.0), CP::Vec2.new(0, 15.0), CP::Vec2.new(10.0, 0)]
    SHAPE_ARRAY = [CP::Vec2.new(-15.0, -15.0), CP::Vec2.new(-15.0, 15.0), CP::Vec2.new(10.0, 15.0), CP::Vec2.new(10.0, -15.0)]
    THRUST_POINT = CP::Vec2.new(-10, 0)
    
    def initialize(window, x, y, angle=0, triggers={Gosu::KbW => {:function => :thrust}})
      super(window, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      set_battery(100)
      
      @image = Gosu::Image.new(window, "media/thruster.png", false)
      
      @states = {:thrust => 0.0}
    end
    
    def thrust
      if @battery.draw_power(0.5)
        @shape.body.apply_impulse((@shape.body.a.radians_to_vec2), CP::Vec2.new(0.0, 0.0))#(@shape.body.a.radians_to_vec2 * (3000.0/SUBSTEPS))
        @states[:thrust] = 1.0
      end
    end
    
    def update
      handle_triggers
      
      if @states[:thrust] >= 0.1
        @states[:thrust] -= 0.1
        point = @shape.body.local2world(THRUST_POINT)
        Particles::ExaustFire.new(@window, point.x, point.y, @shape.body.a.radians_to_gosu-180) if rand(100) < 10
      else
        @states[:thrust] = 0.0
      end
    end
    
    def draw()
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, ZOrder::Player, @shape.body.a.radians_to_gosu, 0.5, 0.5, 1, 1,
       Gosu::Color.new(255, 255, (255 - (100 * @states[:thrust])).to_i, (255 - (100 * @states[:thrust])).to_i))
      red = Gosu::Color.new(255, 255, 0, 0)
      green = Gosu::Color.new(255, 0, 255, 0)
      @window.draw_quad(@shape.body.p.x, @shape.body.p.y, red, @shape.body.p.x + 10, @shape.body.p.y, red, @shape.body.p.x + 10, @shape.body.p.y + 50, red, @shape.body.p.x, @shape.body.p.y + 50, red, ZOrder::UI)
      @window.draw_quad(@shape.body.p.x, @shape.body.p.y + (50 - (0.5*@battery.percentage)), green, @shape.body.p.x + 10, @shape.body.p.y + (50 - (0.5*@battery.percentage)), green, @shape.body.p.x + 10, @shape.body.p.y + 50, green, @shape.body.p.x, @shape.body.p.y + 50, green, ZOrder::UI)
      @window.font.draw(@last_power.to_f.round(3), @shape.body.p.x, @shape.body.p.y, ZOrder::UI, 0.5, 0.5, 0xff0000ff)
    end
  end
 
  class Cannon < BasicModule
    attr_reader :shape, :mount_points
    
    MOUNT_POINTS = [CP::Vec2.new(0, -15.0), CP::Vec2.new(0, 15.0), CP::Vec2.new(10.0, 0)]
    SHAPE_ARRAY = [CP::Vec2.new(-15.0, -15.0), CP::Vec2.new(-15.0, 15.0), CP::Vec2.new(10.0, 15.0), CP::Vec2.new(10.0, -15.0)]
    THRUST_POINT = CP::Vec2.new(-30, 0)
    
    def initialize(window, x, y, angle=0, triggers={Gosu::KbSpace => {:function => :fire}})
      super(window, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      set_battery(100)
      
      @image = Gosu::Image.new(window, "media/thruster.png", false)
      
      @states = {:timeout => 0.0}
    end
    
    def fire
      if @states[:timeout] <= 0.0 && @battery.draw_power(10)
        point = @shape.body.local2world(THRUST_POINT)
        @window.modules << Projectiles::Rocket.new(@window, point.x, point.y, @shape.body.a.radians_to_gosu+90, @shape.body.v) 
        @states[:timeout] += 10.0
      end
    end
    
    def update
      handle_triggers
      @states[:timeout] -= 0.1 if @states[:timeout] > 0.0
    end
    
    def draw()
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, ZOrder::Player, @shape.body.a.radians_to_gosu)
      red = Gosu::Color.new(255, 255, 0, 0)
      green = Gosu::Color.new(255, 0, 255, 0)
      @window.draw_quad(@shape.body.p.x, @shape.body.p.y, red, @shape.body.p.x + 10, @shape.body.p.y, red, @shape.body.p.x + 10, @shape.body.p.y + 50, red, @shape.body.p.x, @shape.body.p.y + 50, red, ZOrder::UI)
      @window.draw_quad(@shape.body.p.x, @shape.body.p.y + (50 - (0.5*@battery.percentage)), green, @shape.body.p.x + 10, @shape.body.p.y + (50 - (0.5*@battery.percentage)), green, @shape.body.p.x + 10, @shape.body.p.y + 50, green, @shape.body.p.x, @shape.body.p.y + 50, green, ZOrder::UI)
      @window.font.draw(@last_power.to_f.round(3), @shape.body.p.x, @shape.body.p.y, ZOrder::UI, 0.5, 0.5, 0xff0000ff)
    end
  end
end
