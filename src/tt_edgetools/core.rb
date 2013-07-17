#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.7.0', 'Edge Tools²' )

module TT::Plugins::EdgeTools
  
  
  ### MODULE VARIABLES ### -------------------------------------------------
  
  @settings = TT::Settings.new(PLUGIN_ID)
  
  unless file_loaded?( __FILE__ )
    @menu = TT.menu('Tools').add_submenu(PLUGIN_NAME)
    @toolbar = UI::Toolbar.new(PLUGIN_NAME)
  
    require 'TT_EdgeTools/divider.rb'
    require 'TT_EdgeTools/close_gaps.rb'
    require 'TT_EdgeTools/simplify.rb'
    require 'TT_EdgeTools/make_colinear.rb'

    # Restore Toolbar
    if @toolbar.get_last_state == TB_VISIBLE
      @toolbar.restore
      UI.start_timer( 0.1, false ) { @toolbar.restore } # SU bug 2902434
    end
  end
  
  
  ### GENERIC METHODS ### --------------------------------------------------
  
  
  ### DEBUG ### ------------------------------------------------------------
  
  def self.reload
    load __FILE__
    load 'TT_EdgeTools/divider.rb'
    load 'TT_EdgeTools/close_gaps.rb'
    load 'TT_EdgeTools/simplify.rb'
    load 'TT_EdgeTools/make_colinear.rb'
  end
  
end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------