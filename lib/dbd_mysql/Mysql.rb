# 
# DBD::Mysql
# $Id: Mysql.rb,v 1.9 2001/11/09 16:08:02 michael Exp $
# 
# Version : 0.3
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

require "mysql"

module DBI
module DBD
module Mysql

VERSION          = "0.3"
USED_DBD_VERSION = "0.2"

MyError = ::MysqlError

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end

  def connect(dbname, user, auth, attr)
    # connect to database
    hash = Utils.parse_params(dbname)

    if hash['database'].nil? 
      raise DBI::InterfaceError, "must specify database"
    end

    hash['host'] ||= 'localhost'

    handle = ::Mysql.connect(hash['host'], user, auth, hash['database'], hash['port'], hash['socket'], hash['flag'])
    #handle.select_db(hash['database'])

    return Database.new(handle, attr)
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def data_sources
    handle = ::Mysql.new
    res = handle.list_dbs.collect {|db| "dbi:Mysql:database=#{db}" }
    handle.close
    return res
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  # Driver-specific functions ------------------------------------------------

  public

  def __createdb(db, host, user, password, port=nil, sock=nil, flag=nil)
    handle = ::Mysql.connect(host, user, password, nil, port, sock, flag)
    begin
      handle.create_db(db)
    ensure
      handle.close if handle
    end
  end

  def __dropdb(db, host, user, password, port=nil, sock=nil, flag=nil)
    handle = ::Mysql.connect(host, user, password, nil, port, sock, flag)
    begin
      handle.drop_db(db)
    ensure
      handle.close if handle
    end
  end

  def __shutdown(host, user, password, port=nil, sock=nil, flag=nil)
    handle = ::Mysql.connect(host, user, password, nil, port, sock, flag)
    begin
      handle.shutdown
    ensure
      handle.close if handle
    end
  end

  def __reload(host, user, password, port=nil, sock=nil, flag=nil)
    handle = ::Mysql.connect(host, user, password, nil, port, sock, flag)
    begin
      handle.reload
    ensure
      handle.close if handle
    end
  end

end # class Driver

class Database < DBI::BaseDatabase
  include SQL::BasicBind

  # Eli Green:
  #   The hope is that we don't ever need to just assume the default values. However,
  #   in some cases (notably floats and doubles), I have seen "show fields from table"
  #   return absolutely zero information about size and precision. Sigh.
  #   I probably should have made a struct to store this info in ... but I didn't.
  MYSQL_to_XOPEN = {
    "TINYINT"    => [SQL_TINYINT, 1, nil],
    "SMALLINT"   => [SQL_SMALLINT, 6, nil],
    "MEDIUMINT"  => [SQL_SMALLINT, 6, nil],
    "INT"        => [SQL_INTEGER, 11, nil],
    "INTEGER"    => [SQL_INTEGER, 11, nil],
    "BIGINT"     => [SQL_BIGINT, 25, nil],
    "INT24"      => [SQL_BIGINT, 25, nil],
    "REAL"       => [SQL_REAL, 12, nil],
    "FLOAT"      => [SQL_FLOAT, 12, nil],
    "DECIMAL"    => [SQL_DECIMAL, 12, nil],
    "NUMERIC"    => [SQL_NUMERIC, 12, nil],
    "DOUBLE"     => [SQL_DOUBLE, 22, nil],
    "CHAR"       => [SQL_CHAR, 1, nil],
    "VARCHAR"    => [SQL_VARCHAR, 255, nil],
    "DATE"       => [SQL_DATE, 10, nil],
    "TIME"       => [SQL_TIME, 8, nil],
    "TIMESTAMP"  => [SQL_TIMESTAMP, 19, nil],
    "DATETIME"   => [SQL_TIMESTAMP, 19, nil],
    "TINYBLOB"   => [SQL_BINARY, 255, nil],
    "BLOB"       => [SQL_VARBINARY, 16277215, nil],
    "MEDIUMBLOB" => [SQL_VARBINARY, 2147483657, nil],
    "LONGBLOB"   => [SQL_LONGVARBINARY, 2147483657, nil],
    "TINYTEXT"   => [SQL_VARCHAR, 255, nil],
    "TEXT"       => [SQL_LONGVARCHAR, 65535, nil],
    "MEDIUMTEXT" => [SQL_LONGVARCHAR, 16277215, nil],
    "ENUM"       => [SQL_CHAR, 255, nil],
    "SET"        => [SQL_CHAR, 255, nil],
    nil          => [SQL_OTHER, nil, nil]
  }

  def disconnect
    @handle.close
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def ping
    begin
      @handle.ping
      return true
    rescue MyError
      return false
    end
  end

  def tables
    @handle.list_tables
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  # Eli Green (fixed up by Michael Neumann)
  def columns(table)
    dbh = DBI::DatabaseHandle.new(self)
    uniques = []
    dbh.execute("SHOW INDEX FROM #{table}") do |sth|
      sth.each do |row|
        uniques << row[4] if row[1] == "0"
      end
    end  

    ret = nil
    dbh.execute("SHOW FIELDS FROM #{table}") do |sth|
      ret = sth.collect do |row|
        name, type, nullable, key, default, extra = row
        #type = row[1]
        #size = type[type.index('(')+1..type.index(')')-1]
        #size = 0
        #type = type[0..type.index('(')-1]

        sqltype, type, size, decimal = mysql_type_info(row[1])
        col = Hash.new
        col['name']           = name
        col['sql_type']       = sqltype
        col['type_name']      = type
        col['nullable']       = nullable == "YES"
        col['indexed']        = key != ""
        col['primary']        = key == "PRI"
        col['unique']         = uniques.index(name) != nil
        col['precision']      = size
        col['scale']          = decimal
        col['default']        = row[4]
        col
      end # collect
    end # execute
   
    ret
  end


  def do(stmt, *bindvars)
    @handle.query_with_result = false
    sql = bind(self, stmt, bindvars)
    @handle.query(sql)
    @handle.affected_rows
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end
 

  def prepare(statement)
    Statement.new(@handle, statement)
  end

  # TODO: Raise Error
  def commit
  end

  # TODO: Raise Error
  def rollback
  end

  private # -------------------------------------------------

  # Eli Green
  def mysql_type_info(typedef)
    sql_type, type, size, decimal = nil, nil, nil, nil

    pos = typedef.index('(')
    if not pos.nil?
      type = typedef[0..pos-1]
      size = typedef[pos+1..-2]
      pos = size.index(',')
      if not pos.nil?
        size, decimal = size.split(',', 2)
        decimal = decimal.to_i
      end
      size = size.to_i
    else
      type = typedef
    end

    type_info = MYSQL_to_XOPEN[type.upcase] || MYSQL_to_XOPEN[nil]
    sqltype = type_info[0]
    if size.nil? then size = type_info[1] end
    if decimal.nil? then decimal = type_info[2] end
    return sqltype, type, size, decimal
  end

  
  # Driver-specific functions ------------------------------------------------

  public

  def __createdb(db)
    @handle.create_db(db)
  end

  def __dropdb(db)
    @handle.drop_db(db)
  end

  def __shutdown
    @handle.shutdown
  end

  def __reload
    @handle.reload
  end

