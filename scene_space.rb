module Scenes

  class SpaceScene < BasicScene
    attr_reader :space, :particle_system, :connection_manager, :modules, :font
    def initialize(window)
      super
      
      @mount_point_image = Gosu::Image.new(window, "media/mount_point.png", false)

      @font = Gosu::Font.new(window, Gosu::default_font_name, 20)
      
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
        @modules.each do |mod|
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
      
      @modules = []
      @remove_queue = []
      
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
      
      scheme = YAML::load_file('ship.yaml')
            
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
        #if scheme[:triggers].is_a? Array
          scheme[:triggers].each_pair do |trigger, function|
            if !function.is_a? Hash
              module_triggers[trigger] = {:function => function}
            else
              module_triggers[trigger] = function
            end
          end
        #else
        #  module_triggers = scheme[:triggers]
        #end
      else
        module_triggers = {} #Gosu::KbW
      end
      
      module_entity = module_class.new(self, module_x, module_y, module_angle, module_triggers)
      
      if parent != nil and mount_point != nil and scheme[:mount_on] != nil
        parent_loc = parent.shape.body.local2world(parent.mount_points[mount_point])
        module_entity.shape.body.p = parent_loc - module_entity.mount_points[scheme[:mount_on]].rotate(module_entity.shape.body.rot)
        module_entity.add_data({:parent_mount_point => mount_point, :mount_on => scheme[:mount_on]})
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
    
    def save_to_scheme(entity)
      entity.to_scheme
    end

    def update
      # Step the physics environment SUBSTEPS times each update
      SUBSTEPS.times do     
        clean_remove_queue
        
        @modules.each do |mod|
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
      
      @font.draw("Particles: #{particle_system.particle_count}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xffffff00)
      
      @font.draw("#{@modules[0].shape.body.p}", 10, 24, ZOrder::UI, 1.0, 1.0, 0xffffff00)
      
      #@font.draw("X", @window.mouse_x, @window.mouse_y, ZOrder::UI, 1.0, 1.0, 0xffffff00)
      
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
      case id
      when Gosu::KbE
        @window.start_scene(Scenes::ShipEditorScene.new(@window, self))
      when Gosu::KbB
        scheme = @cockpit.to_scheme
        File.open('ship.yaml', 'w') do |out|
          YAML.dump(scheme, out)
        end
      when Gosu::KbN
        scheme = YAML::load_file('ship.yaml')
        @cockpit = build_from_scheme(scheme)
      when Gosu::KbEscape
        @window.close
      when Gosu::KbV
        @modules.each do |mod|
          mod.shape.body.velocity_func() { |body, gravity, damping, dt|
            body.update_velocity(gravity, 0.995, dt)
          }
        end
      when Gosu::KbZ
        $debug = ($debug + 1) % 3
      when Gosu::MsLeft
        @modules << Projectiles::Rocket.new(self, @window.mouse_x, @window.mouse_y, 0)
      when Gosu::MsRight
        @modules << Modules::Thruster.new(self, @window.mouse_x, @window.mouse_y, 0)
      else
        @cockpit.start_trigger(id, true)
      end
    end
    
    def button_up(id)
      case id
      when Gosu::KbV
        @modules.each do |mod|
          mod.shape.body.velocity_func()
        end
      else
        @cockpit.start_trigger(id, false)
      end
    end
    
    def draw_debug
      @modules.each do |mod|
        @window.rotate(mod.shape.body.a.radians_to_degrees, mod.shape.body.p.x, mod.shape.body.p.y) do
          num_verts = mod.shape.num_verts
          (0...num_verts).each do |vert_i|
            x = mod.shape.body.p.x
            y = mod.shape.body.p.y
            cur = mod.shape.vert(vert_i)
            nxt = mod.shape.vert((vert_i+1)%num_verts)
            @window.draw_line(x+cur.x, y+cur.y, 0xffffff00, x+nxt.x, y+nxt.y, 0xffff00ff, ZOrder::UI)
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
        @window.draw_line(vector_a.x, vector_a.y, 0xffff0000, vector_b.x, vector_b.y, 0xff00ff00, ZOrder::UI)
      end
    end
  end

end