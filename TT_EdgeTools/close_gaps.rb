#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::EdgeTools

  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( __FILE__ )      
    cmd_find_edge_gaps = UI::Command.new('Find Edge Gaps') {
      self.find_open_gaps
    }
    cmd_find_edge_gaps.large_icon = 'Images/inspect_gaps_24.png'
    cmd_find_edge_gaps.small_icon = 'Images/inspect_gaps_16.png'
    cmd_find_edge_gaps.status_bar_text = 'Inspect and close edge gaps'
    cmd_find_edge_gaps.tooltip = 'Inspect and close edge gaps'
    
    cmd_close_all_gaps = UI::Command.new('Close All Edge Gaps') {
      self.close_all_gaps
    }
    cmd_close_all_gaps.large_icon = 'Images/close_gaps_24.png'
    cmd_close_all_gaps.small_icon = 'Images/close_gaps_16.png'
    cmd_close_all_gaps.status_bar_text = 'Close all edge gaps'
    cmd_close_all_gaps.tooltip = 'Close all edge gaps'
    
    cmd_erase_stray_curves = UI::Command.new('Erase Stray Curves') {
      self.erase_stray_curves
    }
    cmd_erase_stray_curves.large_icon = 'Images/erase_stray_24.png'
    cmd_erase_stray_curves.small_icon = 'Images/erase_stray_16.png'
    cmd_erase_stray_curves.status_bar_text = 'Erase stray curves'
    cmd_erase_stray_curves.tooltip = 'Erase stray curves'
    
    # Menu
    @menu.add_separator
    @menu.add_item( cmd_find_edge_gaps )
    @menu.add_item( cmd_close_all_gaps )
    @menu.add_item( cmd_erase_stray_curves )

    
    # Toolbar
    @toolbar.add_separator
    @toolbar.add_item( cmd_find_edge_gaps )
    @toolbar.add_item( cmd_close_all_gaps )
    @toolbar.add_item( cmd_erase_stray_curves )
  end # UI
  file_loaded( __FILE__ )
  
  # Default Settings
  @settings.set_default( :gap_epsilon, 10.mm )
  @settings.set_default( :gap_remove, 'Yes' )
  
  
  ### METHODS ### ----------------------------------------------------------
  
  
  # (!) Not all curves erased in one run...
  def self.erase_stray_curves
    model = Sketchup.active_model
    entities = (model.selection.empty?) ? model.active_entities : model.selection
    
    Sketchup.status_text = 'Gathering curves...'
    t = Time.now
    curves = TT::Edges.find_curves( entities, true  )
    TT.debug "TT::Edges.find_curves took: #{Time.now-t}s"
    
    Sketchup.status_text = 'Finding stray curves...'
    TT::SketchUp.refresh
    stray_curves = []
    for curve in curves
      vertices = TT::Edges.sort_vertices( curve)
      if vertices.first.edges.length == 1 || vertices.last.edges.length == 1
        stray_curves << curve
      end
    end
    
    Sketchup.status_text = 'Erasing stray curves...'
    TT::SketchUp.refresh
    TT::Model.start_operation('Erase Stray Curves')
    edges = stray_curves.flatten
    model.active_entities.erase_entities( edges )
    #edges.each { |e| e.material = [255,0,0] }
    model.commit_operation
    str = "#{stray_curves.size} stray curves erased. (#{edges.size} edges erased)"
    puts str
    UI.messagebox( str, MB_OK )
  end
  
  
  def self.close_all_gaps
    # Prompt user for epsilon tolerance.
    prompts = ['Tolerance', 'Remove Small Edges']
    lists = ['', 'Yes|No']
    defaults = [ @settings[:gap_epsilon] , @settings[:gap_remove] ]
    input = UI.inputbox(prompts, defaults, lists, 'Close Gaps and Remove Small Edges')
    return false if input == false
    epsilon = input[0]
    remove_small_edges = input[1]=='Yes'
    
    @settings[:gap_epsilon] = epsilon
    @settings[:gap_remove] = remove_small_edges
    
    puts "Epsilon: #{epsilon}"
    puts "Erase Small Edges: #{remove_small_edges}"
    
    # Use the current selection, or the active context if the selection is empty.
    model = Sketchup.active_model
    entities = (model.selection.empty?) ? model.active_entities : model.selection
    
    t = Time.now
    Sketchup.status_text = 'The hamsters are working very hard, please wait...'
    TT::Model.start_operation( 'Close All Edge Gaps' )
    cache = model.active_entities.to_a
    result = TT::Edges::Gaps.close_all( entities, epsilon, remove_small_edges, true )
    new_entities = model.active_entities.to_a - cache
    TT::Edges.repair_splits( new_entities, true )
    model.commit_operation
    puts "#{result} ends fixed in #{Time.now-t}s"
  end
  
  
  # TT_EdgeTools.find_open_gaps
  def self.find_open_gaps
    Sketchup.active_model.select_tool( CloseEdgeGapsTool.new(@settings) )
  end
  
  
  # TT_EdgeTools.find_open_gaps
  class CloseEdgeGapsTool
    
    STRINGS = {
      :vertex_projected => 'Projected Vertices',
      :edge => 'Projected to Edge',
      :vertex => 'Closest Open-end Vertex'
    }
    COLORS = [
      [255,0,0,64],
      [0,128,0,64],
      [0,0,255,64]
    ]
    
    def initialize( settings )
      @settings = settings
      @epsilon = @settings[:gap_epsilon]
      reset()
    end
    
    def reset
      @edges = self.class.find_edges()
      @vertices = TT::Edges::Gaps.find_end_vertices( @edges )
      @pick = nil
      @result = nil
    end
    
    def updateUI
      Sketchup.status_text = 'Click an open end to close it.'
      Sketchup.vcb_label = 'Distance:'
      Sketchup.vcb_value = @epsilon
    end
    
    def activate
      updateUI()
      view = Sketchup.active_model.active_view
      update_circles(view)
      view.invalidate
    end
    
    def deactivate(view)
      view.invalidate
    end
    
    def resume(view)
      updateUI()
      update_circles(view)
      view.invalidate
    end
    
    def enableVCB?
      true
    end
 
    def onUserText(text, view)
      epsilon = text.to_l
      @epsilon = epsilon
      @settings[:gap_epsilon] = @epsilon
      updateUI()
      view.invalidate
    rescue
      UI.beep
      Sketchup.vcb_value = @epsilon
    end
    
    def onCancel(reason, view)
      if reason == 2 # Undo
        # Lazy hack to delay execution. onCancel triggers before the model
        # is updated - so one should use a model observer to catch the undo
        # event.
        UI.start_timer(0,false) {
          reset()
          update_circles(view)
          view.invalidate
        }
      end
    end
    
    # (!) Indicate fixable (cursor)
    # (!) Indicate Delete (cursor)
    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      @circles.each { |v,circle|
        if Geom.point_in_polygon_2D( [x,y,0], circle, true )
          if v != @pick
            @pick = v
            @result = TT::Edges::Gaps.find( v, @vertices, @edges )
            view.invalidate
          end
          result_feedback( @result, view )
          return
        end
      }
      unless @pick.nil?
        @pick = nil
        @result = nil
        view.invalidate
      end
      result_feedback( @result, view )
    end
    
    # (!) private
    def result_feedback( result, view )
      if result
        edge = @pick.edges.first
        if type = can_close?( @result, @epsilon )
          view.tooltip = STRINGS[type]
        elsif edge.length < @epsilon
          view.tooltip = 'Remove Edge'
        else
          view.tooltip = 'No solution within range'
        end
      end
    end
    
    # (!) private
    def can_close?( result, epsilon )
      # 1. Closest projected open end
      data = result[:vertex_projected]
      if data[:dist] && data[:dist][0] + data[:dist][1] < epsilon
        return :vertex_projected
      end
      # 2. Closest edge
      data = result[:edge]
      if data[:dist] && data[:dist] < epsilon
        return :edge
      end
      # 3. Closest open vertex
      data = result[:vertex]
      if data[:dist] && data[:dist] < epsilon
        return :vertex
      end
      false
    end
    
    def onLButtonUp(flags, x, y, view)
      ph = view.pick_helper
      @circles.each { |v,circle|
        next unless Geom.point_in_polygon_2D( [x,y,0], circle, true )
        @pick = v
        @result = TT::Edges::Gaps.find( v, @vertices, @edges )
        TT::Model.start_operation('Close Gaps')
        cache = view.model.active_entities.to_a
        closed = TT::Edges::Gaps.close( view.model.active_entities, v, @result, @epsilon )
        if closed
          new_entities = view.model.active_entities.to_a - cache
          TT::Edges.repair_splits( new_entities )
          reset()
          update_circles(view)
        else
          edge = v.edges.first
          if edge.length < @epsilon
            #puts 'Removing small edge'
            edge.erase!
            reset()
            update_circles(view)
          end
        end
        view.model.commit_operation
        view.invalidate
        break
      }
    end
    
    def draw(view)
      # Draw background
      # (!)
      if TT::SketchUp.support?( TT::SketchUp::COLOR_ALPHA )
        pts = [
          [ 80.5,  80.5, 0],
          [520.5,  80.5, 0],
          [520.5, 360.5, 0],
          [ 80.5, 360.5, 0]
        ]
        color = view.model.rendering_options['BackgroundColor']
        # Border
        view.line_width = 1
        view.drawing_color = color
        view.draw2d( GL_LINE_LOOP, pts )
        # Fill
        color.alpha = 0.75
        view.drawing_color = color
        view.draw2d( GL_QUADS, pts )
      end
      
      # Draw circles around each end.
      view.line_stipple = ''
      view.line_width = 2
      for v in @vertices
        selected = v == @pick
        pt2d = view.screen_coords( v.position )
        circle = TT::Geom3d.circle( pt2d, Z_AXIS, 10, 24 )
        view.drawing_color = (selected) ? [255,0,0] : [0,0,255]
        view.draw2d( GL_LINE_LOOP, circle )
        if TT::SketchUp.support?( TT::SketchUp::COLOR_ALPHA )
          view.drawing_color = (selected) ? [255,0,0,32] : [0,0,255,32]
          view.draw2d( GL_POLYGON, circle )
        end
      end # for
      len = (@pick) ? @pick.edges.first.length : '-'
      view.draw_text( [100,100,0], "Open ends: #{@vertices.size}\n\nSmall dots: Out of range\nLong dashes: Within range\nSolid line: Best Solution\n\nEdge Length: #{len}" )
      
      if @result
        connection_found = false
        view.line_width = 2
        keys = [:vertex_projected, :edge, :vertex]
        keys.each_with_index { |key, i|
          data = @result[key]
          dist = data[:dist]
          # Colour
          view.drawing_color = COLORS[i]
          # Line type.
          # * Dotted it out of epsilon distance.
          # * Solid is valid distance.
          total_distance = ( dist.is_a?(Array) ) ? (dist[0]+dist[1]).to_l : dist
          if total_distance && total_distance < @epsilon
            if connection_found
              view.line_stipple = '_' # Within range
            else
              view.line_stipple = '' # Best solution
              connection_found = true
            end
          else
            view.line_stipple = '.' # Out of range
          end
          # Connecting Lines
          view.line_width = 2
          if data[:point2]
            view.draw( GL_LINE_STRIP, @pick.position, data[:point], data[:point2].position )
          else
            view.draw( GL_LINES, @pick.position, data[:point] )
          end
          # Legend Colour ID
          view.line_stipple = ''
          view.line_width = 4
          view.draw2d( GL_LINES, [100,250+(30*i),0], [200,250+(30*i),0] )
          # Legend and debug data
          distance = ( dist.is_a?(Array) ) ? "#{total_distance} (#{dist.join(' + ')})" : dist
          str = "#{STRINGS[key]}: #{distance}"
          view.draw_text( [100,250+(30*i),0], str )
        }
      end
      
    end
    
    def update_circles(view)
      @circles = {}
      @vertices.each { |v|
        pt2d = view.screen_coords( v.position )
        circle = TT::Geom3d.circle( pt2d, Z_AXIS, 10, 24 )
        @circles[v] = circle
      }
    end
    
    
    def self.find_edges
      Sketchup.active_model.active_entities.select { |e|
        e.is_a?( Sketchup::Edge )
      }
    end
    
  end # Tool

  
end # module