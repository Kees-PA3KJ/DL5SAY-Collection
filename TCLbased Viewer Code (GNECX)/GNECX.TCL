#!/usr/local/bin/bltwish

cd /usr/ham/tclnec

namespace import blt::*

bltdebug 0
set necfile "undefined"
set show    "arrl"
set maxgain 0
set theta 60
set phi 0
set Z0  50

vector gain(181)
vector angle(181)
vector negangle(181)
vector newgain(181)

vector gainx(361)
vector anglex(361)
vector newgainx(361)

# The graphic-nec window

wm minsize   .  170 280
wm maxsize   .  170 280
wm title     . "GNEC"
wm iconname  . "GNEC"


# gnec-controls
frame .mbar -borderwidth 1 -relief raised
menubutton .mbar.file -text " File " -menu .mbar.file.m
menubutton .mbar.opt -text "Options" -menu .mbar.opt.m
menu  .mbar.file.m
menu  .mbar.opt.m
label .cal -text "Selected Antenna:"
label .ant -text " $necfile "
frame .sep  -height 2 -borderwidth 1 -relief sunken
frame .sep1 -height 2 -borderwidth 1 -relief sunken
.mbar.file.m add command -label "Load NEC-File" -command {
                 set necfile [tk_getOpenFile -initialdir /usr/ham/tclnec/antennas]
                 set tailfile [file tail     $necfile]
                 set rootfile [file rootname $tailfile]
                .ant configure -text $tailfile
                 
	     }

.mbar.file.m add command -label "Save OUT-File" -command {
		 
                 set savefile [tk_getSaveFile -initialdir /usr/ham/tclnec/results]
                 if {$savefile != ""} {
                     file copy -force ./output_nec $savefile 
                    }
	     }

.mbar.file.m add command -label "Clear Screen"      -command {
                 if {[winfo exists .rectangular] == 1} {
                      destroy .rectangular 
                     }
                 if {[winfo exists .polar] == 1} {
                      destroy .polar
                     }
                 if {[winfo exists .arrl] == 1} {
                      destroy .arrl
                     }
                 if {[winfo exists .facts] == 1} { 
                      destroy .facts 
                     }
                 if {[winfo exists .near] == 1} { 
                      destroy .near 
                     }
             }

.mbar.file.m add command -label "Exit "      -command exit
.mbar.opt.m  add command -label "Change Phi" -command phi_entry
.mbar.opt.m  add command -label "Change Z0 " -command phi_entry 
.mbar.opt.m  add command -label "Change NF " -command phi_entry 

frame       .rbox 
label       .rbox.title  -text "View:"
frame       .rbox.border -borderwidth 2 -relief groove

radiobutton .rbox.border.rectang -text "Rectangular"\
                                       -command ""\
                                       -variable show -value "rect"
                                        
radiobutton .rbox.border.polar   -text "Polar"\
                                       -command ""\
                                       -variable show -value "polar" 

radiobutton .rbox.border.arrl    -text "ARRL"\
                                       -command ""\
                                       -variable show -value "arrl" 

radiobutton .rbox.border.facts   -text "Facts"\
                                       -command ""\
                                       -variable show -value "facts" 



###############################
# Calculate elevation pattern #
###############################