end # class Database


class Statement < DBI::BaseStatement
  include SQL::BasicBind
  include SQL::BasicQuote

  def initialize(handle, statement)
    super(nil)
    #@attr['mysql_use_result'] = false
    #@attr['mysql_store_result'] = true

    @handle = handle
    @statement = statement
    @params = []
  end

  def bind_param(param, value, attribs)
    raise InterfaceError, "only ? parameters supported" unless param.is_a? Fixnum
    @params[param-1] = value 
  end

  def execute
    @handle.query_with_result = true # automatically switches store_result on 
    #if @attr['mysql_use_result']
    #  @handle.use_result
    #else
    #  @handle.store_result
    #end

    sql = bind(self, @statement, @params)
    @res_handle = @handle.query(sql)
    @current_row = 0
    @rows = @handle.affected_rows
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def finish
    @res_handle.free
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def fetch
    @current_row += 1
    @res_handle.fetch_row
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def fetch_scroll(direction, offset)
    #if @attr['mysql_use_result'] then
    #  super
    #else
      case direction
      when SQL_FETCH_NEXT
        @current_row += 1
        @res_handle.fetch_row
      when SQL_FETCH_PRIOR
        @res_handle.data_seek(@current_row - 1)
        @res_handle.fetch_row
      when SQL_FETCH_FIRST
        @current_row = 1
        @res_handle.data_seek(@current_row - 1)
        @res_handle.fetch_row
      when SQL_FETCH_LAST
        @current_row = @res_handle.num_rows
        @res_handle.data_seek(@current_row - 1)
        @res_handle.fetch_row
      when SQL_FETCH_ABSOLUTE
        @current_row = offset + 1
        @res_handle.data_seek(@current_row - 1)
        @res_handle.fetch_row
      when SQL_FETCH_RELATIVE
        @current_row += offset + 1
        @res_handle.data_seek(@current_row - 1)
        @res_handle.fetch_row
      else
        raise NotSupportedError
      end
    #end
  end

  def column_info
    retval = []

    return [] if @res_handle.nil?

    @res_handle.fetch_fields.each {|col| 
      retval << {'name' => col.name, 'precision' => col.length - col.decimals, 'scale' => col.decimals,
      '_type' => col.type, '_length' => col.length, '_max_length' => col.max_length, '_flags' => col.flags }
    }
    retval
  rescue MyError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def rows
    @rows
  end

=begin
  def []=(attr, value)
    case attr
    when 'mysql_use_result'
      @attr['mysql_store_result'] = ! value
      @attr['mysql_use_result']   = value
    when 'mysql_store_result'
      @attr['mysql_use_result']   = ! value
      @attr['mysql_store_result'] = value
    else
      raise NotSupportedError
    end
  end
=end

end # class Statement


end # module Mysql
end # module DBD
end # module DBI

