=begin
= Ruby/DBI - a database independent interface for accessing databases - similar to Perl's DBI
$Id: index.rd,v 1.3 2001/06/07 19:10:25 michael Exp $

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

== Acknowledgments
Version 0.0.5 of Ruby/DBI was a complete rewrite of version 0.0.4, which
was written by Rainer Perl. Thanks to him and to Jim Weirich who helped a
lot and wrote the database driver for PostgreSQL.

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

  depend on the Ruby/ODBC binding by Christian Werner <chw@ch-werner.de> ((<URL:http://www.ch-werner.de/rubyodbc>)) or
  available from the RAA. Works also together with unixODBC.

* Oracle ((*(dbd_oracle)*))

  depend on the "Oracle 7 Module for Ruby" version 0.2.11 by Yoshida Masato, available from RAA.

* PostgreSQL ((*(dbd_postgresql)*))

  depend on Noboru Saitou's Postgres Package:
  ((<URL:http://www.ruby-lang.org/en/raa-list.rhtml?name=postgres>))

* Proxy/Server ((*(dbd_proxy)*))

  depend on distributed Ruby (DRb) available from RAA.

* Sybase ((*(dbd_sybase)*))
  
  this DBD is currently outdated and will ((*not*)) work with DBI 0.0.5 !!! 


== Download

The newest version in 0.0.5.

: Ruby/DBI 0.0.5

  ((<URL:http://www.ruby-projects.org/dbi/ruby-dbi-all-0.0.5.tar.gz>))


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
   dbh.do("insert into simple01 (SongName, SongLength_s) VALUES (?, ?)", "Song #{i}", "#{i*10}")
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

=end 
