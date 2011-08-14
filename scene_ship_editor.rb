module Scenes

  class ShipEditorScene < BasicScene
    class MountPointStub
      attr_reader :pos, :object, :index
      attr_accessor :s
      def initialize(pos, object, index)
        @pos = pos
        @object = object
        @index = index
        @s = 1
      end
      
      def x
        @pos.x
      end
      
      def y
        @pos.y
      end
    end
  
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
      
      @selected = nil
      @selected_offset_x = 0
      @selected_offset_y = 0
      @selected_start_x = 0
      @selected_end_x = 0
      @selected_rotation = 0
      
      update_mount_points
    end
    
    def update
      if @selected
        if button_down?(Gosu::MsLeft)
          @selected.shape.body.p.x = @window.mouse_x + @selected_offset_x
          @selected.shape.body.p.y = @window.mouse_y + @selected_offset_y
          @previous_scene.space.rehash_shape(@selected.shape)
          
          @selected.mount_points.each do |mp1|
            loc = @selected.shape.body.local2world(mp1)
            @mount_points.each do |mp2|
              if Gosu.distance(loc.x, loc.y, mp2.x, mp2.y) < 5
                mp2.s = 3
              end
            end
          end
        elsif button_down?(Gosu::MsRight)
          @selected.shape.body.a = Gosu.angle(@selected.shape.body.p.x, @selected.shape.body.p.y, @window.mouse_x + @selected_offset_x, @window.mouse_y + @selected_offset_y).gosu_to_radians
          @previous_scene.space.rehash_shape(@selected.shape)
        else # whoops, must have missed the button_up
          end_drag
        end
      end
    end
    
    def draw
      @previous_scene.draw
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
          @mount_point_image.draw_rot(mp.pos.x, mp.pos.y, render_depth+ZOrder::UI, 0, 0.5, 0.5, mp.s, mp.s)
          mp.s = 1
        end
        
        x = mod.shape.body.p.x
        y = mod.shape.body.p.y
        width = @font.text_width(mod.data[:angle])
        height = 11
        @window.draw_quad(x, y, @filter, x+width, y, @filter, x+width, y+height, @filter, x, y+height, @filter, render_depth+ZOrder::UI)
        @font.draw(mod.data[:angle], x, y, render_depth+ZOrder::UI, 1, 1, @font_color)
      end
        
      if @selected
        @selected.mount_points.each do |mount_point|
          vec = @selected.shape.body.local2world(mount_point)
          @mount_point_image.draw_rot(vec.x, vec.y, render_depth+ZOrder::UI, 0)
          #@font.draw(index.to_s, vec.x, vec.y, render_depth+ZOrder::UI, 0.7, 0.7, 0xff0000ff)
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
        start_drag @previous_scene.space.point_query_first(CP::Vec2.new(@window.mouse_x, @window.mouse_y))
      when Gosu::MsRight
        start_drag @previous_scene.space.point_query_first(CP::Vec2.new(@window.mouse_x, @window.mouse_y))
      end
    end
    
    def update_mount_points
      @mount_points = []
      
      @modules.each do |mod|
        mod.mount_points.each_with_index do |mount_point, index|
          @mount_points << MountPointStub.new(mod.shape.body.local2world(mount_point), mod, index)
        end
      end
    end
    
    def start_drag shape
      if shape && shape.body.object.data[:compatible]
        @selected = shape
        @selected_offset_x = @selected.body.p.x - @window.mouse_x
        @selected_offset_y = @selected.body.p.y - @window.mouse_y
        @selected_start_x = @selected.body.p.x
        @selected_start_y = @selected.body.p.y
        @selected_rotation = @selected.body.a
        @selected = @selected.body.object
        
        @mount_points.delete_if do |mp|
          mp.object == @selected
        end
        #p "Dragging #{@selected}"
      end
    end
    
    def end_drag
      if @selected
        if (@selected.shape.body.p.x - @selected_start_x).abs  > 10 || (@selected.shape.body.p.y - @selected_start_y).abs  > 10 || (@selected.shape.body.a - @selected_rotation).abs > 1
          @previous_scene.connection_manager.remove_for_object(@selected)
          p "BREAK"
        end
        
        @selected.mount_points.each_with_index do |mp1, mp1_index|
          loc = @selected.shape.body.local2world(mp1)
          @mount_points.each do |mp2|
            if Gosu.distance(loc.x, loc.y, mp2.x, mp2.y) < 5
              #mp2.s = 3
              @previous_scene.connection_manager.disconnect(mp2.object, @selected)
              
              #parent_loc = parent.shape.body.local2world(parent.mount_points[mount_point])
              #module_entity.shape.body.p = parent_loc - module_entity.mount_points[scheme[:mount_on]].rotate(module_entity.shape.body.rot)
              #module_entity.add_data({:parent_mount_point => mount_point, :mount_on => scheme[:mount_on]})
              
              #mp2_loc = mp2.object.shape.body.local2world(mp2.pos)
              @selected.shape.body.p = mp2.pos - mp1.rotate(@selected.shape.body.rot)
              @selected.add_data({:x => @selected.shape.body.p.x, :y => @selected.shape.body.p.y, :angle => @selected.shape.body.a.radians_to_degrees, :parent_mount_point => mp2.index, :mount_on => mp1_index})
              
              @previous_scene.connection_manager.connect(mp2.object, @selected)
              p "connected"
            end
          end
        end
        
        #@selected.shape.body.a += 0.1
        update_mount_points
      end
      @selected = nil
      #@selected_offset_x = 0
      #@selected_offset_y = 0
      #@selected_start_x = 0
      #@selected_start_y = 0
      #p "Stopped dragging"
    end
  end
  
end