button .elev -text "Elevation" -command {
                                pre_elev $necfile
                                set info [exec ./nec2]


    if {[winfo exists .rectangular] == 1} {
        destroy .rectangular 
    }
    if {[winfo exists .polar] == 1} {
        destroy .polar
    }
    if {[winfo exists .arrl] == 1} {
        destroy .arrl
    }
    if {[winfo exists .facts] == 1} { 
        destroy .facts 
    }
    if {[winfo exists .near] == 1} { 
        destroy .near 
    }


# analize NEC output file

set f [open ./output_nec]

####################### look for data in output file

# We will store them in lists
set taglist {}
set seglist {}
set Zrlist  {}
set Zilist  {}
set Zlist   {}
set SWRlist {}

# first, run through the output looking for the right section

while { [gets $f line ] >= 0 } {
    if { [regexp  {ANTENNA INPUT}  $line ] } {

# we are after the impedance and SWR - skip three lines 
gets $f line
gets $f line
gets $f line

# from here, the impedance is buried in the next non-blank lines.
# NEC actually will force us to "count columns" I'm afraid

# the format of the line is

#     2    11-1.00000E+00 0.00000E+00-1.72281E-03 4.25444E-04 5.47085E+02 1.35101E+02 1.72281E-03-4.25444E-04 8.61404E-04
#012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789

# tagnumber         0-5
# segment number    6-11
# voltage    (real) 12-24
# voltage    (imag) 25-37
# current    (real) 38-50
# current    (imag) 51-63
# impedance  (real) 64-76
# impedance  (imag) 77-89
# admittance (real) 90-102
# admittance (imag) 103-115
# power             116-127


# all I really need is the tagnumber, the segment number, and the real and imaginary
# impedance

# read the next line
gets $f line
while {[string length $line] > 0 } {
#    puts "impedance line $line"
    set tagnumber [string range $line 0 5]
    lappend taglist $tagnumber
    set seg [string range $line 6 11]
    lappend seglist $seg
    set Zr [string range $line 64 76]
    lappend Zrlist $Zr
    set Zi [string range $line 77 89]
#    puts "Z is $Zr + j * $Zi"
    lappend Zilist $Zi
    gets $f line
#    puts "$tagnumber - $seg Zr $Zr Zi $Zi"
    set normZ [ expr sqrt ( $Zr * $Zr + $Zi * $Zi) ]
    lappend Zlist $normZ
#    puts "|Z| is $normZ"
    set gamma [expr sqrt( (($Zr - 50) *($Zr - 50) + $Zi * $Zi )/( ($Zr + 50) * ($Zr + 50) + $Zi * $Zi ) ) ]
    set SWR [expr (1 + $gamma) /(1 - $gamma)]
#    puts "SWR is $SWR to 1"
    lappend SWRlist $SWR
}
}
#### end of impedance and SWR section

### on to the power budget


    if { [regexp  {POWER BUDGET}  $line ] } {

# we are after the total input power - skip two lines 
gets $f line
gets $f line

set pwr [string range $line 58 69]
#puts $pwr

}

### on to the radiation patterns

    if { [regexp  {RADIATION}  $line ]} {

# we skip seven lines and then start loading the vectors
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line

# now start the loop again, loading the vectors
# We assume we are doing an elevation plot and that
# we are using one of our "standard RP cards" so that
# there will be at most 181 entries for gain.
## RP  0  181    1 1001  -90.0  0.0  1.0  0.0  10000.0 0.00E+00

#
# a line consists of several fields ---
# the first is elevation
# the second is azimuth
# the third and fourth are components
# the fifth is gain
# the rest are junk

# cell counter
set count 0

while { ([gets $f line ] >= 0) && ($count <= 180) } {
    scan $line "%f %f %f %f %f %f %f %s %f %f %f %f" e0 a0 junk1 junk2 g0 junk3 junk4 junk5 junk6 junk7 junk8 junk9
    
    # if the gain is very small, just set it to about -60

    if {$g0 <= -60.0} {
	set g0 -60.0
    }
    set gain($count) $g0
    set angle($count) [expr 180 - $count ]

#  puts "angle - $angle($count) --- gain : $gain($count)"

    # if I find a blank line, I just quit
    if {[string length $line] == 0} {
	break
    }
    set count [expr $count + 1]
}
}
}
close $f


negangle set [angle - 90 ]
negangle set [negangle * -1]

set mingain $gain(min)
set maxgain $gain(max)

##########################################################
# we need to find the angles for which maxgain occurs
# maxgain is at these angles  -- caution - may be a list

set maxangles [gain search $maxgain]
# maxangles may be a list and we must subtract 90 from each

set fixedmaxangles {}

foreach maxangle $maxangles {
    set ya [expr $maxangle - 90]
    lappend fixedmaxangles $ya
}

#puts "list of fixedmaxangles is $fixedmaxangles"

##########################################################
if {$show == "rect"} {

puts "start rectang"  
# the Cartesian Coordinate Window

toplevel    .rectangular
wm title    .rectangular "Cartesian Coordianates"
wm iconname .rectangular "Cartesian"

# controls
frame .rectangular.geometry2
frame .rectangular.controls

#the Cartesian coordinate system
graph  .rectangular.cartesian -title "      Vertical Cartesian Power Graph"
button .rectangular.controls.postscript -text "Save to Postscript File" -command {
.rectangular.cartesian postscript output "./results/$rootfile.ps"
}
pack .rectangular.geometry2 .rectangular.controls
pack .rectangular.cartesian  -in .rectangular.geometry2
pack .rectangular.controls.postscript 

# a Cartesian graph is easy
.rectangular.cartesian axis configure "x" -step 30.0

.rectangular.cartesian element create "e1" -label "Cartesian" \
	-xdata negangle -ydata gain \
	-label "Max Gain is $maxgain" \
        -color red \
	-symbol "none"

.rectangular.cartesian marker create text -name ant_marker \
		-text "$tailfile, azimuth = $phi'" \
		-coords { 0 $gain(min)}
  

}
# we need to scale the gain vector by adding the minimum gain
# to each entry

# vector newgain(180)
newgain set  [gain - $mingain]

# create two vectors to contain the points
vector x(181) y(181)

# create a  unit circle  line
vector yDB(181)
vector xDB(181)

for {set i 0} {$i <= 180} {incr i 1} {
    set radians [expr  $angle($i) * 3.14159/180.0 ]
    set x($i) [expr cos($radians) * $newgain($i)]
    set y($i) [expr sin($radians) * $newgain($i)]
    set xDB($i) cos($radians)
    set yDB($i) sin($radians)
}

#################################### Polar Coordinates part
# the linear Polar Coordinate Window
if {$show == "polar"} {

puts  "start polar"
toplevel    .polar
wm title    .polar "Linear Polar Coordianates" 
wm iconname .polar "Polar lin"

graph  .polar.graph -title "Vertical Linear Power Graph" -width 520 -height 225
frame  .polar.controls
pack   .polar.graph .polar.controls
button .polar.controls.postscript -text "Save to Postscript File" -command { .polar.graph  postscript output "./results/$rootfile.ps" -landscape true
}
pack   .polar.controls.postscript

.polar.graph axis configure y -hide yes 
.polar.graph axis configure x -hide yes
.polar.graph element create "e1" -label "Gain(DBi)" \
	-xdata x -ydata y \
	-color red \
	-symbol "none"


################################################
######## put the scales on the graph
    # create a 0 DB line
    set scale $newgain(max)
    set originalscale $scale
    vector x0db(181)
    vector y0db(181)
 
    y0db set [yDB * $scale]
    x0db set [xDB * $scale]

# we need to put radials on the graph

for {set i 0} {$i < 181} {incr i 5} {
    
    vector create pgridx[expr $i](2)
    vector create pgridy[expr $i](2)
    set pgridx[expr $i](0) 0
    set pgridy[expr $i](0) 0

    set pxlabel [expr $originalscale * $xDB($i)]
    set pgridx[expr $i](1) $pxlabel
    set pylabel [expr $originalscale * $yDB($i)]
    set pgridy[expr $i](1) $pylabel

    set widthofline 1
    if { ($i % 30 ) == 0 } {
	set widthofline 2
	set textlabel [expr $i - 90]
	.polar.graph marker create text -name polar_marker($i) \
		-text "$textlabel" -xoffset 1 -yoffset 1 \
		-coords { $pxlabel $pylabel}
    }

    .polar.graph element create "line$i" \
	    -xdata pgridx[expr $i] -ydata pgridy[expr $i] \
	    -color cyan \
	    -label "" \
	    -symbol "none" -linewidth $widthofline
}
#####################################

# put the data on the graph, with maxgain at 0DB
.polar.graph element create "e2" -label "0 DB reference is $maxgain" \
	-xdata x0db -ydata y0db \
	-color blue \
	-symbol "none"



# bottom half of the circle
vector yref(181)
yref set [y0db * -1]
# .polar.graph element create "bottom" -label "" \
#  	-xdata x0db -ydata yref \
#	-color white \
#	-symbol "none" 


######################### linear log scale here

## build a loop to put each of the grid lines on the graph
set counter 0
while {$scale > 10} {
    set counter [expr $counter + 10]
    vector create x[expr $counter](181) 
    vector create y[expr $counter](181) 
 
    set scale [expr $scale - 10]
    x[expr $counter] set [xDB * $scale]
    y[expr $counter] set [yDB * $scale]

    .polar.graph element create "e$scale" -label "-$counter DB" \
	    -xdata x[expr $counter] -ydata y[expr $counter]  \
	    -color blue \
	    -symbol "none"
    }
.polar.graph marker create text -name ant_marker \
		-text "$tailfile, azimuth = $phi'" \
		-coords { 0 0}
  
}
#  end of linear polar coordinate window


#################################### ARRL Polar
# the ARRL  Coordinate Window
if {$show == "arrl"} {

puts  "start arrl"
toplevel    .arrl
wm title    .arrl "ARRL Scale Polar Coordianates"
wm iconname .arrl "polar log"
graph  .arrl.graph -title "Vertical ARRL Power Graph" -width 580 -height 260
frame  .arrl.controls

button .arrl.controls.postscript -text "Save to Postscript File" -command {
       .arrl.graph  postscript output "./results/$rootfile.ps" -landscape true
}
pack   .arrl.graph .arrl.controls
pack   .arrl.controls.postscript 

# create two vectors to contain the points

# original data is in newgain vector

vector xarrl(181) yarrl(181)


for {set i 0} {$i <= 180} {incr i 1} {
    set radians [expr  $angle($i) * 3.14159/180.0 ]
    set xarrl($i) [expr cos($radians) * exp(0.43439/0.98*$newgain($i)/10)]
    set yarrl($i) [expr sin($radians) * exp(0.43439/0.98*$newgain($i)/10)]
}



.arrl.graph axis configure y -hide yes
.arrl.graph axis configure x -hide yes
.arrl.graph element create "e1" -label "Gain(DBi)" \
	-xdata xarrl -ydata yarrl \
	-color red \
	-symbol "none"


################################################
######## put the scales on the graph
    # create a 0 DB line 
    set originalscale $newgain(max)
    vector x0dbarrl(181)
    vector y0dbarrl(181)
    vector y0neg(181)

#set up the data on the graph
for {set i 0} {$i <= 180} {incr i 1} {
    set y0dbarrl($i) [expr exp(0.43439/0.98*$originalscale/10.0) * $yDB($i)]
    set x0dbarrl($i) [expr exp(0.43439/0.98*$originalscale/10.0) * $xDB($i)]
}
y0neg set [y0dbarrl * -1]

#####################################

# put the data on the graph, with maxgain at 0DB
.arrl.graph element create "e2" -label "0 DB reference is $maxgain" \
	-xdata x0dbarrl -ydata y0dbarrl \
	-color blue \
	-symbol "none"

# .arrl.graph element create "nege2" -label "" \
#	-xdata x0dbarrl -ydata y0neg \
#	-color white \
#	-symbol "none" 

######################### ARRL log scale here

## build a loop to put each of the grid lines on the graph
set counter 0
set arrlsteps {3 6 10 20 30 40 50 60 70 80}
set scale $originalscale

# we need to put radials on the graph

for {set i 0} {$i <= 180} {incr i 5} {
    vector gridx[expr $i](2)
    vector gridy[expr $i](2)
    set gridx[expr $i](0)  0
    set gridy[expr $i](0) 0

    set xlabel     [expr exp(0.43439/0.98*$originalscale/10.0) * $xDB($i)]
    set gridx[expr $i](1) $xlabel

    set ylabel [expr exp(0.43439/0.98*$originalscale/10.0) * $yDB($i)]
    set gridy[expr $i](1) $ylabel


        
    set widthofline 1
    if { ($i % 30 ) == 0 } {
	set widthofline 2
	set textlabel [expr $i - 90]
	.arrl.graph marker create text -name first_marker{$i} \
		-text "$textlabel" -xoffset 1 -yoffset 1 \
		-coords { $xlabel $ylabel}
    } 
    .arrl.graph element create "l$i" \
	    -xdata gridx[expr $i] -ydata gridy[expr $i] \
	    -color cyan \
	    -label "" \
	    -symbol "none" -linewidth $widthofline


    
}


#radials
while {$scale > 10} {
    set thisstep [lindex $arrlsteps $counter]
    set counter [expr $counter + 1]
    vector xarrl[expr $counter](181)
    vector yarrl[expr $counter](181)
    set scale [expr $originalscale - $thisstep ]
    xarrl[expr $counter] set [yDB * $scale]
    yarrl[expr $counter] set [xDB *  $scale]
    #set up the data on the graph
    for {set i 0} {$i <= 180} {incr i 1} {
	set yarrl[expr $counter]($i) [expr exp(0.43439/0.98*$scale/10.0) * $yDB($i)]
	set xarrl[expr $counter]($i) [expr exp(0.43439/0.98*$scale/10.0) * $xDB($i)]
    }
    .arrl.graph element create "e$scale" -label "-$thisstep DB" \
	    -xdata xarrl[expr $counter] -ydata yarrl[expr $counter] \
	    -color blue \
	    -symbol "none"
    
}
  
.arrl.graph marker create text -name ant_marker \
		-text "$tailfile, azimuth = $phi'" \
		-coords { 0 0}
    
}
#  end of linear ARRL coordinate window
##########################################################

##################  The Factlist window
if {$show == "facts"} {

puts  "start facts"
toplevel    .facts
wm title    .facts "Fact List"
wm iconname .facts "Facts"

frame .facts.controls
frame .facts.text

listbox   .facts.text.box -width 70 -yscrollcommand ".facts.text.scroller set" \
        	-background white
scrollbar .facts.text.scroller -command ".facts.text.box  yview" \
        	-background grey

pack .facts.text .facts.controls
pack .facts.text.box .facts.text.scroller -fill y -in .facts.text -side left

.facts.text.box insert end " Maximum gain is $maxgain"
.facts.text.box insert end " Maximum gain occurs at these elevation angles: $fixedmaxangles"
.facts.text.box insert end ""
.facts.text.box insert end " Azimuth = $phi'"
.facts.text.box insert end " Z0 = $Z0 Ohm"
.facts.text.box insert end ""
.facts.text.box insert end " Here is a list of the feed points wire tags, with impedances and SWR:"

.facts.text.box insert end " Tag  Seg                  Complex Impedance               |Z|           SWR"

set indexnumber 0
foreach ofthetag $taglist {

    set tag [lindex $taglist  $indexnumber]
    set seg [lindex $seglist  $indexnumber] 
    set ZR  [lindex $Zrlist   $indexnumber]
    set ZI  [lindex $Zilist   $indexnumber]
    set Zed [lindex $Zlist    $indexnumber]
    set SWR [lindex $SWRlist  $indexnumber]
   .facts.text.box insert end "$tag $seg      $ZR + $ZI * j     $Zed    $SWR to 1"
set indexnumber [expr $indexnumber + 1]
}

.facts.text.box insert end ""
#.facts.text.box insert end " Total input power: $pwr Watts"
#.facts.text.box insert end ""

}
# file delete ./output_nec ./input_nec        
 

}

