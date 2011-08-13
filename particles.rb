module Particles
  class BasicParticle
    attr_reader :window
    def initialize(window, x, y, rotation=nil, angle=nil)
      @window = window
      
      @x = x
      @y = y
      
      @rot = rotation
      @rot ||= rand(360)
      
      @angle = angle
      
      @window.particle_system.add_particle(self)
    end
    
    def die
      @window.particle_system.remove_particle(self)
    end    
  end
  
  class ExaustFire < BasicParticle
    def initialize(window, x, y, angle=nil)
      super(window, x, y, nil, angle)
      
      @color = Gosu::Color.new(255,255,255,255)
      @image = Gosu::Image.new(window,"media/fireball.png",false)
    
      if rand > 0.5 then @left = true else @left = false end
    end
    
    def update
      if @angle
        @x += Gosu::offset_x(@angle, 1)
        @y += Gosu::offset_y(@angle, 1)
      end
    
      if @color.alpha-8 > 0 then @color.alpha-=8 else die end
      if @left then @rot -= rand(10) else @rot += rand(10) end
    end
    
    def draw
      scale = 1
      @image.draw_rot(@x, @y, ZOrder::Particles, @rot, 0.5, 0.5, scale, scale, @color, :additive)
    end
  end
end
