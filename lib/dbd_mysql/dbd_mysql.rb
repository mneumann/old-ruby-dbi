# Sample MySQL driver for Rainer Perl's DBI-for-Ruby
#
# Based on (and requires) the "MySQL Ruby Module"
# by TOMITA Masahiro <tommy@tmtm.org> http://www.tmtm.org/mysql/
# 
# Version : 0.0.4
# Author  : Rainer Perl (rainer.perl@sprytech.com)
# Homepage: http://www.sprytech.com/~rainer.perl/ruby/
#
# Copyright (c) 2001 Rainer Perl
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

require 'mysql'

module DBI
 module DBD
  module MySQL
  
   class DBHandle
    
    def initialize(db_user, db_pass, db_args)
     db_name, db_host = db_args.split(':') unless db_args.nil?
     db_host='localhost' unless db_host
     @db_handle=Mysql.connect(db_host, db_user, db_pass)
     @db_handle.select_db(db_name) unless !db_name
    end
    
    def disconnect
     @db_handle.close
    end
    
    def do(sqlstring)
     @db_handle.query_with_result = false
     @db_handle.query(sqlstring)
    end
    
    def do_store(sqlstring)
     return ResultHandle.new(@db_handle, sqlstring)
    end
    
    def quote(aString)
     return "'#{Mysql.quote(aString)}'"
    end
    
   end
   
   class ResultHandle
   
    def initialize(db_handle, sqlstring)
     db_handle.query_with_result = true
     @res_handle = db_handle.query(sqlstring)
    end
    
    def fetchrow
     return @res_handle.fetch_row
    end
   
    def fetch_fields
     myFields=Array.new
     @res_handle.fetch_fields.each { |field| myFields.push(Hash['name' => field.name]) }
     return myFields
    end
    
    def finish
     @res_handle.free
    end
   
   end

  end 
 end
end

DBI.register('mysql', DBI::DBD::MySQL)