#############################
# Calculate azimuth pattern #
#############################

button .az   -text " Azimuth " -command {
                                theta_entry
                                pre_az $necfile $theta
                                set info [exec ./nec2]


    if {[winfo exists .rectangular] == 1} {
        destroy .rectangular 
    }
    if {[winfo exists .polar] == 1} {
        destroy .polar
    }
    if {[winfo exists .arrl] == 1}  {
        destroy .arrl
    }
    if {[winfo exists .facts] == 1} { 
        destroy .facts 
    }
    if {[winfo exists .near] == 1} { 
        destroy .near 
    }


# analize NEC output file

set f [open ./output_nec]

####################### try for impendance and SWR

# We will store them in lists
set taglist {}
set seglist {}
set Zrlist  {}
set Zilist  {}
set Zlist   {}
set SWRlist {}

# first, run through the output looking for the right section

while { [gets $f line ] >= 0 } {
    if { [regexp  {ANTENNA INPUT}  $line ] } {
	break
    }
}

# we are after the impedance and SWR - skip three lines 
gets $f line
gets $f line
gets $f line

# from here, the impedance is buried in the next non-blank lines.
# NEC actually will force us to "count columns" I'm afraid

# the format of the line is

#     2    11-1.00000E+00 0.00000E+00-1.72281E-03 4.25444E-04 5.47085E+02 1.35101E+02 1.72281E-03-4.25444E-04 8.61404E-04
#012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789

# tagnumber         0-5
# segment number    6-11
# voltage    (real) 12-24
# voltage    (imag) 25-37
# current    (real) 38-50
# current    (imag) 51-63
# impedance  (real) 64-76
# impedance  (imag) 77-89
# admittance (real) 90-102
# admittance (imag) 103-115
# power             116-127


# all I really need is the tagnumber, the segment number, and the real and imaginary
# impedance


# read the next line
gets $f line
while {[string length $line] > 0 } {
#    puts "impedance line $line"
    set tagnumber [string range $line 0 5]
    lappend taglist $tagnumber
    set seg [string range $line 6 11]
    lappend seglist $seg
    set Zr [string range $line 64 76]
    lappend Zrlist $Zr
    set Zi [string range $line 77 89]
#    puts "Z is $Zr + j * $Zi"
    lappend Zilist $Zi
    gets $f line
#    puts "$tagnumber - $seg Zr $Zr Zi $Zi"
    set normZ [ expr sqrt ( $Zr * $Zr + $Zi * $Zi) ]
    lappend Zlist $normZ
#    puts "|Z| is $normZ"
    set gamma [expr sqrt( (($Zr - 50) *($Zr - 50) + $Zi * $Zi )/( ($Zr + 50) * ($Zr + 50) + $Zi * $Zi ) ) ]
    set SWR [expr (1 + $gamma) /(1 - $gamma)]
#    puts "SWR is $SWR to 1"
    lappend SWRlist $SWR
}

#### end of impedance and SWR section

### on the power budget

while { [gets $f line ] >= 0 } {
    if { [regexp  {POWER BUDGET}  $line ] } {
	break
    }
}

# we are after the total input power - skip two lines 
gets $f line
gets $f line

set pwr [string range $line 58 69]
#puts $pwr

### on to the radiation patterns

while { [gets $f line ] >= 0 } {

    if { [regexp  {RADIATION}  $line ] } {
	break
    }   
}

# we skip seven lines and then start loading the vectors
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line

# now start the loop again, loading the vectors
# We assume we are doing an azimuth plot and that
# we are using one of our "standard RP cards" so that
# there will be at most 361 entries for gain.
## RP  0  1  361   1001  $theta 0   0  1  10000.0 0.00E+00

#
# a line consists of several fields ---
# the first is elevation
# the second is azimuth
# the third and fourth are components
# the fifth is gain
# the rest are junk

# cell counter
set count 0

while { ([gets $f line ] >= 0) && ($count <= 360) } {
    scan $line "%f %f %f %f %f %f %f %s %f %f %f %f" e0 a0 junk1 junk2 g0 junk3 junk4 junk5 junk6 junk7 junk8 junk9
    
    # if the gain is very small, just set it to about -60
    if {$g0 <= -60.0} {
	set g0 -60.0
    }
    set gainx($count) $g0
    set anglex($count) $count

    # if I find a blank line, I just quit
    if {[string length $line] == 0} {
	break
    }
    set count [expr $count + 1]

}

close $f


set mingain $gainx(min)
set maxgain $gainx(max)

if {[expr ( $maxgain - $mingain)] <= 10 } {
    set mingain [expr $mingain -10 ]
}

newgainx set  [gainx - $mingain]

##########################################################
# we need to find the angles for which maxgain occurs
# maxgain is at these angles  -- caution - may be a list

set maxangles [gainx search $maxgain]
# maxangles may be a list 



##########################################################
if {$show == "rect"} {

puts "start rectang"  
# the Cartesian Coordinate Window

toplevel    .rectangular
wm title    .rectangular "Cartesian Coordianates"
wm iconname .rectangular "Cartesian"

# controls
frame .rectangular.geometry2
frame .rectangular.controls

#the Cartesian coordinate system
graph  .rectangular.cartesian -title "X-Y Power Plane Cartesian Coordinates"
button .rectangular.controls.postscript -text "Save to Postscript File" -command {
.rectangular.cartesian postscript output "./results/$rootfile.ps"
}
pack .rectangular.geometry2 .rectangular.controls
pack .rectangular.cartesian  -in .rectangular.geometry2
pack .rectangular.controls.postscript 

# a Cartesian graph is easy
.rectangular.cartesian axis configure "x" -step 60.0

.rectangular.cartesian element create "e1" -label "Cartesian" \
	-xdata anglex -ydata gainx \
	-label "Gain(DBi) is $maxgain" \
        -color red \
	-symbol "none"


# we need to scale the gain vector by adding the minimum gain
# to each entry

#scaled data can be displayed
#.rectangular.cartesian element create "e2" -label "Cartesian" \
#	-xdata anglex -ydata newgainx \
#	-label "Scaled Gain" \
#	-color red \
#	-symbol "none"

.rectangular.cartesian marker create text -name ant_marker \
	-text "$tailfile, elevation = $theta'" \
	-coords { 180 $gainx(min)}

}


# create two vectors to contain the points used for polar coordinate
vector azx(361) azy(361)

# create a  unit circle  line
vector azyDB(361)
vector azxDB(361)
vector azx0db(361)
vector azy0db(361)
 

#################################### Polar Coordinates part
# the linear Polar Coordinate Window
if {$show == "polar"} {

puts  "start polar"
toplevel    .polar
wm title    .polar "Polar Coordianates" 
wm iconname .polar "Polar lin"

graph  .polar.graph -title "X-Y Linear Power Polar Graph" -width 500 -height 370
frame  .polar.controls
pack   .polar.graph .polar.controls
button .polar.controls.postscript -text "Save to Postscript File" -command { .polar.graph  postscript output "./results/$rootfile.ps" -landscape true
}
pack   .polar.controls.postscript

for {set i 0} {$i <= 360} {incr i 1} {
    set radians [expr  $anglex($i)  * 3.14159/180.0 ]
    set azx($i) [expr cos($radians) * $newgainx($i)]
    set azy($i) [expr sin($radians) * $newgainx($i)]
    set azxDB($i) cos($radians)
    set azyDB($i) sin($radians)
}

.polar.graph axis configure y -hide yes
.polar.graph axis configure x -hide yes
.polar.graph element create "e1" -label "Gain" \
	-xdata azx -ydata azy \
	-color red \
	-symbol "none"


################################################
######## put the scales on the graph
    # create a 0 DB line
    set scale $newgainx(max)
    set originalscale $scale
   
    azy0db set [azyDB * $scale]
    azx0db set [azxDB * $scale]

# we need to put radials on the graph

for {set i 0} {$i < 361} {incr i 5} {
    vector pgridx[expr $i](2)
    vector pgridy[expr $i](2)
    set pgridx[expr $i](0) 0
    set pgridy[expr $i](0) 0
    
    set widthofline 1
    if { ($i % 30 ) == 0 } {
	set widthofline 2
    } 
	
    set pgridx[expr $i](1) [expr $originalscale * $azxDB($i)]

    set pgridy[expr $i](1) [expr $originalscale * $azyDB($i)]
        
    .polar.graph element create "line$i" \
	    -xdata pgridx[expr $i] -ydata pgridy[expr $i] \
	    -color cyan \
	    -label "" \
	    -symbol "none" -linewidth $widthofline
}
#####################################

# put the data on the graph, with maxgain at 0DB
.polar.graph element create "e2" -label "0 DB reference is $maxgain" \
	-xdata azx0db -ydata azy0db \
	-color blue \
	-symbol "none"

######################### linear log scale here

## build a loop to put each of the grid lines on the graph
set counter 0
while {$scale > 10} {
    set counter [expr $counter + 10]
    vector azx[expr $counter](361)
    vector azy[expr $counter](361)
    set scale [expr $scale - 10]
    azx[expr $counter] set [azxDB * $scale]
    azy[expr $counter] set [azyDB * $scale]
   .polar.graph element create "e$scale" -label "-$counter DB" \
	    -xdata azx[expr $counter] -ydata azy[expr $counter] \
	    -color blue \
	    -symbol "none"
    
}
.polar.graph marker create text -name ant_marker \
	-text "$tailfile, elevation = $theta'" \
	-coords { 0 0}
  

}

#  end of linear polar coordinate window

##########################################################
if {$show == "arrl"} {
#################################### ARRL Polar
# the ARRL  Coordinate Window
puts  "start arrl"
toplevel    .arrl
wm title    .arrl "ARRL Scale Polar Coordianates"
wm iconname .arrl "polar log"
graph  .arrl.graph -title "X-Y ARRL Power Graph" -width 500 -height 370
frame  .arrl.controls
button .arrl.controls.postscript -text "Save to Postscript File" -command {
       .arrl.graph  postscript output "./results/$rootfile.ps" -landscape true
}
pack   .arrl.graph .arrl.controls
pack   .arrl.controls.postscript 


# create two vectors to contain the points

# original data is in newgain vector

vector azxarrl(361) azyarrl(361)

for {set i 0} {$i <= 360} {incr i 1} {
    set radians [expr  $anglex($i) * 3.14159/180.0 ]
    set azxarrl($i) [expr cos($radians) * exp(0.43439/0.98*$newgainx($i)/10)]
    set azyarrl($i) [expr sin($radians) * exp(0.43439/0.98*$newgainx($i)/10)]
    set azxDB($i) cos($radians)
    set azyDB($i) sin($radians)
}

.arrl.graph axis configure y -hide yes
.arrl.graph axis configure x -hide yes
.arrl.graph element create "e1" -label "Gain" \
	-xdata azxarrl -ydata azyarrl \
	-color red \
	-symbol "none"


################################################
######## put the scales on the graph
    # create a 0 DB line 
    set originalscale $newgainx(max)
    vector azx0dbarrl(361)
    vector azy0dbarrl(361)

#set up the data on the graph
for {set i 0} {$i <= 360} {incr i 1} {
    set azy0dbarrl($i) [expr exp(0.43439/0.98*$originalscale/10.0) * $azyDB($i)]
    set azx0dbarrl($i) [expr exp(0.43439/0.98*$originalscale/10.0) * $azxDB($i)]
}

#####################################

# put the data on the graph, with maxgain at 0DB
.arrl.graph element create "e2" -label "0 DB reference is $maxgain" \
	-xdata azx0dbarrl -ydata azy0dbarrl \
	-color blue \
	-symbol "none"

######################### ARRL log scale here

## build a loop to put each of the grid lines on the graph
set counter 0
set arrlsteps {3 6 10 20 30 40 50 60 70 80}
set scale $originalscale

# we need to put radials on the graph

for {set i 0} {$i < 361} {incr i 5} {
    vector gridx[expr $i](2)
    vector gridy[expr $i](2)
    set gridx[expr $i](0) 0
    set gridy[expr $i](0) 0

    set gridx[expr $i](1) [expr exp(0.43439/0.98*$originalscale/10.0) * $azxDB($i)]
    set gridy[expr $i](1) [expr exp(0.43439/0.98*$originalscale/10.0) * $azyDB($i)]

    set widthofline 1
    if { ($i % 30 ) == 0 } {
	set widthofline 2
    } 
        
    .arrl.graph element create "l$i" \
	    -xdata gridx[expr $i] -ydata gridy[expr $i] \
	    -color cyan \
	    -label "" \
	    -symbol "none" -linewidth $widthofline
}


while {$scale > 10} {
    set thisstep [lindex $arrlsteps $counter]
    set counter [expr $counter + 1]
    vector azxarrl[expr $counter](361)
    vector azyarrl[expr $counter](361)
    set scale [expr $originalscale - $thisstep ]
    azxarrl[expr $counter] set [azyDB * $scale]
    azyarrl[expr $counter] set [azxDB * $scale]
    #set up the data on the graph
    for {set i 0} {$i <= 360} {incr i 1} {
	set azyarrl[expr $counter]($i) [expr exp(0.43439/0.98*$scale/10.0) * $azyDB($i)]
	set azxarrl[expr $counter]($i) [expr exp(0.43439/0.98*$scale/10.0) * $azxDB($i)]
    }
    .arrl.graph element create "e$scale" -label "-$thisstep DB" \
	    -xdata azxarrl[expr $counter] -ydata azyarrl[expr $counter] \
	    -color blue \
	    -symbol "none"
    
}
.arrl.graph marker create text -name ant_marker \
	-text "$tailfile, elevation = $theta'" \
	-coords { 0 0}


    
}
#  end of linear ARRL coordinate window

##########################################################
if {$show == "facts"} {
##################  The Factlist window

puts  "start facts"
toplevel    .facts
wm title    .facts "Fact List"
wm iconname .facts "Facts"

frame .facts.controls
frame .facts.text

listbox .facts.text.box -width 70 -yscrollcommand ".facts.text.scroller set" \
	-background white
scrollbar .facts.text.scroller -command ".facts.text.box  yview" \
	-background grey

pack .facts.text .facts.controls
pack .facts.text.box .facts.text.scroller -fill y -in .facts.text -side left

.facts.text.box insert end " Maximum gain is $maxgain"
.facts.text.box insert end " Maximum gain occurs at these azimuth angles: $maxangles"
.facts.text.box insert end " Gain at 180 degrees is $gainx(180)"
.facts.text.box insert end ""
.facts.text.box insert end " Elevation = $theta'"
.facts.text.box insert end " Z0 = $Z0 Ohm"
.facts.text.box insert end ""
.facts.text.box insert end " Here is a list of the feed points wire tags, with impedances and SWR:"

.facts.text.box insert end " Tag  Seg                  Complex Impedance               |Z|           SWR"

set indexnumber 0
foreach ofthetag $taglist {

    set tag [lindex $taglist  $indexnumber]
    set seg [lindex $seglist  $indexnumber] 
    set ZR  [lindex $Zrlist   $indexnumber]
    set ZI  [lindex $Zilist   $indexnumber]
    set Zed [lindex $Zlist    $indexnumber]
    set SWR [lindex $SWRlist  $indexnumber]
   .facts.text.box insert end "$tag $seg      $ZR + $ZI * j     $Zed    $SWR to 1"
    set indexnumber [expr $indexnumber + 1]
}

#.facts.text.box insert end ""
#.facts.text.box insert end " Total input power: $pwr Watts"

}
}


