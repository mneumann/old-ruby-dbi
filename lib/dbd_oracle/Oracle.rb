# 
# DBD::Oracle
# $Id: Oracle.rb,v 1.3 2001/06/07 10:42:14 michael Exp $
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




#
# copied some code from lib/oracle.rb of Oracle 7 Module
# 

require "oracle"    # only depends on the oracle.so 
class OCIError
  def to_i
    if self.to_s =~ /^ORA-(\d+):/
      return $1.to_i
    end
    0
  end
end

module DBI
module DBD
module Oracle


  VARCHAR2 = 1
  NUMBER = 2
  INTEGER = 3 ## external
  FLOAT = 4   ## external
  LONG = 8
  ROWID = 11
  DATE = 12
  RAW = 23
  LONG_RAW = 24
  UNSIGNED_INT = 68 ## external
  CHAR = 96
  MLSLABEL = 105





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
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

end # class Driver


class Database < DBI::BaseDatabase
 
  def disconnect
    @handle.rollback
    @handle.logoff 
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
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
    Statement.new(@handle, statement)
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

  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

  def commit
    @handle.commit
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

  def rollback
    @handle.rollback
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

end # class Database


class Statement < DBI::BaseStatement

  def initialize(handle, statement)
    parse(handle, statement)
    @arr = Array.new(@ncols)
  end

  def bind_param(param, value, attribs)

    # TODO: check attribs
    ##
    # which SQL type?
    #
    #if value.kind_of? Integer
    #  vtype = INTEGER
    #elsif value.is_a? Float
    #  vtype = FLOAT

    if value.is_a? DBI::Binary
      vtype = LONG_RAW
    else
      vtype = VARCHAR2
    end

    param = ":#{param}" if param.is_a? Fixnum
    @handle.bindrv(param, value.to_s, vtype)
   
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

  def cancel
    @handle.cancel
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

  def execute
    @rows = @handle.exec
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

  def finish
    @handle.close
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

  def fetch
    rpc = @handle.fetch
    return nil if rpc.nil?

    (1..@ncols).each do |colnr|
      @arr[colnr-1] = @handle.getCol(colnr)[0]
    end 

    @arr
  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

  def column_info
    @colinfo
  end

  def rows
    @rows
  end

  private # ---------------------------------------------------

  def parse(handle, statement)
    @handle = handle.open

    begin
      @handle.parse(statement)
    rescue OCIError => err
      retry if err.to_i == 3123  ## block
    end   

    colnr = 1
    @colinfo = []
    loop {
      colinfo = @handle.describe(colnr)
      break if colinfo.nil?

      @colinfo << {'name' => colinfo[2]}

      collength, coltype = colinfo[3], colinfo[1]

      collength, coltype = case coltype
##      when NUMBER
##        [0, FLOAT]
      when NUMBER
        [40, VARCHAR2]
      when VARCHAR2, CHAR
        [(collength*1.5).ceil, VARCHAR2]
      when LONG
        [65535, LONG]
      when LONG_RAW
        [65535, LONG_RAW]
      else
        [collength, VARCHAR2]
      end
 

      #coltype = case coltype
      #  when ::Oracle::NUMBER then ::Oracle::FLOAT
      #  when ::Oracle::DATE   then ::Oracle::VARCHAR2
      #  else coltype
      #end

      @handle.define(colnr, collength, coltype)

      colnr += 1
    }
    @ncols = colnr - 1

  rescue OCIError => err
    raise DBI::DatabaseError.new(err.message, err.to_i)
  end

end


end # module Oracle
end # module DBD
end # module DBI

