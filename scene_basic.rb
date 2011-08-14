module Scenes

  class BasicScene
    attr_reader :window
    attr_accessor :depth
    
    def initialize(window)
      @window = window
      @depth = depth
    end

    def button_down(id)
    end
    
    def button_up(id)
    end
    
    def button_down?(id)
      @window.button_down?(id)
    end
    
    def render_depth
      @depth*100
    end
    
    def to_s
      "#{self.class}:#{__id__}"
    end
  end

end
