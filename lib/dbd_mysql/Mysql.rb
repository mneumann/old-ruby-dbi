# 
# DBD::Mysql
# $Id: Mysql.rb,v 1.3 2001/06/05 12:06:21 michael Exp $
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

require "mysql"

module DBI
module DBD
module Mysql

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

MyError = ::MysqlError

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end

  def connect(dbname, user, auth, attr)
    # connect to database
    hash = Utils.parse_params(dbname)

    if hash['database'].nil? 
      raise InterfaceError, "must specify database"
    end

    hash['host'] ||= 'localhost'

    handle = ::Mysql.connect(hash['host'], user, auth)
    handle.select_db(hash['database'])
    return Database.new(handle, attr)
  rescue MyError => err
    raise DBI::Error.new(err.message)
  end

  def data_sources
    handle = ::Mysql.new
    res = handle.list_dbs.collect {|db| "dbi:Mysql:database=#{db}" }
    handle.close
    return res
  rescue MyError => err
    raise DBI::Error.new(err.message)
  end

end # class Driver

class Database < DBI::BaseDatabase
 
  def disconnect
    @handle.close
  rescue MyError => err
    raise DBI::Error.new(err.message)
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
    raise DBI::Error.new(err.message)
  end

  # TODO: 
  # def do
  
  def prepare(statement)
    Statement.new(@handle, statement)
  end

  # TODO: Raise Error
  def commit
  end

  # TODO: Raise Error
  def rollback
  end

end # class Database


class Statement < DBI::BaseStatement
  include SQL::BasicBind
  include SQL::BasicQuote

  def initialize(handle, statement)
    @handle = handle
    @statement = statement
    @params = []
  end

  def bind_param(param, value, attribs)
    raise InterfaceError, "only ? parameters supported" unless param.is_a? Fixnum
    @params[param-1] = value 
  end

  def execute
    @handle.query_with_result = true
    sql = bind(self, @statement, @params)
    @res_handle = @handle.query(sql)
    @rows = @handle.affected_rows
  rescue MyError => err
    raise DBI::Error.new(err.message)
  end

  def finish
    @res_handle.free
   rescue MyError => err
    raise DBI::Error.new(err.message)
  end

  def fetch
    @res_handle.fetch_row
   rescue MyError => err
    raise DBI::Error.new(err.message)
  end

  def column_info
    retval = []

    return [] if @res_handle.nil?

    @res_handle.fetch_fields.each {|col| 
      retval << {'name' => col.name }
    }
    retval
   rescue MyError => err
    raise DBI::Error.new(err.message)
  end

  def rows
    @rows
  end

end # class Statement


end # module Mysql
end # module DBD
end # module DBI




