# 
# DBD::ODBC
# $Id: ODBC.rb,v 1.1 2001/06/07 19:06:24 michael Exp $
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



$:.delete(".")
require "odbc"
$: << "."

module ODBC
class Column
  attr_reader :name, :table, :type, :length, :nullable, :scale
  attr_reader :precision, :searchable, :unsigned
end
class DSN
  attr_accessor :name, :descr
end
class Driver
  attr_accessor :name, :attrs
end
end


module DBI
module DBD
module ODBC

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

ODBCErr = ::ODBC::Error

module Converter
  def convert(val)
    if val.is_a? DBI::Date
      ::ODBC::Date.new(val.year, val.month, val.day)
    elsif val.is_a? DBI::Time
      ::ODBC::Time.new(val.hour, val.minute, val.second)
    elsif val.is_a? DBI::Timestamp
      ::ODBC::TimeStamp.new(val.year, val.month, val.day,
          val.hour, val.minute, val.second, val.fraction)
    elsif val.is_a? DBI::Binary
      val.to_s
    else
      val
    end
  end
end

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end


  def data_sources
    ::ODBC.datasources.collect {|dsn| dsn.name }
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def connect(dbname, user, auth, attr)
    handle = ::ODBC.connect(dbname, user, auth)
    return Database.new(handle, attr)
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

end

class Database < DBI::BaseDatabase
  include Converter

  def disconnect
    @handle.rollback
    @handle.disconnect 
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def tables
    stmt = @handle.tables
    tabs = [] 
    stmt.each_hash {|row|
      tabs << row["TABLE_NAME"]
    }
    stmt.drop
    tabs
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def prepare(statement)
    stmt = @handle.prepare(statement)
    Statement.new(stmt)
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def do(statement, *bindvars)
    bindvars = bindvars.collect{|v| convert(v)}
    @handle.do(statement, *bindvars) 
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def execute(statement, *bindvars)
    bindvars = bindvars.collect{|v| convert(v)}
    stmt = @handle.run(statement, *bindvars) 
    Statement.new(stmt)
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def []=(attr, value)
    case attr
    when 'AutoCommit'
      @handle.autocommit(value)
    else
      raise NotSupportedError
    end
    @attr[attr] = value
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def commit
    @handle.commit
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def rollback
    @handle.rollback
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

end # class Database


class Statement < DBI::BaseStatement
  include Converter

  def initialize(handle)
    @handle = handle
    @params = []
    @arr = []
  end

  def bind_param(param, value, attribs)
    raise InterfaceError, "only ? parameters supported" unless param.is_a? Fixnum
    @params[param-1] = value
  end

  def execute
    bindvars = @params.collect{|v| convert(v)}
    @handle.execute(*bindvars)
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def finish
    @handle.drop
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def cancel
    @handle.cancel
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end


  def fetch
    convert_row(@handle.fetch)
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def fetch_scroll(direction, offset)
    direction = case direction
    when DBI::SQL_FETCH_FIRST    then ::ODBC::SQL_FETCH_FIRST
    when DBI::SQL_FETCH_LAST     then ::ODBC::SQL_FETCH_LAST
    when DBI::SQL_FETCH_NEXT     then ::ODBC::SQL_FETCH_NEXT
    when DBI::SQL_FETCH_PRIOR    then ::ODBC::SQL_FETCH_PRIOR
    when DBI::SQL_FETCH_ABSOLUTE then ::ODBC::SQL_FETCH_ABSOLUTE
    when DBI::SQL_FETCH_RELATIVE then ::ODBC::SQL_FETCH_RELATIVE
    end
    
    convert_row(@handle.fetch_scroll(direction, offset))
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end


  def column_info
    (0...(@handle.ncols)).collect do |i| 
      col = @handle.column(i)
      {'name' => col.name, 'nullable' =>  col.nullable}
    end
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  def rows
    @handle.nrows
  rescue ODBCErr => err
    raise DBI::DatabaseError.new(err.message)
  end

  private # -----------------------------------

  # convert the ODBC datatypes to DBI datatypes
  def convert_row(row)
    return nil if row.nil?
    row.collect do |col|
      if col.is_a? ::ODBC::Date
        DBI::Date.new(col.year, col.month, col.day)
      elsif col.is_a? ::ODBC::Time
        DBI::Time.new(col.hour, col.minute, col.second)
      elsif col.is_a? ::ODBC::TimeStamp
        DBI::Timestamp.new(col.year, col.month, col.day,
          col.hour, col.minute, col.second, col.fraction)
      else
        col
      end
    end
  end 
end


end # module ODBC
end # module DBD
end # module DBI




