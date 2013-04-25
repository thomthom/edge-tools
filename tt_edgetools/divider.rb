#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::EdgeTools

  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( __FILE__ )      
    cmd_divide_face = UI::Command.new('Divide Face') {
      self.divide_face
    }
    cmd_divide_face.large_icon = 'Images/divide_24.png'
    cmd_divide_face.small_icon = 'Images/divide_16.png'
    cmd_divide_face.status_bar_text = 'Split faces into multiple pieces'
    cmd_divide_face.tooltip = 'Split faces into multiple pieces'
    
    # Menu
    @menu.add_item( cmd_divide_face )
    
    # Toolbar
    @toolbar.add_item( cmd_divide_face )
  end # UI
  file_loaded( __FILE__ )
  
  
  ### METHODS ### ----------------------------------------------------------
  
  
  def self.divide_face
    Sketchup.active_model.select_tool( DivideFace.new )
  end
  
  
  # (!) Review and cleanup
  class DivideFace
    
    STATE_NORMAL = 0
    STATE_OFFSET = 1
    
    
    def initialize
      @last_ip1 = Sketchup::InputPoint.new
      @last_ip2 = Sketchup::InputPoint.new
      @last_edge = nil
      @last_face = nil
      Sketchup.vcb_label = 'Distance'
    end
    
    def save_cache
      #puts 'save_cache'
      #p [@last_ip1.position, @last_ip2.position, @last_edge, @last_face]
      @last_ip1.copy!(@ip1)
      @last_ip2.copy!(@ip2)
      @last_edge = @picked_edge
      @last_face = @picked_face
      #p [@last_ip1.position, @last_ip2.position, @last_edge, @last_face]
      #puts ' '
    end
    
    def load_cache
      #puts 'load_cache'
      #p [@last_ip1.position, @last_ip2.position, @last_edge, @last_face]
      @ip1.copy!(@last_ip1)
      @ip2.copy!(@last_ip2)
      @picked_edge = @last_edge
      @picked_face = @last_face
      #p [@last_ip1.position, @last_ip2.position, @last_edge, @last_face]
      #puts ' '
    end
    
    
    def activate
      @success = false # Indicates if last operation succeeded
      reset()
    end
    
    
    def reset
      @state = STATE_NORMAL
      @picked_edge = nil
      @picked_face = nil
      @ip1 = Sketchup::InputPoint.new
      @ip2 = Sketchup::InputPoint.new
      
    end
    
    
    def enableVCB?
      return true
    end
    
    
    def onCancel(reason, view)
      reset()
    end
    
    
    def deactivate(view)
      view.invalidate
    end
    
    
    def resume(view)
      Sketchup.vcb_label = 'Distance'
    end
    
    
    def onMouseMove(flags, x, y, view)
      # (!) Select current face.
      case @state
      when STATE_NORMAL
        ip = view.inputpoint(x, y)
        if @picked_edge != ip.edge
          @picked_edge = ip.edge
          view.model.selection.clear
          view.model.selection.add(@picked_edge) if @picked_edge
        end
        @ip1.copy!(ip)
        view.invalidate
      when STATE_OFFSET
        ip = view.inputpoint(x, y)
        if @picked_face != ip.face
          @picked_face = ip.face
          
          #if @picked_face
          #  view.model.selection.clear
          #  view.model.selection.add(@picked_edge, @picked_face)
          #end
        end
        @ip2.copy!(ip)
        
        if @picked_face
          p1 = @ip1.position
          p2 = @ip2.position
          vector = offset_vector(p1, p2, @picked_face.plane)
          #Sketchup.vcb_value = vector.length
          
          # !!
          line2 = offset_line(@picked_edge.line, vector)
          op = p1.project_to_line(line2)
          vector = p1.vector_to( op )
          Sketchup.vcb_value = vector.length
          # !!
        end
        
        view.invalidate
      end
    end
    
    
    def onLButtonDown(flags, x, y, view)
      case @state
      when STATE_NORMAL
        if @picked_edge
          @state = STATE_OFFSET
          @last_distance = nil
        end
      when STATE_OFFSET
        divide()
      end
    end
    
    
    def onUserText(text, view)
      if @state == STATE_OFFSET
        
        begin
          length = text.to_l
        rescue ArgumentError
          length = 0.0.to_l
        end
        
        #puts 'STATE_OFFSET'
        divide(length)
        Sketchup.vcb_value = length
      else
        #puts 'STATE_NORMAL'
        if @last_distance.nil?
          Sketchup.vcb_value = ''
        else
          
          begin
            if result = text.match( /^[*x]\s*(\d+)|(\d+)\s*[*x]/ )
              number = result.to_a.compact[1].to_i
              divide(@last_distance, true, number, :multiply)
            elsif result = text.match( /^\/\s*(\d+)|(\d+)\s*\// )
              number = result.to_a.compact[1].to_i
              divide(@last_distance, true, number, :divide)
            else
              length = text.to_l
              divide(length, true)
              Sketchup.vcb_value = length
            end
          rescue ArgumentError
            length = 0.0.to_l
          end
          
          view.invalidate
        end
      end
    end
    
    
    def draw(view)
      # <debug>
      #view.draw_text([500,50,0], @state.inspect)
      #view.draw_text([500,70,0], @picked_edge.inspect)
      #view.draw_text([500,90,0], @picked_face.inspect)
      #view.draw_text([500,110,0], @ip1.valid?.inspect)
      #view.draw_text([500,130,0], @ip2.valid?.inspect)
      #view.draw_text([500,150,0], @ip1.position.inspect)
      #view.draw_text([500,170,0], @ip2.position.inspect)
      # </debug>
      
      view.line_stipple = ''
      view.line_width = 1     
      if @picked_face && @picked_edge
        p1 = @ip1.position
        p2 = @ip2.position
        # Split Line
        vector = offset_vector(p1, p2, @picked_face.plane)
        line = offset_line(@picked_edge.line, vector)
        # Offset direction
        op = p1.project_to_line(line)
        view.drawing_color = view.model.rendering_options['ForegroundColor']
        view.line_stipple = '-'
        view.draw(GL_LINES, [p1, op])
        # Split Edges
        pts = split_points(line, @picked_face)
        unless pts.empty? || TT.odd?(pts.length)
          #view.draw_text([50,50,0], pts.length.to_s)
          #view.draw_text([50,70,0], pts.inspect)
          view.line_stipple = ''
          view.draw(GL_LINES, pts)
          
          #pts.each_index { |i|
          #  view.draw_text(view.screen_coords(pts[i]), i.inspect)
          #}
          #view.draw_points(pts, 5, 2, [255,0,0])
        end
      end
      @ip1.draw(view) if @ip1.display?
      @ip2.draw(view) if @ip2.display?
    end
    
    
    def divide(length = nil, correct = false, copies = 1, copy_type = :multiply)

      if correct
       #puts 'Undo' if @success
        Sketchup.undo if @success
        load_cache()
      end

      if @picked_face.nil? || @picked_edge.nil?
        @success = false
        return nil
      end

      model = Sketchup.active_model
      p1 = @ip1.position
      p2 = @ip2.position
      source_line = @picked_edge.line
      plane = @picked_face.plane
      vector = offset_vector(p1, p2, plane)
      
      # !!
      line2 = offset_line(source_line, vector)
      op = p1.project_to_line(line2)
      vector = p1.vector_to( op )
      # !!
      
      length = vector.length if length.nil?
      
      if copy_type == :divide
        sub_length = length / copies
      else
        sub_length = length
      end
      
      max_dist = 0
      TT::Model.start_operation('Divide Face')
      edges = []
      (1..copies).each { |i|
        # The sum of the length for this iteration
        step_length = sub_length * i
        # Split Line
        # Input points might not be on face, so project down to face and
        # ensure the line is on the face.
        sub_vector = vector.clone
        sub_vector.length = step_length
        line = offset_line(source_line, sub_vector)
        pts = split_points(line, @picked_face)
        edges << pts unless pts.empty?
      } # each
      len = model.active_entities.length
      if edges.empty?
        #@success = false
        model.abort_operation 
      else
        edges.each { |pts|
          # Draw edges
          #puts 'Draw Edges'
          until pts.empty?
            ep1 = pts.shift
            ep2 = pts.shift
            model.active_entities.add_line(ep1, ep2)
          end
        }
        
        @last_distance = length
        #@success = true
        save_cache()
        model.commit_operation
      end
      @success = (len != model.active_entities.length)

      reset()
    end
    
    
    # p1 and p2 are InputPoint positions. p2 might not be on the plane of the
    # face, so p2 must be projected down to the plane.
    # Then a vector from p1 to the projected point is returned.
    # The length is the vector is adjusted if a length argument is given.
    def offset_vector(p1, p2, plane, length=nil)
      fp = p2.project_to_plane(plane)
      v = p1.vector_to(fp)
      v.length = length unless length.nil?
      v
    end
    
    
    def offset_line(line, vector)
      [ line[0].offset(vector), line[1] ]
    end
    
    
    # Returns an array of Point3d objects for each Edge in Face that the Line
    # intersect.
    def split_points(line, face)
      pts = []
      for edge in face.edges
        next if line[1].parallel?(edge.line[1])
        point = TT::Edge.intersect_line_edge(line, edge)
        pts << point unless point.nil?
      end
      # Sort points along line
      # 1. Find point at one end
      ep = pts.sort { |a,b| line[0].distance(a) <=> line[0].distance(b) }.last
      # 2. Sort points by distance from end point
      pts.sort! { |a,b| ep.distance(a) <=> ep.distance(b) }
      # Ensure an even number is returned
      if TT.odd?(pts.length)
        p1, p2 = pts[0, 2]
        # See if the first set of points both belong to an edge in the face.
        # If it does then it's not needed and it's removed.
        # Otherwise the end point is assumed to be not needed.
        trimmed_start = false
        face.edges.each { |e|
          points = e.vertices.map { |v| v.position }
          if points.include?(p1) && points.include?(p2)
            pts.shift
            trimmed_start = true
            break
          end
        }
        unless trimmed_start
          pts.pop
        end
      end
      pts
    end
    
  end # class DivideFace

  
end # module