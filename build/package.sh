#!/bin/sh

dialog --yesno "Modified lib/dbi/version.rb?" 8 40
if [ $? != 0 ]; then
  dialog --msgbox "Exiting! Please modify lib/dbi/version.rb appropriately, before trying again." 8 40
  rm -rf work/
  exit 1
fi

dialog --yesno "Did you run test.rb in this directory (with both old and new Ruby versions; ruby test.rb ruby18/ruby test.rb ruby)?" 8 40
if [ $? != 0 ]; then
  dialog --msgbox "Exiting! Please run before trying again." 8 40
  rm -rf work/
  exit 1
fi

dialog --msgbox "Please tag the trunk like 'svn cp trunk tags/0.1.0'" 8 40

dialog --msgbox "Change to the tags/_your_tag_ directory and make the gem: 'gem -b build/dbi.gemspec'" 8 40

dialog --msgbox "Now log into RubyForge Admin page and make a release. Release is named like '0.1.0'; choose Any and .gem" 8 40

dialog --msgbox "Finally, update the page at the RAA." 8 40
w3m "http://raa.ruby-lang.org/update.rhtml?name=ruby-dbi"
