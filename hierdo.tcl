#!/usr/bin/env tclsh

set windowtitle {Hierarchical ToDo}
set version {0.4.1}
set license {Copyright (c) 2013 Sewan Aleanakian <sewan@nyox.de>

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
namespace import ::msgcat::mc
#::msgcat::mcload [file join [file dirname [info script]] msgs]

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
	open_all {Alle aufklappen}
	close_all {Alle zuklappen}
	information {Informationen}
	version {Version}
	license {Lizenz}
	close {Schließen}
}
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
	open_all {Open all}
	close_all {Close all}
	information {Information}
	version {Version}
	license {License}
	close {Close}
}


# General Tk stuff
bind Treeview <Double-1> {}
bind Treeview <Return> {}
bind Text <Control-a> {%W tag add sel 0.0 {end - 1 chars};%W mark set insert end}
bind Text <<Paste>> {note_paste %W}
bind TEntry <Control-a> {%W selection range 0 end; %W icursor end}
bind TSpinbox <Control-a> {%W selection range 0 end; %W icursor end}

wm title . {Hierarchical ToDo}
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
	global conf title version license

	tk::panedwindow .pw -orient horizontal

	ttk::frame .tf
	ttk::treeview .tree -columns {time cost progress note} -displaycolumns {time cost progress} -selectmode browse -xscrollcommand {.treescrollx set} -yscrollcommand {.treescrolly set}
	.tree column #0 -minwidth 100 -stretch true -width 200
	.tree column time -minwidth 50 -stretch false -width 100 -anchor e
	.tree column cost -minwidth 50 -stretch false -width 100 -anchor e
	.tree column progress -minwidth 50 -stretch false -width 100 -anchor e
	.tree heading #0 -text [mc title]
	.tree heading time -text "[mc effort] (h)"
	.tree heading cost -text "[mc cost] (€)"
	.tree heading progress -text "[mc finished] (%)"
	.tree tag configure toplevel -font [font create {*}[font configure TkDefaultFont] -weight bold]
	ttk::scrollbar .treescrollx -orient horizontal -command {tree_xview}
	ttk::scrollbar .treescrolly -orient vertical -command {tree_yview}

	ttk::frame .nf
	ttk::label .note_l -text "[mc note]:"
	text .note -width 0 -xscrollcommand {.notescrollx set} -yscrollcommand {.notescrolly set} -state disabled
	ttk::scrollbar .notescrollx -orient horizontal -command {.note xview}
	ttk::scrollbar .notescrolly -orient vertical -command {.note yview}

	grid .tree .treescrolly -in .tf -sticky nesw
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

	ttk::entry .tree.tetitle
	ttk::spinbox .tree.tetime -from 0 -to 1000000000 -increment 1 -wrap false -justify right -format {%.2f}
	ttk::spinbox .tree.tecost -from 0 -to 1000000000 -increment 100 -wrap false -justify right -format {%.2f}

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
	text .info.tabs.license.text -height 0 -font {TkFixedFont} -xscrollcommand {.info.tabs.license.x set} -yscrollcommand {.info.tabs.license.y set}
	.info.tabs.license.text insert 0.0 $license
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
	.tree xview {*}$args
	redraw_editor
}
proc tree_yview {args} {
	.tree yview {*}$args
	redraw_editor
}

