#!/usr/bin/env ruby

require "date"

Dir.chdir ".."  # This script should be executed from directory src/ (of ruby-dbi cvs repository)

# modify if needed
FILE = "ChangeLog"
DBI_VERSIONS = "./build/DBI-VERSIONS"
USER = "./build/USER"


lines = File.readlines(DBI_VERSIONS)

START_DATE = "1980-01-01 00:00:00"    # a date before all other dates

v = []
lines.each {|l| 
  l.strip!
  next if l.empty? or l[0] == ?#
  v << l.split(/\s+/, 2) 
}

f = File.new(FILE, "w+")

for i in 0..(v.size-1)
  to = v[i] 
  from = v[i+1] || ["none-tag", START_DATE] 

  if to[1] != nil
    f << "\n\n"
    f << "===============================================================================\n"
    f << " Tag #{to[0]} (#{to[1]})\n"
    f << "===============================================================================\n"
    f << "\n\n"
  end
  to[1] ||= (Date.today + 3).to_s  # a day in the future
  f << `./build/cvs2cl -g -d:ext:mneumann@cvs.ruby-dbi.sourceforge.net:/cvsroot/ruby-dbi -l "-d '#{from[1]}<#{to[1]}'" --stdout --prune --utc -U #{USER} --no-wrap -R '^\s*[*]\s*'`
end

f.close
