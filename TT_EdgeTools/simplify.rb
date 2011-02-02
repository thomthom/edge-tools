#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::EdgeTools

  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( __FILE__ )      
    cmd_simplify_curves = UI::Command.new('Simplify Curves') {
      self.simplify_curves
    }
    cmd_simplify_curves.large_icon = 'Images/simplify_24.png'
    cmd_simplify_curves.small_icon = 'Images/simplify_16.png'
    cmd_simplify_curves.status_bar_text = 'Simplify selected curves'
    cmd_simplify_curves.tooltip = 'Simplify selected curves'
    
    # Menu
    @menu.add_separator
    @menu.add_item( cmd_simplify_curves )
    
    # Toolbar
    @toolbar.add_separator
    @toolbar.add_item( cmd_simplify_curves )
  end # UI
  file_loaded( __FILE__ )
  
  
  ### METHODS ### ----------------------------------------------------------
  
  
  # (!) Progressbar
  def self.simplify_curves
    model = Sketchup.active_model
    
    # Ensure the user has selected something.
    if model.selection.empty?
      UI.messagebox('Nothing selected. :(')
      return false
    end
    
    # Prompt user for epsilon tolerance.
    prompts = ['Max Deviation']
    defaults = [200.mm]
    input = UI.inputbox(prompts, defaults, 'Simplify Curves')
    return if input == false
    epsilon = input.first

    # Find valid curves in the set of entities.
    Sketchup.status_text = 'Gathering curves...'
    t=Time.now
    curves = TT::Edges.find_curves( model.selection, true )
    #curves.reject! { |c| c.size == 1 } # (!) Important to work around SU bug.
    #puts "Curves: #{curves.size} (#{Time.now-t})"
    
    # Validate search.
    if curves.empty?
      UI.messagebox('Sorry. Could not find any connected edges making up any curves')
      return false 
    end
    
    # Calculate simplified curves.
    points_removed = 0
    progress = TT::Progressbar.new( curves, 'Calculating simplified curves' )
    new_curves = []
    for curve in curves
      progress.next
      
      # Generate a sorted point set of the curve.
      vertices = TT::Edges.sort_vertices(curve)
      points = vertices.collect { |v| v.position }
      
      # If epsilon is 0 no simplification is done. The curve is then converted
      # directly into a curve segment.
      if epsilon > 0
        simplified_curve = TT::Point3d.simplify_curve(points, epsilon)
      else
        simplified_curve = points.dup
      end
      
      points_removed += points.length - simplified_curve.length
      
      # Cache the new curve to be recreated later. Modifications to the model
      # is done at the end to avoid iterating over deleted or changed entities.
      new_curve = {
        :material => curve[0].material,
        :layer    => curve[0].layer,
        :points   => simplified_curve
      }
      new_curves << new_curve
    end # for
    
    TT::Model.start_operation('Simplify Curves')
    # Replace old edges with new curves.
    Sketchup.status_text = 'Erasing old curves...'
    # (!) When lone edges are excluded from the curves array, it appear that some
    # edges disappear. As a workaround, even lonely edges are included and recreated.
    # Hard to reliably reproduce.
    model.active_entities.erase_entities( curves.flatten.uniq )

    # Rebuild the new curves. Draw single segments as plain Edges.
    progress = TT::Progressbar.new( curves, 'Recreating curves' )
    for curve in new_curves
      progress.next
      if curve[:points].size > 2
        edges = model.active_entities.add_curve( curve[:points] )
      else
        edges = [ model.active_entities.add_line( *curve[:points] ) ]
      end
      material = curve[:material]
      layer = curve[:layer]
      edges.each { |e|
        e.material = material
        e.layer = layer
      }
    end
    model.commit_operation
    
    # Output statistics to the user.
    results = "Reduced curves by #{points_removed} edges."
    puts results
    Sketchup.status_text = results
    UI.messagebox( results )
  end

  
end # module