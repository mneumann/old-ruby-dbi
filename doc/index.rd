=begin
= Ruby/DBI - a database independent interface for accessing databases - similar to Perl's DBI
$Id: index.rd,v 1.9 2001/08/30 14:01:31 michael Exp $

Copyright (c) 2001 by Michael Neumann (neumann@s-direktnet.de)

== License

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

Optionally this program is released under the same terms of license as Ruby itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

== Contributors

: Rainer Perl 
  Author of Ruby/DBI 0.0.4 from which many good ideas were taken into the nwe completely rewritten version 0.0.5. 
: Jim Weirich
  Author of the PostgreSQL driver (DBD::Pg).
  Wrote many additional code (e.g. sql.rb, testcases). 
  Gave many helpful hints and comments.
: Eli Green
  Implemented DatabaseHandle#columns for Mysql and Pg.
: Masatoshi SEKI
  For his version of module BasicQuote in sql.rb
: John Gorman 
  For his case insensitive load_driver patch and parameter parser.

== Database Drivers (DBDs)

* ADO (ActiveX Data Objects) ((*(dbd_ado)*))
* DB2 ((*(dbd_db2)*))

  depend on Michael Neumann's Ruby/DB2 Module, available from RAA.

* InterBase ((*(dbd_interbase)*))

  depend on the InterBase module available from RAA.

* mSQL ((*(dbd_msql)*))

  depend on the "mSQL Library" by DATE Ken available from the RAA.

* MySQL ((*(dbd_mysql)*))

  depend on the "MySQL Ruby Module" by TOMITA Masahiro <tommy@tmtm.org> ((<URL:http://www.tmtm.org/mysql/>)) or
  available from the RAA.

* ODBC ((*(dbd_odbc)*))

  depend on the Ruby/ODBC (version >= 0.5) binding by Christian Werner <chw@ch-werner.de> 
  ((<URL:http://www.ch-werner.de/rubyodbc>)) or available from the RAA. 
  Works also together with unixODBC.

* Oracle ((*(dbd_oracle)*))

  depend on the "Oracle 7 Module for Ruby" version 0.2.11 by Yoshida Masato, available from RAA.

* PostgreSQL ((*(dbd_pg)*))

  depend on Noboru Saitou's Postgres Package:
  ((<URL:http://www.ruby-lang.org/en/raa-list.rhtml?name=postgres>))

* Proxy/Server ((*(dbd_proxy)*))

  depend on distributed Ruby (DRb) available from RAA.

* Sybase ((*(dbd_sybase)*))
  
  this DBD is currently outdated and will ((*not*)) work with DBI versions > 0.0.4 !!! 


== ChangeLog

See ((<URL:http://www.ruby-projects.org/dbi/dbi/ChangeLog.html>)).

== ToDo

See ((<URL:http://www.ruby-projects.org/dbi/dbi/ToDo.html>)).


== Download

If you're running FreeBSD or NetBSD, have a look at their package collections. FreeBSD has for DBI and each DBD an easy to
install package, NetBSD currently only for PostgreSQL but more is to come.

Latest development snapshot available at ((<URL:http://www.ruby-projects.org/downloads/dbi/ruby-dbi-all-current.tar.gz>)).


: Ruby/DBI 0.0.8

  ((<URL:http://www.ruby-projects.org/downloads/dbi/ruby-dbi-all-0.0.8.tar.gz>))

: Ruby/DBI 0.0.7

  ((<URL:http://www.ruby-projects.org/downloads/dbi/ruby-dbi-all-0.0.7.tar.gz>))

: Ruby/DBI 0.0.6

  ((<URL:http://www.ruby-projects.org/downloads/dbi/ruby-dbi-all-0.0.6.tar.gz>))

: Ruby/DBI 0.0.5

  ((<URL:http://www.ruby-projects.org/downloads/dbi/ruby-dbi-all-0.0.5.tar.gz>))


== Installation

All available DBDs come with this package, but you should only
install the DBDs you really need.

=== To install all:

   ruby setup.rb config
   ruby setup.rb setup
   ruby setup.rb install

=== To install dbi and some DBDs:

   ruby setup.rb config --with=dbi,dbd_pg....
   ruby setup.rb setup
   ruby setup.rb install

Choose the packages to install by specifing them after the option (({--with})).


== Mailing List
There is also a mailing-list for DBI-specific discussions, see
((<URL:http://groups.yahoo.com/group/ruby-dbi-talk>))

== Documentation

See the directories lib/*/doc or ext/*/doc for DBI and DBD specific informations.

The DBI specification is lib/dbi/doc/DBI_SPEC or lib/dbi/doc/html/DBI_SPEC.html or available
from WWW at ((<URL:http://www.ruby-projects.org/dbi/dbi/DBI_SPEC.html>)).

The DBD specification (how to write a database driver) is lib/dbi/doc/DBD_SPEC or lib/dbi/doc/html/DBD_SPEC.html or available
from WWW at ((<URL:http://www.ruby-projects.org/dbi/dbi/DBD_SPEC.html>)).


== Examples

Examples can be found in the examples/ subdirectory.
There is e.g. sqlsh.rb, which is an interactive SQL shell similar to Perl's dbish.rb.
Further there is in this directory the file proxyserver.rb which has to be run if you use the DBD::Proxy, 
to access databases remote over a TCP/IP network. 

=== A simple example
  require 'dbi'

  # connect to a datbase
  dbh = DBI.connect('DBI:Mysql:test', 'testuser', 'testpwd')

  puts "inserting..."
  1.upto(13) do |i|
     sql = "insert into simple01 (SongName, SongLength_s) VALUES (?, ?)"
     dbh.do(sql, "Song #{i}", "#{i*10}")
  end 

  puts "selecting..."
  sth=dbh.prepare('select * from simple01')
  sth.execute

  while row=sth.fetch do
   p row
  end

  puts "deleting..."
  dbh.do('delete from simple01 where internal_id > 10')

  dbh.disconnect

=== The same using Ruby's features

  require 'dbi'

  DBI.connect('DBI:Mysql:test', 'testuser', 'testpwd') do | dbh |

    puts "inserting..."
    sql = "insert into simple01 (SongName, SongLength_s) VALUES (?, ?)"
    dbh.prepare(sql) do | sth | 
      1.upto(13) { |i| sth.execute("Song #{i}", "#{i*10}") }
    end 

    puts "selecting..."
    dbh.select_all('select * from simple01') do
      p row
    end

    puts "deleting..."
    dbh.do('delete from simple01 where internal_id > 10')

  end

=end 
