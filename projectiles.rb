module Projectiles
  class BasicProjectile
    
  end
  class Rocket < BasicProjectile
    attr_reader :shape, :mount_points, :data
    
    MOUNT_POINTS = []
    THRUST_POINT = CP::Vec2.new(-10, 0)
    
    def initialize(scene, x, y, angle=0, velocity=CP::Vec2::ZERO,trigger=nil)
      @scene = scene
      @trigger = trigger
      
      @mount_points = MOUNT_POINTS
      @data = {}
      
      @spawn_time = Time.now
      
      body = CP::Body.new(10.0, 150.0)
      
      shape_array = [CP::Vec2.new(-10.0, -2.5), CP::Vec2.new(-10.0, 2.5), CP::Vec2.new(10.0, 2.5), CP::Vec2.new(10.0, -2.5)]
      @shape = CP::Shape::Poly.new(body, shape_array, CP::Vec2.new(0,0))
      
      @shape.collision_type = :rocket
      
      @shape.body.p = CP::Vec2.new(x, y)
      @shape.body.v = velocity
      
      @shape.body.a = angle.degrees_to_radians
      @shape.body.object = self
      
      scene.space.add_body(body)
      scene.space.add_shape(shape)
      
      @image = scene.particle_system.gfx[:rocket]
    end
    
    def update
      if Time.now - @spawn_time < 2 # Two seconds of thrust
        @shape.body.apply_impulse(@shape.body.a.radians_to_vec2 * (30.0 / SUBSTEPS), CP::Vec2.new(0.0, 0.0))
        if rand(100) < 50
          point = @shape.body.local2world(THRUST_POINT)
          Particles::ExaustFire.new(@scene, point.x, point.y, @shape.body.a.radians_to_gosu-180)
        end
      elsif Time.now - @spawn_time > 3 # One minute to live
        @scene.schedule_remove(self)
      end
    end
    
    def draw(render_depth=0)
      @image.draw_rot(@shape.body.p.x, @shape.body.p.y, ZOrder::Player, @shape.body.a.radians_to_gosu)
    end
    
    def to_s
      "Rocket:#{__id__}"
    end
  end
end
