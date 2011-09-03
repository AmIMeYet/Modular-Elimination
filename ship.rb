class Ship
  attr_reader :body, :cockpit, :children
  def initialize(scene, x, y, angle)
    @scene = scene
    #@children = children
    
    @body = CP::Body.new(0, 0)
    @body.p = CP::Vec2.new(x, y) # position
    @body.v = CP::Vec2.new(0.0, 0.0) # velocity
    @body.a = angle.degrees_to_radians
    scene.space.add_body(@body)
    
    @children = []
    @cockpit = nil
    
    #update_ship
  end
  
  def draw(render_depth=0)
    @children.each { |child| child.draw(render_depth) }
    @scene.particle_system.gfx[:fireball].draw_rot(@body.p.x, @body.p.y, 9999, 0)
  end
  
  def update
    @children.each { |child| child.update }
  end
  
  def add_module(module_entity)
    @children << module_entity
    p "module was attached? #{module_entity.attached?}"
    module_entity.offset = @body.world2local(module_entity.shape.body.p) #@body.local2world(@offset+(THRUST_POINT.rotate(@data[:offset_angle]))) #@body.p - module_entity.shape.body.p
  end
  
  def remove_module(module_entity)
    if @children.include? module_entity
      @children.delete module_entity
      module_entity.detach
      #update_ship
    end
  end
  
  def set_cockpit
    @children.each do |child|
      if child.is_a? Modules::Cockpit
        @cockpit = child
        break
      end
    end
  end
  
  def update_ship
    avg_x = 0.0
    avg_y = 0.0
    mass_total = 0.0
    inertia_total = 0.0
    
    @children.each do |child|
      #child.detach
      child_mass = 10
      mass_total += child_mass
      inertia_total += CP.moment_for_poly(child_mass, child.shape_verts, child.offset) #child.shape.body.i + child.shape.body.m*((cogOfShip - cogOfPiece).lengthsq)
      avg_x += child_mass * child.offset.x
      avg_y += child_mass * child.offset.y
      #mass_total += child.shape.body.m
      #inertia_total += CP.moment_for_poly(child.shape.body.m, child.shape_verts, child.offset) #child.shape.body.i + child.shape.body.m*((cogOfShip - cogOfPiece).lengthsq)
      #avg_x += child.shape.body.m * child.offset.x
      #avg_y += child.shape.body.m * child.offset.y
    end
    avg_x /= mass_total
    avg_y /= mass_total
    new_body_position = @body.local2world(CP::Vec2.new(avg_x,avg_y))
    
    @body.p = new_body_position
    @body.m = mass_total
    @body.i = inertia_total
    
    @children.each do |child|
      x = child.offset.x-avg_x
      y = child.offset.y-avg_y
      child.offset = CP::Vec2.new(x, y)
      child.attach(self)
    end
    
    p "Position: #{@body.p}, Mass: #{@body.m}, Inertia: #{@body.i}"
  end
end