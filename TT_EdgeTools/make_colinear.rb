#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::EdgeTools

  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    cmd_make_colinear = UI::Command.new('Co-linear from start to end') {
      self.make_colinear(X_AXIS)
    }
    cmd_make_colinear.large_icon = 'Images/colinear_24.png'
    cmd_make_colinear.small_icon = 'Images/colinear_16.png'
    cmd_make_colinear.status_bar_text = 'Make vertices colinear from start to end'
    cmd_make_colinear.tooltip = 'Make vertices colinear from start to end'
    
    cmd_make_colinear_x = UI::Command.new('Co-linear to Red (X) Axis') {
      self.make_colinear(X_AXIS)
    }
    cmd_make_colinear_x.large_icon = 'Images/colinear_x_24.png'
    cmd_make_colinear_x.small_icon = 'Images/colinear_x_16.png'
    cmd_make_colinear_x.status_bar_text = 'Make vertices colinear in the X axis'
    cmd_make_colinear_x.tooltip = 'Make vertices colinear in the X axis'
    
    cmd_make_colinear_y = UI::Command.new('Co-linear to Green (Y) Axis') {
      self.make_colinear(Y_AXIS)
    }
    cmd_make_colinear_y.large_icon = 'Images/colinear_y_24.png'
    cmd_make_colinear_y.small_icon = 'Images/colinear_y_16.png'
    cmd_make_colinear_y.status_bar_text = 'Make vertices colinear in the Y axis'
    cmd_make_colinear_y.tooltip = 'Make vertices colinear in the Y axis'
    
    cmd_make_colinear_z = UI::Command.new('Co-linear to Blue (Z) Axis') {
      self.make_colinear(Z_AXIS)
    }
    cmd_make_colinear_z.large_icon = 'Images/colinear_z_24.png'
    cmd_make_colinear_z.small_icon = 'Images/colinear_z_16.png'
    cmd_make_colinear_z.status_bar_text = 'Make vertices colinear in the Z axis'
    cmd_make_colinear_z.tooltip = 'Make vertices colinear in the Z axis'
    
    # Menu
    @menu.add_separator
    @menu.add_item( cmd_make_colinear )
    @menu.add_item( cmd_make_colinear_x )
    @menu.add_item( cmd_make_colinear_y )
    @menu.add_item( cmd_make_colinear_z )
    
    # Toolbar
    @toolbar.add_separator
    @toolbar.add_item( cmd_make_colinear )
    @toolbar.add_item( cmd_make_colinear_x )
    @toolbar.add_item( cmd_make_colinear_y )
    @toolbar.add_item( cmd_make_colinear_z )
  end # UI
  file_loaded( __FILE__ )
  
  
  ### METHODS ### ----------------------------------------------------------
  
  
  # Find each sets of selected curves. Curves being a series of connected edges.
  # For each curve found, the vertices inbetween is fit to be co-linear to the first
  # and last point in each curve.
  #
  # restrict_vector - Restricts the adjustments of the vertices to this vector.
  #   If no vector is given all points are fitted to the line between the
  #   first and the last point in each curve.
  #
  ## (!) Review and cleanup
  def self.make_colinear(restrict_vector = nil)
    model = Sketchup.active_model
    sel = model.selection
    
    return false if sel.empty?
    
    edges = sel.select { |e| e.is_a?(Sketchup::Edge) }
    #curves = TT::Edges.sort_edges(edges)
    curves = self.sort_edges( edges )
    
    TT::Model.start_operation('Make Edges Co-Linear')
    
    for curve in curves
      # Ensure all edges are not part of any Curve that might enforce transformation
      # restrictions.
      for edge in curve
        edge.explode_curve
      end
      
      # The vertices needs to be sorted from start to beginning in order to
      # process it.
      vertices = TT::Edges.sort_vertices( curve )
      
      # The line between the first and last point will be used as a quide for
      # arranging the vertices.
      guide_line = [vertices.first.position, vertices.last.position]
      
      tr = {}
      vertices[1...-1].each { |v|
        if restrict_vector.nil?
          # No vector restriction, all vertices are made truly co-linear.
          point = v.position.project_to_line(guide_line)
        else
          # Vector restrictions, vertices can only be adjusted in the direction
          # of the given vector.
          line = [v.position, restrict_vector]
          point = Geom.closest_points( guide_line, line ).last
        end
        
        tr[ v ] = v.position.vector_to(point)
      }
      model.active_entities.transform_by_vectors( tr.keys, tr.values )
    end # for
    
    model.commit_operation
  end
  
  
  # (!) Review
  # Sorts the given set of edges from one end point to the other.
  # (?) insert nil instead of array some times?
  def self.sort_edges(edges)
    curves = []
    source = edges.to_a
    until source.empty?
      start = self.get_end_edge(source)
      break if start.nil? # we only have loops left - can't process them
      curve = []
      curve << start
      source.delete(start)
      while true
        connected_edges = curve.last.start.edges + curve.last.end.edges
        edge = (connected_edges & source).first
        break if edge.nil?
        curve << edge
        source.delete(edge)
      end
      curves << curve
    end
    return curves
  end
  
  
  def self.get_end_edge(edges)
    edges.each { |e|
      return e if ((e.start.edges-[e]) & edges).empty? || ((e.end.edges-[e]) & edges).empty?
    }
    return nil
  end

  
end # module