################################
# Calculate E and H Near Field #
################################

button .nf -text "Near Field" -command {
                                pre_elev $necfile
                                set info [exec ./nec2]


    if {[winfo exists .rectangular] == 1} {
        destroy .rectangular 
    }
    if {[winfo exists .polar] == 1} {
        destroy .polar
    }
    if {[winfo exists .arrl] == 1} {
        destroy .arrl
    }
    if {[winfo exists .facts] == 1} { 
        destroy .facts 
    }
    if {[winfo exists .near] == 1} { 
        destroy .near 
    }


# analize NEC output file

set f [open ./output_nec]

####################### look for data in output file

# We will store them in lists

set xlist   {}
set ylist   {}
set zlist   {}
set Exlist  {}
set Eylist  {}
set Ezlist  {}
set Elist   {}
set Hlist   {}
set distlist {}

# first, run through the output looking for the right section

set NE 0
set NH 0

while { [gets $f line ] >= 0 } {

### on to the power budget

    if { [regexp  {POWER BUDGET}  $line ] } {

# we are after the total input power - skip two lines 
gets $f line
gets $f line

set pwr [string range $line 58 69]
#puts $pwr

}


### on to the near field

    if { [regexp  {NEAR ELEC}  $line ] } {

set NE "ok"
# we are after the location and field stength - skip five lines 
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line

while {[string length $line] > 0 } {

    scan $line "%f %f %f %f %f %f %f %f %f" lx ly lz Ex junk1 Ey junk2 Ez junk3 
    
#    puts "near field line $line"
#    set lx [string  range $line  0 12]
    lappend xlist $lx
#    set ly [string  range $line 13 23]
    lappend ylist $ly
#    set lz [string  range $line 24 34]
    lappend zlist $lz
#    set Ex [string range $line 40 49]
    lappend Exlist $Ex
#    set Ey [string range $line 63 72]
    lappend Eylist $Ey
#    set Ez [string range $line 86 95]
    lappend Ezlist $Ez
#    puts "field points: $lx $ly $lz $Ex $Ey $Ez "
    set dist [expr sqrt( $lx * $lx + $ly * $ly + $lz * $lz ) ]
    lappend distlist $dist
    set E [ expr sqrt ( pow($Ex,2) + pow($Ey,2) + pow($Ez,2) ) ]
    lappend Elist $E
    gets $f line
}
}

    if { [regexp  {NEAR MAGN}  $line ] } {

set NH "ok"
# we are after the location and field stength - skip five lines 
gets $f line
gets $f line
gets $f line
gets $f line
gets $f line

while {[string length $line] > 0 } {

    scan $line "%f %f %f %f %f %f %f %f %f" lx ly lz Hx junk1 Hy junk2 Hz junk3 
    
#    puts "near field line $line"
#    puts "field points: $lx $ly $lz $Hx $Hy $Hz "
    set H [ expr sqrt ( pow($Hx,2) + pow($Hy,2) + pow($Hz,2) ) ]
    lappend Hlist $H
    gets $f line
}
}
}
##################  The Near Field Strength window

puts  "start near"
toplevel    .near
wm title    .near "Near Field Strength"
wm iconname .near "Near"

frame .near.controls
frame .near.text

listbox   .near.text.box -width 70 -yscrollcommand ".near.text.scroller set" \
        	-background white
scrollbar .near.text.scroller -command ".near.text.box  yview" \
        	-background grey

pack .near.text .near.controls
pack .near.text.box .near.text.scroller -fill y -in .near.text -side left


.near.text.box insert end ""
.near.text.box insert end " Total input power: $pwr Watts"
.near.text.box insert end ""
.near.text.box insert end " Here is a list of locations, with total E and H  field strength of the near field:"  
.near.text.box insert end " x             y             z        total distance in m      |E| in V/m   |H| in A/m         E/H"
puts "NE and NH $NE $NH "

if { ( $NE == "ok" )  && ( $NH == "ok" ) } {

    set indexnumber 0
    foreach ofthetag $xlist {

    set   lx [lindex $xlist  $indexnumber]
    set   ly [lindex $ylist  $indexnumber]
    set   lz [lindex $zlist  $indexnumber]
    set dist [lindex $distlist  $indexnumber]
    set    E [lindex $Elist  $indexnumber]
    set    H [lindex $Hlist  $indexnumber]
    set    Zspace [expr $E/$H ]
   .near.text.box insert end " $lx         $ly         $lz           $dist                $E      $H     $Zspace"
    set indexnumber [expr $indexnumber + 1]
}
} else {
   .near.text.box insert end ""
   .near.text.box insert end " NEC-input file has no NE or no NH card !"      
}
# file delete ./output_nec ./input_nec        
 
}



