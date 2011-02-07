#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.5.0', 'Edge Tools²')

#-----------------------------------------------------------------------------

module TT::Plugins::EdgeTools
  
  
  ### MODULE VARIABLES ### -------------------------------------------------
  
  @settings = TT::Settings.new(PREF_KEY)
  
  unless file_loaded?( __FILE__ )
    @menu = TT.menu('Tools').add_submenu('Edge Tools²')
    @toolbar = UI::Toolbar.new('Edge Tools²')
  
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


#-----------------------------------------------------------------------------
file_loaded( __FILE__ )
#-----------------------------------------------------------------------------