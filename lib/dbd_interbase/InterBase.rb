#
# $Id: InterBase.rb,v 1.1 2001/05/30 12:40:21 michael Exp $
# Copyright (c) 2001 by Michael Neumann
#

require "interbase"

module DBI
module DBD
module InterBase

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

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
  end

end

class Database < DBI::BaseDatabase
 
  def disconnect
    #@handle.rollback   # is called implicit by #close
    @handle.close
  end

  def ping
    klass = ::InterBase::Error
    begin
      stmt = execute("SELECT * FROM RDB$RELATIONS")
      stmt.fetch
      stmt.finish
      return true
    rescue klass 
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
  end

  def rollback
    @handle.rollback
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
  end

  def finish
    @handle.drop
  end

  def fetch
    @handle.fetch
  end

  def column_info
    retval = []

    @handle.description.each {|col| 
      retval << {'name' => col[0] }
    }
    retval
  end

  def rows
    nil
  end

end


end # module InterBase
end # module DBD
end # module DBI