pack .mbar -fill x 
pack .mbar.file -side left      
pack .mbar.opt -side left
pack .cal -fill x
pack .ant -fill x
pack .sep -fill x
pack .rbox -padx 4 -pady 4 
pack .rbox.title -side top -anchor w
pack .rbox.border -expand yes -fill both
pack .rbox.border.rectang -side top -anchor w
pack .rbox.border.polar   -side top -anchor w
pack .rbox.border.arrl    -side top -anchor w
pack .rbox.border.facts   -side top -anchor w
pack .elev  -expand yes -fill both
pack .az    -expand yes -fill both
pack .sep1  -fill x
pack .nf    -expand yes -fill both
.elev configure -activebackground IndianRed1 -background khaki 
.az   configure -activebackground IndianRed1 -background khaki
.nf   configure -activebackground IndianRed1 -background khaki
.sep  configure -background cyan
.sep1 configure -background cyan


proc pre_elev {datafile} {
    global phi
    set pre [open $datafile]
    set nec [open ./input_nec "w"]
    if { [file exists ./output_nec] == 1} {
          file delete ./output_nec
    }
    while { [gets $pre line ] >= 0 } {
    # throw away all the RP lines
	if { ([regexp  {^RP[.]*}  $line ]  == 0) && ([regexp {^EN[.]*} $line ] == 0 )  } {
	    puts $nec "$line"
	}
        
	if { ([regexp  {^RP[.]*}  $line ]  != 0)} {
#            puts "$line"
            scan  $line "%s %d %d %d %d %d %d %f %f %f %f" junk0 a0 junk1 junk2 junk3 junk4 junk5 junk6 junk7 junk8 junk9
#            puts "$a0" 
	}    
    }

      set rpstring [format "%s %d %d %d %d %d %d %d %d %d %E" RP  $a0  181    1 1001  -90  $phi  1  0  10000 0.00E+00]
#      puts "$rpstring" 
      puts  $nec $rpstring 
#     puts  $nec "RP  0  180    1 1001  -90.  0.  1.  0.  10000.0 0.00E+00" 
      puts  $nec "EN"
      close $pre
      close $nec

      return

}


