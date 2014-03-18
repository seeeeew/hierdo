#!/usr/bin/env tclsh

set windowtitle {Hierarchical ToDo}
set version {0.4.4}
set license {The MIT License (MIT)

Copyright (c) 2013 Sewan Aleanakian <sewan@nyox.de>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.}

# Requirements
package require Tcl 8.5
package require Tk
package require tile
package require msgcat
package require comm
namespace import ::msgcat::mc
wm withdraw .

::msgcat::mcmset {} {
	title {Title}
	effort {Effort}
	cost {Cost}
	note {Note}
	new {New}
	new_item {New item}
	paste {Paste}
	before {before}
	at_start {as first}
	at_end {as last}
	copy {Copy}
	cut {Cut}
	delete {Delete}
	finished {Finished}
	unfinished {Unfinished}
	all_finished {All finished}
	all_unfinished {All unfinished}
	expand_all {Expand all}
	collapse_all {Collapse all}
	information {Information}
	version {Version}
	license {License}
	close {Close}
	already_running {Another instance of this program seems to be already running, but does not respond. Start anyway?}
}
::msgcat::mcmset de_de {
	title {Titel}
	effort {Aufwand}
	cost {Kosten}
	note {Notiz}
	new {Neu}
	new_item {Neuer Knoten}
	paste {Einfügen}
	before {davor}
	at_start {am Anfang}
	at_end {am Ende}
	copy {Kopieren}
	cut {Ausschneiden}
	delete {Löschen}
	finished {Erledigt}
	unfinished {Unerledigt}
	all_finished {Alle erledigt}
	all_unfinished {Alle unerledigt}
	expand_all {Alle aufklappen}
	collapse_all {Alle zuklappen}
	information {Informationen}
	version {Version}
	license {Lizenz}
	close {Schließen}
	already_running {Eine andere Instanz des Programms scheint bereits gestartet zu sein, antwortet aber nicht. Trotzdem starten?}
}
::msgcat::mcload [file join [file dirname [info script]] msgs]

set lockfile [file join $env(HOME) .hierdo_lock]
if {[file exists $lockfile]} {
	set lockfid [open $lockfile {RDONLY}]
	set appid [string trim [read $lockfid]]
	close $lockfid
	if {![catch {comm::comm send $appid raise .}]} {
		exit
	} else {
		set answer [tk_messageBox -title $windowtitle -message [mc already_running] -icon warning -type yesno]
		if {$answer != yes} {
			exit
		}
	}
}
set lockfid [open $lockfile {WRONLY CREAT TRUNC}]
puts $lockfid [comm::comm self]
close $lockfid

if {![catch {package require Tclx}]} {
	signal trap {SIGINT SIGTERM} quit
}

# General Tk stuff
wm deiconify .
bind Treeview <Double-1> {}
bind Treeview <Return> {}
bind Text <Control-a> {%W tag add sel 0.0 {end - 1 chars};%W mark set insert end}
bind Text <<Paste>> {note_paste %W}
bind TEntry <Control-a> {%W selection range 0 end; %W icursor end}
bind TSpinbox <Control-a> {%W selection range 0 end; %W icursor end}

wm title . $windowtitle
wm minsize . 400 300


# global variables
set clicked {}
set item {}
set column {}
set editor {}
set treedata [list]
set copied [list]
set checkmark "\u2714" ;# ✅ \u2705 ✓ \u2713 ✔ \u2714 ☑ \u2611 ☐ \u2610


