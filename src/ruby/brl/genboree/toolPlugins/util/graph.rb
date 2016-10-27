require 'RMagick'
require 'rvg/rvg'
include Magick

module BRL ; module Genboree; module ToolPlugins ; module Util

# Generic Graph class
class Graph
    attr_accessor :title, :subtitle
end

# Generic 2D graph class
class Graph2D < Graph
    attr_accessor :xaxis, :yaxis, :legend
end

# ROC Curve graph
class ROC < Graph2D
    attr_accessor :points

    #---------------------------------------------------------------------------
    # * *Function*: ROC graph constructor.
    #
    # * *Usage*   : <tt>  ROC.new() </tt>
    # * *Args*    :
    #   - +none+ ->
    # * *Returns* :
    #   - +instance+ ->
    # * *Throws* :
    #   - +none+
    #---------------------------------------------------------------------------
    def initialize()
       @xaxis = { :label=>"", :size=>100 }
       @yaxis = { :label=>"", :size=>100 }
       @points = Array.new
    end

    #---------------------------------------------------------------------------
    # * *Function*: Method used for actual drawing of graph object.  Returns an RMagic Image
    #
    # * *Usage*   : <tt> myRoc.draw() </tt>
    # * *Args*    :
    #   - +none+ ->
    # * *Returns* :
    #   - +none+ ->
    # * *Throws* :
    #   - +none+
    #---------------------------------------------------------------------------
    def draw( )
        rvg = Magick::RVG.new( 500, 500 ) do |canvas|
            canvas.background_fill = "white"

            # Draw x and y axis
            canvas.g.styles( :stroke=>'black', :stroke_width=>2 ) do |_axis|
                _axis.polygon(70, 430, 470, 430, 70, 430).styles(:fill=>'black')
                _axis.polygon(70, 30,  70,  430, 70, 30).styles(:fill=>'black')
            end

            # Tick marks
            tick = RVG::Group.new do |_tick|
                _tick.polygon( 10, 10, 10, 20, 10, 10 )
            end
            index = 5
            while( index <= 100 )
                tmp = index * 4
                canvas.use( tick ).translate( (60+tmp), 415 ) # X
                canvas.use( tick ).translate( 85, (420-tmp) ).rotate( 90 ) # Y

                # Every 10%, draw axis tick mark
                if( index%20 == 0 )
                    canvas.text( (60+tmp), 450 ){ |tm| tm.tspan("#{index}%").styles( :font_size=>16, :font_family=>'Helvetica', :fill=>'black' ) }
                    canvas.text( 22, (435-tmp) ){ |tm| tm.tspan("#{index}%").styles(:font_size=>16, :font_family=>'Helvetica', :fill=>'black' ) }
                    # Major grid lines
                    canvas.polygon( 70+tmp, 430, 70+tmp, 30, 70+tmp, 430 ).styles( :fill=>'#CCCCCC', :fill_opacity=>0.9 )
                    canvas.polygon( 70, (430-tmp), 470, (430-tmp), 70, (430-tmp)) .styles( :fill=>'#CCCCCC', :fill_opacity=>0.9)
                elsif( index%5 == 0 )
                    # Minor grid lines
                    canvas.polygon( 70+tmp, 430, 70+tmp, 30, 70+tmp, 430 ).styles( :fill=>'#CCCCCC', :fill_opacity=>0.4 )
                    canvas.polygon( 70, (430-tmp), 470, (430-tmp), 70, (430-tmp)) .styles( :fill=>'#CCCCCC', :fill_opacity=>0.4)
                end
                index += 5
            end

            # Walk through the points, draw
            @points.each{ |xx,yy,label|
                canvas.g.translate( 70+xx*400, 430-(yy*400) ) do |point|
                    point.circle( 4 ).styles( :fill=>'red' )
                end
            }

            # Draw Legend
            # TODO

            # Draw title
            canvas.text( 270, 20 ){ |title| title.tspan("ROC Curve").styles( :font_family=>'Helvetica', :fill=>'black', :text_anchor=>'middle', :font_size=>20 ) }
            # Draw axis labels
            canvas.text( 270, 470 ){ |xlabel| xlabel.tspan("Specificity").styles( :font_family=>'Helvetica', :fill=>'black', :text_anchor=>'middle', :font_size=>14 ) }
            canvas.text( 5, 220 ){ |xlabel| xlabel.tspan("Sensitivity").styles( :glyph_orientation_vertical=>90, :writing_mode=>'tb', :font_family=>'Helvetica', :fill=>'black', :text_anchor=>'middle', :font_size=>14 ) }.rotate( 180 )

        end

        # Draw to canvas and write out
        return rvg.draw
    end
end # class Graph

# Example usage
#g = ROC.new
#g.title = "ROC Curve"
#g.xaxis[:label] = "Percent Specificity"
#g.yaxis[:label] = "Percent Sensitivity"
#g.points.push( [ 35, 100, "A" ] )
#g.points.push( [ 55, 95, "B" ] )
#g.points.push( [ 65, 80, "C" ] )
#g.points.push( [ 70, 70, "D" ] )
#g.draw( "/users/ml142326/public_html/test.png" )

end ; end ; end ; end # BRL ; ToolPlugins ; Util
