#
# $Id: Oracle.rb,v 1.1 2001/05/30 12:40:58 michael Exp $
# Copyright (c) 2001 by Michael Neumann
# 

require "oracle"

module DBI
module DBD
module Oracle

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end

  def default_user
    ['scott', 'tiger']
  end

  def data_sources
    # read from $ORACLE_HOME/network/admin/tnsnames.ora
    []
  end

  def connect(dbname, user, auth, attr)
    # connect to database
    handle = ::ORAconn.logon(user, auth, dbname)
    return Database.new(handle, attr)
  end

end

class Database < DBI::BaseDatabase
 
  def disconnect
    @handle.rollback
    @handle.logoff 
  end

  def ping
    begin
      stmt = execute("SELECT SYSDATE FROM DUAL /* ping */")
      stmt.fetch
      stmt.finish
      return true
    rescue OCIError
      return false
    end
  end

  def tables
    stmt = execute("SELECT table_name FROM user_tables")  
    rows = stmt.fetch_all || []
    stmt.finish
    rows.collect {|row| row[0]} 
  end

  def prepare(statement)
    cursor = @handle.open
    cursor.parse(statement)
    Statement.new(cursor)
  end

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

  def commit
    @handle.commit
  end

  def rollback
    @handle.rollback
  end

end # class Database


class Statement < DBI::BaseStatement

  def initialize(handle)
    @handle = handle
    @params = []
    @arr = []
  end

  def bind_param(param, value, attribs)

    # TODO: check attribs
    ##
    # which SQL type?
    #
    if value.kind_of? Integer
      vtype = ::Oracle::INTEGER
    elsif value.is_a? Float
      vtype = ::Oracle::FLOAT
    elsif value.is_a? DBI::Binary
      vtype = ::Oracle::LONG_RAW
    else
      vtype = ::Oracle::VARCHAR2
    end

    param = ":#{param}" if param.is_a? Fixnum
    @handle.bindrv(param, value.to_s, vtype)
  end

  def execute
    colnr = 1
    loop {
      colinfo = @handle.describe(colnr)

      break if colinfo.nil?

      collength, coltype = colinfo[3], colinfo[1]

      coltype = case coltype
        when ::Oracle::NUMBER then ::Oracle::FLOAT
        when ::Oracle::DATE   then ::Oracle::VARCHAR2
        else coltype
      end

      @handle.define(colnr, collength, coltype)

      colnr += 1
    }
    @ncols = colnr - 1

    @rows = @handle.exec
  end

  def finish
    @handle.close
  end

  def fetch
    rpc = @handle.fetch
    return nil if rpc.nil?

    (1..@ncols).each do |colnr|
      @arr[colnr-1] = @handle.getCol(colnr)[0]
    end 

    @arr
  end

  def column_info
    retval = []
    colnr = 1
    loop {
      colinfo = @handle.describe(colnr)
      break if colinfo.nil?
      
      retval << {'name' => colinfo[2] }

      colnr += 1
    }
    retval
  end

  def rows
    @rows
  end

end


end # module Oracle
end # module DBD
end # module DBI