proc pre_az {datafile theta} {
    set pre [open $datafile]
    set nec [open ./input_nec "w"]
    if { [file exists ./output_nec] == 1} {
          file delete ./output_nec
    }
    while { [gets $pre line ] >= 0 } {
    # throw away all the RP lines
	if { ([regexp  {^RP[.]*}  $line ]  == 0) && ([regexp {^EN[.]*} $line ] == 0 )  } {
	    puts $nec "$line"
	}
        
	if { ([regexp  {^RP[.]*}  $line ]  != 0)} {
#            puts "$line"
            scan  $line "%s %d %d %d %d %d %d %f %f %f %f" junk0 a0 junk1 junk2 junk3 junk4 junk5 junk6 junk7 junk8 junk9
#            puts "$a0" 
	}    
    }

      set rpstring [format "%s %d %d %d %d %d %d %d %d %d %E" RP  $a0  1  361 1001  $theta  0  0  1  10000 0.00E+00]
      puts  $nec $rpstring  
      puts  $nec "EN"
      close $pre
      close $nec

      return
}



proc theta_entry {} {

global theta

toplevel   .ent
wm title   .ent "Elevation Angle"
wm minsize .ent  200 80
frame    .ent.f
label    .ent.f.title  -text "Enter Elevation Angle:"
entry    .ent.theta
button   .ent.ok -text "OK" -command { set theta [.ent.theta get] }
.ent.theta insert 0 "$theta"
pack .ent.f -padx 4 -pady 4
pack .ent.f.title -side top -anchor w
pack .ent.theta
pack .ent.ok
bind .ent.theta <KeyPress-Return> { .ent.ok invoke }
focus .ent.ok
vwait theta
destroy .ent
return

}

proc phi_entry {} {

global phi

toplevel   .ent
wm title   .ent "Azimuth Angle"
wm minsize .ent  200 80
frame    .ent.f
label    .ent.f.title  -text "Enter Azimuth Angle:"
entry    .ent.phi
button   .ent.ok -text "OK" -command { set phi [.ent.phi get] }
.ent.phi insert 0 "$phi"
pack .ent.f -padx 4 -pady 4
pack .ent.f.title -side top -anchor w
pack .ent.phi
pack .ent.ok
bind .ent.phi <KeyPress-Return> { .ent.ok invoke }
focus .ent.ok
vwait phi
destroy .ent
return

}










