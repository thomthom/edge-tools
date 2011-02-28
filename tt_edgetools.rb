#-----------------------------------------------------------------------------
# Compatible: SketchUp 6 (PC)
#             (other versions untested)
#-----------------------------------------------------------------------------
#
# CHANGELOG
#
# 2.0.2 - 06.02.2011
#		 * Fixed namespace reference issue
#
# 2.0.1 - 06.02.2011
#		 * Fixed namespace issue
#
# 2.0.0 - 01.02.2011
#		 * Initial release.
#
#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-----------------------------------------------------------------------------

module TT
  module Plugins
    module EdgeTools
    
  ### CONSTANTS ### --------------------------------------------------------
  
  VERSION   = '2.0.3'.freeze
  PREF_KEY  = 'TT_EdgeTools'.freeze
  TITLE     = 'Edge Tools²'.freeze
  
  
  ### EXTENSION ### --------------------------------------------------------
  
  path = File.dirname( __FILE__ )
  core = File.join( path, 'TT_EdgeTools', 'core.rb' )
  ex = SketchupExtension.new( TITLE, core )
  ex.version = VERSION
  ex.copyright = 'Thomas Thomassen © 2010—2011'
  ex.creator = 'Thomas Thomassen (thomas@thomthom.net)'
  ex.description = 'Suite of tools for manipulating edges.'
  ::Sketchup.register_extension( ex, true )
  
    end
  end
end # module


#-----------------------------------------------------------------------------
file_loaded( __FILE__ )
#-----------------------------------------------------------------------------