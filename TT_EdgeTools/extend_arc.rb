#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::EdgeTools

  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( __FILE__ )      
    cmd_extend_arc = UI::Command.new( 'Extend Arc' ) {
      self.extend_arc
    }
    cmd_extend_arc.large_icon = 'Images/divide_24.png'
    cmd_extend_arc.small_icon = 'Images/divide_16.png'
    cmd_extend_arc.status_bar_text = 'Extend selected arc'
    cmd_extend_arc.tooltip = 'Extend selected arc'
    
    # Menu
    @menu.add_item( cmd_extend_arc )
    
    # Toolbar
    @toolbar.add_item( cmd_extend_arc )
  end # UI
  file_loaded( __FILE__ )
  
  
  ### METHODS ### ----------------------------------------------------------
  
  
  def self.extend_arc
    Sketchup.active_model.select_tool( ExtendArcTool.new )
  end
  
  
  class ExtendArcTool
    
    STATE_NORMAL        = nil
    STATE_EXTEND_START  = 1
    STATE_EXTEND_END    = 2
    
    
    def initialize
      @arc = nil
      @new_arc_points = nil
      @ip = Sketchup::InputPoint.new
    end    
    
    def activate
      reset()
      model = Sketchup.active_model
      if model.selection.is_curve?
        curve = model.selection[0].curve
        if curve.is_a?( Sketchup::ArcCurve )
          @arc = curve
        end
      end
    end
    
    def reset
      @state = STATE_NORMAL
      @arc = nil
      @new_arc_points = nil
      @ip.clear
    end    
    
    def onCancel( reason, view )
      reset()
    end
    
    def deactivate( view )
      view.invalidate
    end
    
    def resume( view )
      view.invalidate
    end
    
    def onMouseMove( flags, x, y, view )
      if @state
        @ip.pick( view, x, y )
      else
        @ip.pick( view, x, y )
      end
      view.tooltip = @ip.tooltip
      view.invalidate
    end
    
    def onLButtonDown( flags, x, y, view )
      if @state
        @state = STATE_NORMAL
      elsif @arc && @ip.vertex
        vertices = @arc.vertices
        positions = vertices.map { |v| v.position }
        selected = @ip.vertex
        if vertices.first == selected
          @state = STATE_EXTEND_START
        elsif vertices.last == selected
          @state = STATE_EXTEND_END
        end
        view.invalidate
      end
    end
    
    # (!) Move to TT_Lib?
    def full_angle_between( vector1, vector2, normal )
      angle = vector1.angle_between( vector2 )
      angle = 360.degrees - angle if right_turn?( vector1, vector2, normal )
      angle
    end
    
    # (!) Move to TT_Lib?
    def right_turn?( vector1, vector2, normal )
      cross1 = vector1 * normal
      cross2 = vector2 * normal
      cross = cross1 * cross2
      (cross.z > 0.0) ? false : true
    end
    
    def draw( view )
      return nil unless @arc
      
      vertices = @arc.vertices
      end_vertices = [ vertices.first, vertices.last ]
      positions = vertices.map { |v| v.position }
      
      if @state && @ip.valid?
        @ip.draw( view ) if @ip.display?
        center = @arc.center
        cursor = @ip.position
        # Project cursor point to arc plane
        cursor_on_plane = cursor.project_to_plane( @arc.plane )
        # Project center to new leg
        direction = center.vector_to( cursor_on_plane )
        direction.length = @arc.radius
        point = center.offset( direction )
        # New Arc
        view.line_stipple = ''
        view.line_width = 2
        view.drawing_color = [128,0,255]
        view.draw_line( center, point )
        if @state == STATE_EXTEND_END
          xaxis = @arc.xaxis
          normal = @arc.normal
          radius = @arc.radius
          
          start_angle = @arc.start_angle
          end_angle = full_angle_between( xaxis, direction, normal )
          
          # Calculate new arc segment count based on existing arc.
          segments = @arc.vertices.size
          arc_angle = @arc.end_angle - @arc.start_angle
          full_angle = end_angle - start_angle
          segments_per_angle = segments.to_f / arc_angle
          segments = ( full_angle * segments_per_angle ).to_i
          
          points = TT::Geom3d.arc( center, xaxis, normal, radius, start_angle, end_angle, segments )
          view.draw( GL_LINE_STRIP, points )
        else
          # ...
        end
        # Arc
        view.line_stipple = ''
        view.line_width = 2
        view.drawing_color = [255,0,0]
        # Arc xaxis
        view.line_stipple = '.'
        view.line_width = 1
        view.drawing_color = [0,128,0]
        pt = center.offset( @arc.xaxis, @arc.radius )
        points = [ center, pt ]
        view.draw( GL_LINE_STRIP, points )
        # Arc radius
        view.line_stipple = '-'
        view.line_width = 1
        view.drawing_color = 'orange'
        points = [ center, positions.first ]
        view.draw( GL_LINE_STRIP, points )
        view.drawing_color = 'pink'
        points = [ center, positions.last ]
        view.draw( GL_LINE_STRIP, points )
        # Arc center
        view.line_stipple = ''
        view.line_width = 2
        points = [ center ]
        view.draw_points( points, 8, TT::POINT_CROSS, [255,0,0] )
      else
        view.line_stipple = ''
        # Draw end vertices
        points = [ positions.first, positions.last ]
        view.line_width = 2
        view.draw_points( points, 8, TT::POINT_OPEN_SQUARE, [255,0,0] )
        # Draw selected end
        if @ip.vertex && end_vertices.include?( @ip.vertex )
          points = [ @ip.vertex.position ]
          view.draw_points( points, 8, TT::POINT_FILLED_SQUARE, [255,0,0] )
        end
      end
      
    end # def
    
  end # class ExtendArcTool

  
end # module