proc note_paste {W} {
	if {[llength [$W tag ranges sel]]} {
		$W mark set insert sel.first
		$W delete sel.first sel.last
	}
	catch {
		$W insert insert [clipboard get]
	}
}
proc build_gui {} {
	global conf title version license treeview

	tk::panedwindow .pw -orient horizontal

	ttk::frame .tf
	frame .tb -highlightthickness 1 -highlightcolor black
	set treeview [ttk::treeview .tb.tree -columns {time cost progress note} -displaycolumns {time cost progress} -selectmode browse -xscrollcommand {.treescrollx set} -yscrollcommand {.treescrolly set}]
	.tb.tree column #0 -minwidth 100 -stretch true -width 200
	.tb.tree column time -minwidth 50 -stretch false -width 100 -anchor e
	.tb.tree column cost -minwidth 50 -stretch false -width 100 -anchor e
	.tb.tree column progress -minwidth 50 -stretch false -width 100 -anchor e
	.tb.tree heading #0 -text [mc title]
	.tb.tree heading time -text "[mc effort] (h)"
	.tb.tree heading cost -text "[mc cost] (€)"
	.tb.tree heading progress -text "[mc finished] (%)"
	.tb.tree tag configure toplevel -font [font create {*}[font configure TkDefaultFont] -weight bold]
	ttk::scrollbar .treescrollx -orient horizontal -command {tree_xview}
	ttk::scrollbar .treescrolly -orient vertical -command {tree_yview}
	label $treeview.line -background red

	ttk::frame .nf
	ttk::label .note_l -text "[mc note]:"
	text .note -width 0 -xscrollcommand {.notescrollx set} -yscrollcommand {.notescrolly set} -state disabled
	ttk::scrollbar .notescrollx -orient horizontal -command {.note xview}
	ttk::scrollbar .notescrolly -orient vertical -command {.note yview}

	pack .tb.tree -in .tb -expand true -fill both
	grid .tb .treescrolly -in .tf -sticky nesw
	grid .treescrollx -in .tf -sticky nesw
	grid columnconfigure .tf 0 -weight 1
	grid rowconfigure .tf 0 -weight 1
	grid .note_l -in .nf -sticky nesw -columnspan 2
	grid .note .notescrolly -in .nf -sticky nesw
	grid .notescrollx -in .nf -sticky nesw
	grid columnconfigure .nf 0 -weight 1
	grid rowconfigure .nf 1 -weight 1
	.pw add .tf -stretch always -minsize 200
	.pw add .nf -stretch never -minsize 200
	pack .pw -expand true -fill both

	ttk::entry .tb.tree.tetitle
	ttk::spinbox .tb.tree.tetime -from 0 -to 1000000000 -increment 1 -wrap false -justify right -format {%.2f}
	ttk::spinbox .tb.tree.tecost -from 0 -to 1000000000 -increment 100 -wrap false -justify right -format {%.2f}

	menu .treemenu -tearoff false
	
	toplevel .info
	wm withdraw .info
	wm transient .info .
	wm minsize .info 200 150
	wm geometry .info 400x300
	wm title .info [mc information]
	ttk::notebook .info.tabs
	ttk::button .info.close -text [mc close] -command {wm withdraw .info;grab release .info}
	
	ttk::frame .info.tabs.version
	ttk::frame .info.tabs.license
	text .info.tabs.license.text -height 0 -font {TkFixedFont} -wrap word -xscrollcommand {.info.tabs.license.x set} -yscrollcommand {.info.tabs.license.y set}
	.info.tabs.license.text insert 0.0 [regsub -all {([^\n])\n([^\n])} $license {\1 \2}]
	.info.tabs.license.text configure -state disabled
	ttk::scrollbar .info.tabs.license.x -orient horizontal -command {.info.tabs.license.text xview}
	ttk::scrollbar .info.tabs.license.y -orient vertical -command {.info.tabs.license.text yview}
	

	grid .info.tabs.license.text .info.tabs.license.y -in .info.tabs.license -sticky nesw
	grid .info.tabs.license.x -in .info.tabs.license -sticky nesw
	grid columnconfigure .info.tabs.license 0 -weight 1
	grid rowconfigure .info.tabs.license 0 -weight 1
	.info.tabs add .info.tabs.version -text [mc version]
	.info.tabs add .info.tabs.license -text [mc license]
	pack .info.tabs -side top -expand true -fill both
	pack .info.close -side bottom -pady 5
	
	
	update
	
	load_conf
}
proc tree_xview {args} {
	.tb.tree xview {*}$args
	redraw_editor
}
proc tree_yview {args} {
	.tb.tree yview {*}$args
	redraw_editor
}

