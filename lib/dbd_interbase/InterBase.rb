# 
# DBD::InterBase
# $Id: InterBase.rb,v 1.3 2001/06/07 10:42:13 michael Exp $
# 
# Version : 0.1
# Author  : Michael Neumann (neumann@s-direktnet.de)
#
# Copyright (c) 2001 Michael Neumann
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



require "interbase"

module DBI
module DBD
module InterBase

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

IBError = ::InterBase::Error

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end

  # database=xxx;[charset=xxx]
  def connect(dbname, user, auth, attr)
    # connect to database
    hash = Utils.parse_params(dbname)

    if hash['database'].nil? 
      raise InterfaceError, "must specify database"
    end

    params = []
    params << hash['charset'] unless hash['charset'].nil? 

    handle = ::InterBase::Connection.connect(hash['database'], user, auth, *params)
    return Database.new(handle, attr)
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

end

class Database < DBI::BaseDatabase
 
  def disconnect
    #@handle.rollback   # is called implicit by #close
    @handle.close
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def ping
    begin
      stmt = execute("SELECT * FROM RDB$RELATIONS")
      stmt.fetch
      stmt.finish
      return true
    rescue IBError
      return false
    end
  end

  def tables
    stmt = execute("SELECT RDB$RELATION_NAME FROM RDB$RELATIONS")  
    rows = stmt.fetch_all || []
    stmt.finish
    rows.collect {|row| row[0]} 
  end

  def prepare(statement)
    Statement.new(@handle.cursor, statement)
  end

=begin
  def []=(attr, value)
    case attr
    when 'AutoCommit'
      if value
        @handle.commiton
      else
        @handle.commitoff
      end
    else
      raise NotSupportedError
    end
    @attr[attr] = value
  end
=end

  def commit
    @handle.commit
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def rollback
    @handle.rollback
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

end # class Database


class Statement < DBI::BaseStatement

  def initialize(cursor, statement)
    @handle = cursor
    @statement = statement
    @params = []
  end

  def bind_param(param, value, attribs)
    raise InterfaceError, "only ? parameters supported" unless param.is_a? Fixnum
    @params[param-1] = value 
  end

  def execute
    @handle.execute(@statement, *@params)
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def finish
    @handle.drop
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def fetch
    @handle.fetch
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def column_info
    retval = []

    @handle.description.each {|col| 
      retval << {'name' => col[0] }
    }
    retval
  rescue IBError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def rows
    nil
  end

end


end # module InterBase
end # module DBD
end # module DBI

