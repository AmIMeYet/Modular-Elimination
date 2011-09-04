module Scenes

  class ShipEditorScene < BasicScene  
    def initialize(window, previous_scene)
      super(window)
      
      @previous_scene = previous_scene
      
      @filter = Gosu::Color.new(0xaa000000)
      @mount_point_image = Gosu::Image.new(window, "media/small_mount_point.png", false)
      @font = Gosu::Font.new(window, Gosu::default_font_name, 11)
      @font_color = Gosu::Color.new(0xff00ff00)
      
      @modules = previous_scene.modules.dup
      @modules.delete_if do |mod|
        !mod.data[:compatible]
      end
      
      @ships = previous_scene.ships.dup
      @ships.delete_if do |ship|
        #!ship.data[:compatible]
      end
      
      @selected = nil
      @selected_offset_x = 0
      @selected_offset_y = 0
      @selected_start_x = 0
      @selected_end_x = 0
      @selected_rotation = 0
      
      @mount_points = []
      
      @modules.each do |mod|
        #mod.mount_points.each do |mount_point|
        #  @mount_points << mount_point
        #end
        @mount_points += mod.mount_points
      end
      
      @ships.each do |ship|
        ship.children.each do |mod|
          @mount_points +=  mod.mount_points
        end
      end
      
      @camera = @previous_scene.camera
    end
    
    def update
      if @selected != nil
        if button_down?(Gosu::MsLeft)
          #@selected.detach if @selected.attached? # Improve on this! #FIXME
          @selected.shape.body.p.x = @camera.mouse_x + @selected_offset_x
          @selected.shape.body.p.y = @camera.mouse_y + @selected_offset_y
          @previous_scene.space.rehash_shape(@selected.shape)
          
          #@selected.mount_points.each do |mp1|
          #  @mount_points.each do |mp2|
          #    if Gosu.distance(mp1.space_pos.x, mp1.space_pos.y, mp2.space_pos.x, mp2.space_pos.y) < 5
          #      mp2.s = 3
          #    end
          #  end
          #end
        elsif button_down?(Gosu::MsRight)
          @selected.shape.body.a = Gosu.angle(@selected.shape.body.p.x, @selected.shape.body.p.y, @camera.mouse_x + @selected_offset_x, @camera.mouse_y + @selected_offset_y).gosu_to_radians
          @previous_scene.space.rehash_shape(@selected.shape)
        else # whoops, must have missed the button_up
          end_drag
        end
      end
    end
    
    def draw
      @previous_scene.draw
      @camera.draw do
        @window.draw_quad(0, 0, @filter, SCREEN_WIDTH, 0, @filter, SCREEN_WIDTH, SCREEN_HEIGHT, @filter, 0, SCREEN_HEIGHT, @filter, render_depth+ZOrder::Background)
        @modules.each do |mod|
          mod.draw(render_depth)
        
          @window.rotate(mod.shape.body.a.radians_to_degrees, mod.shape.body.p.x, mod.shape.body.p.y) do
            num_verts = mod.shape.num_verts
            (0...num_verts).each do |vert_i|
              x = mod.shape.body.p.x
              y = mod.shape.body.p.y
              cur = mod.shape.vert(vert_i)
              nxt = mod.shape.vert((vert_i+1)%num_verts)
              @window.draw_line(x+cur.x, y+cur.y, 0xaaff0000, x+nxt.x, y+nxt.y, 0xaaff0000, render_depth+ZOrder::UI)
            end
          end
          
          @mount_points.each do |mp|
            @mount_point_image.draw_rot(mp.space_pos.x, mp.space_pos.y, render_depth+ZOrder::UI, 0, 0.5, 0.5, mp.s, mp.s)
            mp.s = 1
          end
          
          x = mod.shape.body.p.x
          y = mod.shape.body.p.y
          width = @font.text_width(mod.data[:angle])
          height = 11
          @window.draw_quad(x, y, @filter, x+width, y, @filter, x+width, y+height, @filter, x, y+height, @filter, render_depth+ZOrder::UI)
          @font.draw(mod.data[:angle], x, y, render_depth+ZOrder::UI, 1, 1, @font_color)
        end
        
        @ships.each do |ship|
          ship.draw(render_depth)
        end
          
        if @selected
          @selected.mount_points.each do |mount_point|
            @mount_point_image.draw_rot(mount_point.space_pos.x, mount_point.space_pos.y, render_depth+ZOrder::UI, 0)
            #@font.draw(index.to_s, vec.x, vec.y, render_depth+ZOrder::UI, 0.7, 0.7, 0xff0000ff)
          end
        end
      end
    end
    
    def button_up(id)
      case id
      when Gosu::KbLeft
        end_drag
      end
    end
    
    def button_down(id)
      case id
      when Gosu::KbE
        @window.end_scene
      when Gosu::KbEscape
        @window.close
      when Gosu::MsLeft
        start_drag @previous_scene.space.point_query_first(CP::Vec2.new(@camera.mouse_x, @camera.mouse_y))
      when Gosu::MsRight
        start_drag @previous_scene.space.point_query_first(CP::Vec2.new(@camera.mouse_x, @camera.mouse_y))
      end
    end
    
    def start_drag shape
      p shape
      if shape && shape.object.data[:compatible] #body.
        @selected = shape
        if @selected.object.attached?
          ship = @selected.object.ship
          ship.remove_module(@selected.object)  #@selected.object.detach
          ship.update_ship
          @selected.object.parent.unmount(@selected.object) if @selected.object.mounted?
        end
          
          
        @selected_offset_x = @selected.object.get_p.x - @camera.mouse_x#@selected.body.p.x - @camera.mouse_x
        @selected_offset_y = @selected.object.get_p.y - @camera.mouse_y#@selected.body.p.y - @camera.mouse_y
        @selected_start_x = @selected.object.get_p.x#@selected.body.p.x
        @selected_start_y = @selected.object.get_p.y#@selected.body.p.y
        @selected_rotation = @selected.object.get_a#@selected.body.a
        
        @selected = @selected.object
        
        @mount_points.delete_if do |mp|
          mp.object == @selected
        end
      end
    end
    
    def end_drag
      if @selected
        # TODO: only mount once and when movement is > .. or whatever
        if (@selected.shape.body.p.x - @selected_start_x).abs  > 10 || (@selected.shape.body.p.y - @selected_start_y).abs  > 10 || (@selected.shape.body.a - @selected_rotation).abs > 1
          @previous_scene.connection_manager.remove_for_object(@selected)
        end
        
        @selected.mount_points.each do |mp1|
          @mount_points.each do |mp2|
            if Gosu.distance(mp1.space_pos.x, mp1.space_pos.y, mp2.space_pos.x, mp2.space_pos.y) < 5
              @previous_scene.connection_manager.remove_for_object(@selected)#disconnect(mp2.object, @selected)
              
              other_angle = (mp2.object.get_a + mp2.angle.degrees_to_radians) #(mp2.object.shape.body.a + mp2.angle.degrees_to_radians)
              @selected.shape.body.a = (other_angle - 180.degrees_to_radians) - mp1.angle.degrees_to_radians
              
              @selected.shape.body.p = mp2.space_pos - mp1.p.rotate(@selected.shape.body.rot)
              #@selected.add_data({:parent_mount_point => mp2.index, :mount_on => mp1.index})
              
              #Actually mount!
              @selected.mount_on(mp2.index, mp1.index, @selected)
              
              if mp2.object.attached?
                p "ship is attached"
                #@selected.attach(mp2.object.ship)
                mp2.object.ship.add_module(@selected)
                mp2.object.ship.update_ship
              else
                @selected.attach_to(mp2.object.ship)
              end
              
              @previous_scene.space.rehash_shape(@selected.shape)
              
              @previous_scene.connection_manager.connect(mp2.object, @selected)
              p "Connected #{@selected} with #{mp2.object}"
            end
          end
        end
        
        @mount_points += @selected.mount_points
      end
      @selected = nil
    end
  end
  
end