proc show_popup {X Y x y} {
	global clicked copied
	set item [.tb.tree identify item $x $y]
	set clicked $item
	if {[lsearch [.tb.tree selection] $item] < 0} {
		.tb.tree selection set $item
	}
	
	.treemenu delete 0 end

	.treemenu add command -label "[mc new_item] ([expr {$clicked == {} ? [mc at_start] : [mc before]}])" -command {item_new before}
	.treemenu add command -label "[mc new_item] ([mc at_end])" -command {item_new end}
	.treemenu add command -label "[mc paste] ([expr {$clicked == {} ? [mc at_start] : [mc before]}])" -command {item_paste before} -state [expr {[llength $copied] ? {normal} : {disabled}}]
	.treemenu add command -label "[mc paste] ([mc at_end])" -command {item_paste end} -state [expr {[llength $copied] ? {normal} : {disabled}}]
	.treemenu add command -label [mc copy] -command {item_copy} -state [expr {$clicked == {} ? {disabled} : {normal}}]
	.treemenu add command -label [mc cut] -command {item_cut} -state [expr {$clicked == {} ? {disabled} : {normal}}]
	.treemenu add command -label [mc delete] -command {item_delete} -state [expr {$clicked == {} ? {disabled} : {normal}}]
	.treemenu add separator
	.treemenu add command -label [expr {[llength [.tb.tree children $clicked]] ? [mc all_finished] : [mc finished]}] -command {item_complete} -state [expr {$clicked == {} ? {disabled} : {normal}}]
	.treemenu add command -label [expr {[llength [.tb.tree children $clicked]] ? [mc all_unfinished] : [mc unfinished]}] -command {item_uncomplete} -state [expr {$clicked == {} ? {disabled} : {normal}}]
	.treemenu add separator
	.treemenu add command -label [mc expand_all] -command {tree_expand $clicked}
	.treemenu add command -label [mc collapse_all] -command {tree_collapse $clicked}
	.treemenu add separator
	.treemenu add command -label [mc information] -command {show_info}

	tk_popup .treemenu $X $Y
}
proc get_progress {item} {
	return [expr {[.tb.tree set $item progress] != {}}]
}
proc item_complete {{item {}}} {
	global clicked checkmark
	if {$item == {}} {set item $clicked}
	set children [.tb.tree children $item]
	if {[llength $children]} {
		foreach child $children {
			item_complete $child
		}
	} else {
		.tb.tree set $item progress $checkmark
	}
	if {$item == $clicked} {
		recalc
		save_tree
	}
}
proc item_uncomplete {{item {}}} {
	global clicked
	if {$item == {}} {set item $clicked}
	set children [.tb.tree children $item]
	if {[llength $children]} {
		foreach child $children {
			item_uncomplete $child
		}
	} else {
		.tb.tree set $item progress {}
	}
	if {$item == $clicked} {
		recalc
		save_tree
	}
}
proc item_new {position} {
	global clicked
	if {$position == {end}} {
		set parent $clicked
		set index end
	} else {
		set parent [.tb.tree parent $clicked]
		set index [.tb.tree index $clicked]
	}
	set item [.tb.tree insert $parent $index -text [mc new]]
	if {$parent == {}} {.tb.tree tag add toplevel $item}
	.tb.tree set $item time 0.00
	.tb.tree set $item cost 0.00
	.tb.tree set $item progress {}
	.tb.tree set $item note {}
	.tb.tree item $parent -open true
	.tb.tree selection set $item
	refresh_note
	recalc
	save_tree
}
proc tree_expand {{parent {}}} {
	foreach item [.tb.tree children $parent] {
		tree_expand $item
	}
	.tb.tree item $parent -open true
}
proc tree_collapse {{parent {}}} {
	foreach item [.tb.tree children $parent] {
		tree_collapse $item
	}
	.tb.tree item $parent -open false
}
proc item_paste {position} {
	global clicked copied
	if {$position == {end}} {
		set parent $clicked
		set index end
	} else {
		set parent [.tb.tree parent $clicked]
		set index [.tb.tree index $clicked]
	}
	foreach item $copied {
		import_tree $item $parent $index
		.tb.tree item $parent -open true
	}
	if {[llength $copied] == 1} {
		.tb.tree selection set [lindex [.tb.tree children $parent] $index]
	} elseif {[llength $copied] > 1} {
		.tb.tree selection set $parent
	}
	recalc
}
proc item_copy {} {
	global clicked copied
	set copied [list [list [.tb.tree item $clicked -text] {*}[.tb.tree item $clicked -values] [export_tree $clicked]]]
}
proc item_cut {} {
	global clicked
	item_copy
	item_delete
}
proc item_delete {} {
	global clicked item column editor
	.tb.tree set [.tb.tree parent $clicked] progress {}
	.tb.tree delete $clicked
	set item {}
	set column {}
	set editor {}
	.note delete 0.0 end
	.note configure -state disabled
	recalc
	save_tree
}
proc tree_select {} {
	global item
	save_note
	set selection [.tb.tree selection]
	if {[llength $selection] == 1} {
		set item [lindex $selection 0]
	}
	if {$item != {}} refresh_note
}
proc refresh_note {} {
	global item
	.note configure -state normal
	.note delete 0.0 end
	.note insert end [.tb.tree set $item note]
}
proc save_note {} {
	global item
	if {$item == {}} return
	.tb.tree set $item note [.note get 0.0 {end - 1 chars}]
	save_tree
}
proc redraw_editor {} {
	global item column editor
	if {$item != {} && [winfo exists $editor]} {
		lassign [.tb.tree bbox $item $column] x y width height
		place $editor -in .tb.tree -x $x -y $y -width $width -height $height
		focus $editor
	}
}
proc show_editor {} {
	global item column editor
	if {![winfo exists $editor]} return
	set values(.tb.tree.tetitle) [.tb.tree item $item -text]
	set values(.tb.tree.tetime) [.tb.tree set $item time]
	set values(.tb.tree.tecost) [.tb.tree set $item cost]
	set value [set values($editor)]
	$editor delete 0 end
	$editor insert 0 $value
	redraw_editor
	set pos end
	if {[winfo class $editor] == {TSpinbox}} {
		set pos [string first . $value]
	}
	$editor selection range 0 $pos
	$editor icursor $pos
}
proc hide_editor {{save true}} {
	global item column editor
	if {$save} {
		if {[winfo exists $editor]} {
			set value [$editor get]
			if {$column == {#0}} {
				.tb.tree item $item -text $value
			} else {
				if {[.tb.tree set $item $column] != $value} {
					.tb.tree set $item $column $value
					recalc
				}
			}
			save_tree
		}
	}
	set item {}
	set column {}
	set editor {}
	foreach slave [place slaves .tb.tree] {place forget $slave}
}
proc recalc {{item {}}} {
	set children [.tb.tree children $item]
	if {[llength $children]} {
		set sum_time 0
		set sum_cost 0
		set sum_time_done 0
		foreach child $children {
			lassign [recalc $child] time cost progress
			set sum_time [expr $sum_time+$time]
			set sum_cost [expr $sum_cost+$cost]
			set sum_time_done [expr $sum_time_done+($time*$progress)]
		}
		set sum_progress [expr $sum_time>0?(1.0*$sum_time_done/$sum_time):1]
		.tb.tree set $item time [format %.2f $sum_time]
		.tb.tree set $item cost [format %.2f $sum_cost]
		if {$sum_time > 0} {
			.tb.tree set $item progress [format %.1f [expr $sum_progress*100]]
		} else {
			.tb.tree set $item progress {}
		}
		set sums [list $sum_time $sum_cost $sum_progress]
	} else {
		set sums [list [.tb.tree set $item time] [.tb.tree set $item cost] [get_progress $item]]
	}
	return $sums
}

proc import_tree {tree {parent {}} {index end}} {
	set item [.tb.tree insert $parent $index -text [lindex $tree 0] -values [lrange $tree 1 end-1] -open false]
	if {$parent == {}} {.tb.tree tag add toplevel $item}
	foreach child [lindex $tree end] {
		import_tree $child $item
	}
}
proc export_tree {{parent {}}} {
	set tree [list]
	foreach item [.tb.tree children $parent] {
		set title [.tb.tree item $item -text]
		set values [.tb.tree item $item -values]
		set children [export_tree $item]
		lappend tree [list $title {*}$values $children]
	}
	return $tree
}
proc load_tree {{file {}}} {
	global env treedata
	if {$file == {}} {set file [file join $env(HOME) .hierdo_tree]}
	if {![file exists $file]} return
	set fid [open $file {RDONLY}]
	set new_treedata [read $fid]
	close $fid
	foreach tree $new_treedata {
		import_tree $tree
	}
	recalc
	set treedata [export_tree]
}
proc save_tree {{file {}}} {
	global env treedata
	set new_treedata [export_tree]
	if {$treedata == $new_treedata} return
	if {$file == {}} {set file [file join $env(HOME) .hierdo_tree]}
	set fid [open $file {WRONLY TRUNC CREAT}]
	puts $fid $new_treedata
	close $fid
	set treedata $new_treedata
}
proc load_conf {} {
	global env
	set file [file join $env(HOME) .hierdo_conf]
	if {![file exists $file]} return
	set fid [open $file {RDONLY}]
	set confdata [read $fid]
	close $fid
	array set conf $confdata
	if {[info exists conf(window_width)] && [info exists conf(window_width)]} {
		wm geometry . "$conf(window_width)x$conf(window_height)"
	}
	if {[info exists conf(separator_x)]} {
		update
		.pw sash place 0 $conf(separator_x) 1
	}
	if {[info exists conf(title_width)]} {
		.tb.tree column #0 -width $conf(title_width)
	}
	if {[info exists conf(time_width)]} {
		.tb.tree column time -width $conf(time_width)
	}
	if {[info exists conf(cost_width)]} {
		.tb.tree column cost -width $conf(cost_width)
	}
	if {[info exists conf(progress_width)]} {
		.tb.tree column progress -width $conf(progress_width)
	}
}
proc save_conf {} {
	global env
	set file [file join $env(HOME) .hierdo_conf]
	set fid [open $file {WRONLY TRUNC CREAT}]
	puts $fid "window_width [winfo width .]"
	puts $fid "window_height [winfo height .]"
	puts $fid "separator_x [lindex [.pw sash coord 0] 0]"
	puts $fid "title_width [.tb.tree column #0 -width]"
	puts $fid "time_width [.tb.tree column time -width]"
	puts $fid "cost_width [.tb.tree column cost -width]"
	puts $fid "progress_width [.tb.tree column progress -width]"
	close $fid
}
proc quit {} {
	global lockfile
	focus .
	update
	save_conf
	file delete $lockfile
	exit
}
proc show_info {} {
	wm deiconify .info
	grab set .info
}
set drag_from {}
set drag_to {}
proc drag_start {x y} {
	global treeview drag_from drag_to
	set drag_from [$treeview identify row $x $y]
	set drag_to {}
}
proc drag_update {x y} {
	global treeview drag_from drag_to
	if {[llength $drag_from]} {
		set over [$treeview identify row $x $y]
		set bbox [$treeview bbox $over #0]
		if {![llength $bbox] || $over == $drag_from} {
			set drag_to {}
			place forget $treeview.line
		} else {
			lassign $bbox bb_x bb_y bb_w bb_h
			set line_x $bb_x
			set line_y [expr $y < $bb_y+$bb_h/2.0 ? $bb_y-2 : $bb_y+$bb_h-2]
			set parent [$treeview parent $over]
			set index [$treeview index $over]
			if {$parent == [$treeview parent $drag_from] && $index > [$treeview index $drag_from]} {incr index -1}
			if {[expr $y >= $bb_y+$bb_h*0.5] && $over != $drag_from} {incr index}
			set width [lindex $bbox 2]
			if {$parent == [$treeview parent $drag_from] && $index == [$treeview index $drag_from] || [child_of $drag_from $over]} {
				set drag_to {}
				place forget $treeview.line
			} else {
				set drag_to [list $parent $index]
				place $treeview.line -height 4 -width $width -x $line_x -y $line_y
			}
		}
	}
}
proc drag_end {} {
	global treeview drag_from drag_to
	if {[llength $drag_to]} {
		$treeview move $drag_from {*}$drag_to
		if {[lindex $drag_to 0] == {}} {
			$treeview tag add toplevel $drag_from
		} else {
			$treeview tag remove toplevel $drag_from
		}
	}
	place forget $treeview.line
	set drag_from {}
	set drag_to {}
}
proc child_of {parent child} {
	global treeview
	set result false
	while {$child != {}} {
		set child [$treeview parent $child]
		if {$child == $parent} {set result true}
	}
	return $result
}

build_gui

bind .tb.tree <Button-3> {show_popup %X %Y %x %y}
bind .tb.tree.tetitle <FocusOut> {hide_editor}
bind .tb.tree.tetime <FocusOut> {hide_editor}
bind .tb.tree.tecost <FocusOut> {hide_editor}
bind .tb.tree.tetitle <Return> {hide_editor}
bind .tb.tree.tetime <Return> {hide_editor}
bind .tb.tree.tecost <Return> {hide_editor}
bind .tb.tree.tetitle <Escape> {hide_editor false}
bind .tb.tree.tetime <Escape> {hide_editor false}
bind .tb.tree.tecost <Escape> {hide_editor false}
bind .note <FocusOut> {save_note}
bind .nf <Configure> {focus .pw}
bind .tb.tree <Double-1> {
	set clicked $item
	set item [.tb.tree identify item %x %y]
	set column [.tb.tree identify column %x %y]
	if {$column == {#0}} {
		set editor .tb.tree.tetitle
	} elseif {[.tb.tree column $column -id] == {progress}} {
		if {![llength [.tb.tree children $item]]} {
			if {[get_progress $item]} {
				item_uncomplete $item
			} else {
				item_complete $item
			}
		}
	} else {
		if {[llength [.tb.tree children $item]]} {return}
		set editor .tb.tree.te[.tb.tree column $column -id]
	}
	show_editor
}
bind .tb.tree <Configure> {hide_editor}
bind .tb.tree <<TreeviewSelect>> {tree_select}
bind .tb.tree <ButtonPress-1> {drag_start %x %y}
bind .tb.tree <Motion> {drag_update %x %y}
bind .tb.tree <ButtonRelease-1> {drag_end}
bind .tb.tree <Escape> {if {[llength $drag_from]} {set drag_to {};place forget $treeview.line};set drag_from {}}

wm protocol . WM_DELETE_WINDOW {quit}
wm protocol .info WM_DELETE_WINDOW {wm withdraw .info;grab release .info}

load_tree