proc show_popup {X Y x y} {
	global clicked copied
	set item [.tree identify item $x $y]
	set clicked $item
	if {[lsearch [.tree selection] $item] < 0} {
		.tree selection set $item
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
	.treemenu add command -label [expr {[llength [.tree children $clicked]] ? [mc all_finished] : [mc finished]}] -command {item_complete} -state [expr {$clicked == {} ? {disabled} : {normal}}]
	.treemenu add command -label [expr {[llength [.tree children $clicked]] ? [mc all_unfinished] : [mc unfinished]}] -command {item_uncomplete} -state [expr {$clicked == {} ? {disabled} : {normal}}]
	.treemenu add separator
	.treemenu add command -label [mc open_all] -command {tree_open}
	.treemenu add command -label [mc close_all] -command {tree_close}
	.treemenu add separator
	.treemenu add command -label [mc information] -command {show_info}

	tk_popup .treemenu $X $Y
}
proc get_progress {item} {
	return [expr {[.tree set $item progress] != {}}]
}
proc item_complete {{item {}}} {
	global clicked checkmark
	if {$item == {}} {set item $clicked}
	set children [.tree children $item]
	if {[llength $children]} {
		foreach child $children {
			item_complete $child
		}
	} else {
		.tree set $item progress $checkmark
	}
	if {$item == $clicked} {
		recalc
		save_tree
	}
}
proc item_uncomplete {{item {}}} {
	global clicked
	if {$item == {}} {set item $clicked}
	set children [.tree children $item]
	if {[llength $children]} {
		foreach child $children {
			item_uncomplete $child
		}
	} else {
		.tree set $item progress {}
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
		set parent [.tree parent $clicked]
		set index [.tree index $clicked]
	}
	set item [.tree insert $parent $index -text [mc new]]
	if {$parent == {}} {.tree tag add toplevel $item}
	.tree set $item time 0.00
	.tree set $item cost 0.00
	.tree set $item progress {}
	.tree set $item note {}
	.tree item $parent -open true
	.tree selection set $item
	refresh_note
	recalc
	save_tree
}
proc tree_open {{parent {}}} {
	foreach item [.tree children $parent] {
		tree_open $item
	}
	.tree item $parent -open true
}
proc tree_close {{parent {}}} {
	foreach item [.tree children $parent] {
		tree_close $item
	}
	.tree item $parent -open false
}
proc item_paste {position} {
	global clicked copied
	if {$position == {end}} {
		set parent $clicked
		set index end
	} else {
		set parent [.tree parent $clicked]
		set index [.tree index $clicked]
	}
	foreach item $copied {
		import_tree $item $parent $index
		.tree item $parent -open true
	}
	if {[llength $copied] == 1} {
		.tree selection set [lindex [.tree children $parent] $index]
	} elseif {[llength $copied] > 1} {
		.tree selection set $parent
	}
	recalc
}
proc item_copy {} {
	global clicked copied
	set copied [list [list [.tree item $clicked -text] {*}[.tree item $clicked -values] [export_tree $clicked]]]
}
proc item_cut {} {
	global clicked
	item_copy
	item_delete
}
proc item_delete {} {
	global clicked item column editor
	.tree set [.tree parent $clicked] progress {}
	.tree delete $clicked
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
	set selection [.tree selection]
	if {[llength $selection] == 1} {
		set item [lindex $selection 0]
	}
	if {$item != {}} refresh_note
}
proc refresh_note {} {
	global item
	.note configure -state normal
	.note delete 0.0 end
	.note insert end [.tree set $item note]
}
proc save_note {} {
	global item
	if {$item == {}} return
	.tree set $item note [.note get 0.0 {end - 1 chars}]
	save_tree
}
proc redraw_editor {} {
	global item column editor
	if {$item != {} && [winfo exists $editor]} {
		lassign [.tree bbox $item $column] x y width height
		place $editor -in .tree -x $x -y $y -width $width -height $height
		focus $editor
	}
}
proc show_editor {} {
	global item column editor
	if {![winfo exists $editor]} return
	set values(.tree.tetitle) [.tree item $item -text]
	set values(.tree.tetime) [.tree set $item time]
	set values(.tree.tecost) [.tree set $item cost]
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
				.tree item $item -text $value
			} else {
				if {[.tree set $item $column] != $value} {
					.tree set $item $column $value
					recalc
				}
			}
			save_tree
		}
	}
	set item {}
	set column {}
	set editor {}
	foreach slave [place slaves .tree] {place forget $slave}
}
proc recalc {{item {}}} {
	set children [.tree children $item]
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
		.tree set $item time [format %.2f $sum_time]
		.tree set $item cost [format %.2f $sum_cost]
		if {$sum_time > 0} {
			.tree set $item progress [format %.1f [expr $sum_progress*100]]
		} else {
			.tree set $item progress {}
		}
		set sums [list $sum_time $sum_cost $sum_progress]
	} else {
		set sums [list [.tree set $item time] [.tree set $item cost] [get_progress $item]]
	}
	return $sums
}

proc import_tree {tree {parent {}} {index end}} {
	set item [.tree insert $parent $index -text [lindex $tree 0] -values [lrange $tree 1 end-1] -open false]
	if {$parent == {}} {.tree tag add toplevel $item}
	foreach child [lindex $tree end] {
		import_tree $child $item
	}
}
proc export_tree {{parent {}}} {
	set tree [list]
	foreach item [.tree children $parent] {
		set title [.tree item $item -text]
		set values [.tree item $item -values]
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
		.pw sash place 0 $conf(separator_x) 1
	}
	if {[info exists conf(title_width)]} {
		.tree column #0 -width $conf(title_width)
	}
	if {[info exists conf(time_width)]} {
		.tree column time -width $conf(time_width)
	}
	if {[info exists conf(cost_width)]} {
		.tree column cost -width $conf(cost_width)
	}
	if {[info exists conf(progress_width)]} {
		.tree column progress -width $conf(progress_width)
	}
}
proc save_conf {} {
	global env
	set file [file join $env(HOME) .hierdo_conf]
	set fid [open $file {WRONLY TRUNC CREAT}]
	puts $fid "window_width [winfo width .]"
	puts $fid "window_height [winfo height .]"
	puts $fid "separator_x [lindex [.pw sash coord 0] 0]"
	puts $fid "title_width [.tree column #0 -width]"
	puts $fid "time_width [.tree column time -width]"
	puts $fid "cost_width [.tree column cost -width]"
	puts $fid "progress_width [.tree column progress -width]"
	close $fid
}
proc quit {} {
	focus .
	update
	save_conf
	exit
}
proc show_info {} {
	wm deiconify .info
	grab set .info
}

build_gui

bind .tree <Button-3> {show_popup %X %Y %x %y}
bind .tree.tetitle <FocusOut> {hide_editor}
bind .tree.tetime <FocusOut> {hide_editor}
bind .tree.tecost <FocusOut> {hide_editor}
bind .tree.tetitle <Return> {hide_editor}
bind .tree.tetime <Return> {hide_editor}
bind .tree.tecost <Return> {hide_editor}
bind .tree.tetitle <Escape> {hide_editor false}
bind .tree.tetime <Escape> {hide_editor false}
bind .tree.tecost <Escape> {hide_editor false}
bind .note <FocusOut> {save_note}
bind .nf <Configure> {focus .pw}
bind .tree <Double-1> {
	set clicked $item
	set item [.tree identify item %x %y]
	set column [.tree identify column %x %y]
	if {$column == {#0}} {
		set editor .tree.tetitle
	} elseif {[.tree column $column -id] == {progress}} {
		if {![llength [.tree children $item]]} {
			if {[get_progress $item]} {
				item_uncomplete $item
			} else {
				item_complete $item
			}
		}
	} else {
		if {[llength [.tree children $item]]} {return}
		set editor .tree.te[.tree column $column -id]
	}
	show_editor
}
bind .tree <Configure> {hide_editor}
bind .tree <<TreeviewSelect>> {tree_select}

wm protocol . WM_DELETE_WINDOW {quit}
wm protocol .info WM_DELETE_WINDOW {wm withdraw .info;grab release .info}

load_tree

