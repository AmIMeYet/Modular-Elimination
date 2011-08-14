module Modules
  class BasicModule
    attr_reader :shape, :mount_points, :battery, :data
    
    def initialize(scene, x, y, angle=0, triggers={}, shape_array = [], mount_points = [], mass=10.0, moment=150.0)
      @scene = scene
      @triggers = triggers
      @data = {:x => x, :y => y, :angle => angle, :compatible => true}
      
      @mount_points = []
      mount_points.each_with_index do |mp, index|
        @mount_points << MountPoint.new(mp[0], self, index, mp[1])
      end
      
      @battery = Battery.new(0)
      
      body = CP::Body.new(mass, moment)
      
      @shape = CP::Shape::Poly.new(body, shape_array, CP::Vec2.new(0,0))
      
      @shape.collision_type = :module
      
      @shape.body.p = CP::Vec2.new(x, y) # position
      @shape.body.v = CP::Vec2.new(0.0, 0.0) # velocity
      @shape.body.a = angle.degrees_to_radians
      @shape.body.object = self
      
      scene.space.add_body(body)
      scene.space.add_shape(shape)
      
      @last_power = 0.0
    end
    
    def draw_battery
      red = Gosu::Color.new(255, 255, 0, 0)
      green = Gosu::Color.new(255, 0, 255, 0)
      @scene.window.draw_quad(@shape.body.p.x, @shape.body.p.y, red, @shape.body.p.x + 6, @shape.body.p.y, red, @shape.body.p.x + 6, @shape.body.p.y + 20, red, @shape.body.p.x, @shape.body.p.y + 20, red, ZOrder::UI)
      @scene.window.draw_quad(@shape.body.p.x, @shape.body.p.y + (20 - (0.2*@battery.percentage)), green, @shape.body.p.x + 6, @shape.body.p.y + (20 - (0.2*@battery.percentage)), green, @shape.body.p.x + 6, @shape.body.p.y + 20, green, @shape.body.p.x, @shape.body.p.y + 20, green, ZOrder::UI)
      @scene.font.draw(@last_power.to_f.round(3), @shape.body.p.x, @shape.body.p.y, ZOrder::UI, 0.5, 0.5, 0xff0000ff)
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
        
        @scene.connection_manager.connections_from(self).each do |connection|
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
    
    def draw(render_depth=0)
    end    
    
    def to_scheme
      type = self.class.name.split('::').last || self.class.name
      triggers = @triggers
      mounts_arr = @scene.connection_manager.connections_from(self).map do |connection|
        {connection.to.data[:parent_mount_point] => connection.to.to_scheme}
      end
      
      mounts = {}
      
      mounts_arr.each do |hash|
        mounts.merge!(hash)
      end
      
      @data.delete(:parent_mount_point)
      
      hash = {
        :type => type,
        :triggers => triggers,
        :mounts => mounts
      }.merge(@data)
      
      return hash
    end
    
    def add_data(hash)
      @data.merge!(hash)
    end
    
    def to_s
      "#{self.class.to_s}:#{self.__id__}"
    end
  end
  
  class MountPoint
    attr_reader :p, :object, :index, :angle
    attr_accessor :s # FIXME
    def initialize(position, object, index, angle)
      @p = position
      @object = object
      @index = index
      @angle = angle
      @s = 1
    end
    
    def x
      @p.x
    end
    
    def y
      @p.y
    end
    
    def space_pos
      @object.shape.body.local2world(@p)
    end
  end
  
  class Cockpit < BasicModule
    MOUNT_POINTS = [
      [CP::Vec2.new(-25.0, 0.0), 180],
      [CP::Vec2.new(25.0, 0.0), 0],
      [CP::Vec2.new(0.0, 25.0), 90],
      [CP::Vec2.new(0.0, -25.0), -90]
    ]
    SHAPE_ARRAY = [CP::Vec2.new(-25.0, -25.0), CP::Vec2.new(-25.0, 25.0), CP::Vec2.new(25.0, 25.0), CP::Vec2.new(25.0, -25.0)]
    
    def initialize(scene, x, y, angle=0, triggers={})
      super(scene, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      set_battery(200)
      
      @image = Gosu::Image.new(scene.window, "media/cockpit.png", false)
    end
    
    def start_trigger(trigger_code, trigger_value)
      @scene.connection_manager.connections_from(self).each do |connection|
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
    
    def draw(render_depth=0)
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, render_depth+ZOrder::Player, @shape.body.a.radians_to_gosu - 90)
      draw_battery
    end
  end

  class Tube < BasicModule
    MOUNT_POINTS = [
      [CP::Vec2.new(-35.0, 0.0), 180],
      [CP::Vec2.new(35.0, 0.0), 0],
      [CP::Vec2.new(0.0, 25.0), 90],
      [CP::Vec2.new(0.0, -25.0), -90]
    ]
    SHAPE_ARRAY = [CP::Vec2.new(-35.0, -25.0), CP::Vec2.new(-35.0, 25.0), CP::Vec2.new(35.0, 25.0), CP::Vec2.new(35.0, -25.0)]
    
    def initialize(scene, x, y, angle=0, triggers={})
      super(scene, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      
      @image = Gosu::Image.new(scene.window, "media/tube.png", false)
    end
    
    def draw(render_depth=0)
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, render_depth+ZOrder::Player, @shape.body.a.radians_to_gosu - 90)
    end
  end
  
  class Thruster < BasicModule
    attr_reader :battery
    
    MOUNT_POINTS = [
      [CP::Vec2.new(0, -15.0), -90],
      [CP::Vec2.new(0, 15.0), 90],
      [CP::Vec2.new(10.0, 0), 0]
    ]
    SHAPE_ARRAY = [CP::Vec2.new(-15.0, -15.0), CP::Vec2.new(-15.0, 15.0), CP::Vec2.new(10.0, 15.0), CP::Vec2.new(10.0, -15.0)]
    THRUST_POINT = CP::Vec2.new(-10, 0)
    
    def initialize(scene, x, y, angle=0, triggers={Gosu::KbW => {:function => :thrust}})
      super(scene, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      set_battery(100)
      
      @image = Gosu::Image.new(scene.window, "media/thruster.png", false)
      
      @states = {:thrust => 0.0}
    end
    
    def thrust
      if @battery.draw_power(0.5)
        @shape.body.apply_impulse((@shape.body.a.radians_to_vec2) * 4, CP::Vec2.new(0.0, 0.0))#(@shape.body.a.radians_to_vec2 * (3000.0/SUBSTEPS))
        @states[:thrust] = 1.0
      end
    end
    
    def update
      handle_triggers
      
      if @states[:thrust] > 0
        @states[:thrust] -= 0.1
        point = @shape.body.local2world(THRUST_POINT)
        Particles::ExaustFire.new(@scene, point.x, point.y, @shape.body.a.radians_to_gosu-180) if rand(100) < 10
      end
    end
    
    def draw(render_depth=0)
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, render_depth+ZOrder::Player, @shape.body.a.radians_to_gosu, 0.5, 0.5, 1, 1)#,
       #Gosu::Color.new(255, 255, (255 - (100 * @states[:thrust])).to_i, (255 - (100 * @states[:thrust])).to_i))
      draw_battery
    end
  end
 
  class Cannon < BasicModule
    attr_reader :shape, :mount_points
    
    MOUNT_POINTS = [
      [CP::Vec2.new(0, -15.0), -90],
      [CP::Vec2.new(0, 15.0), 90],
      [CP::Vec2.new(10.0, 0), 0]
    ]
    SHAPE_ARRAY = [CP::Vec2.new(-15.0, -15.0), CP::Vec2.new(-15.0, 15.0), CP::Vec2.new(10.0, 15.0), CP::Vec2.new(10.0, -15.0)]
    THRUST_POINT = CP::Vec2.new(-30, 0)
    
    def initialize(scene, x, y, angle=0, triggers={Gosu::KbSpace => {:function => :fire}})
      super(scene, x, y, angle, triggers, SHAPE_ARRAY, MOUNT_POINTS)
      set_battery(100)
      
      @image = Gosu::Image.new(scene.window, "media/thruster.png", false)
      
      @states = {:timeout => 0.0}
    end
    
    def fire
      if @states[:timeout] <= 0.0 && @battery.draw_power(10)
        point = @shape.body.local2world(THRUST_POINT)
        @scene.modules << Projectiles::Rocket.new(@scene, point.x, point.y, @shape.body.a.radians_to_gosu+90, @shape.body.v) 
        @states[:timeout] += 10.0
      end
    end
    
    def update
      handle_triggers
      @states[:timeout] -= 0.1 if @states[:timeout] > 0
    end
    
    def draw(render_depth=0)
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, render_depth+ZOrder::Player, @shape.body.a.radians_to_gosu)
      draw_battery
    end
  end
end
