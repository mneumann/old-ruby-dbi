# 
# DBD::SQLRelay
# $Id: SQLRelay.rb,v 1.2 2001/11/12 20:25:40 michael Exp $
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

require "sqlrelay"

module DBI
module DBD
module SQLRelay

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end

  def connect(dbname, user, auth, attr)
    # connect to database
    
    # * dbi:SQLRelay:host:port
    # * dbi:SQLRelay:host=xxx;port=xxx;socket=xxx;retrytime=xxx;tries=xxx
    hash = Utils.parse_params(dbname)

    if hash.has_key? "database" then
      # first form
      hash["host"], hash["port"] = hash["database"], hash["host"]
    end

    # default values
    hash['host']      ||= "localhost"
    hash['port']      ||= 9000
    hash['socket']    ||= ''
    hash['retrytime'] ||= 0
    hash['tries']     ||= 1
    
    # TODO: what happens on connection failure? return nil?
    handle = ::SQLRelay.new(hash['host'], hash['port'], hash['socket'], 
      user, auth, hash['retrytime'], hash['tries'])

    return Database.new(handle, attr)
  end

end # class Driver

class Database < DBI::BaseDatabase

  def disconnect
    @handle.endSession
    # TODO: can endSession fail? What happens if it fails, which return value?
  end

  def ping
    @handle.ping == 1 ? true : false
  end

  def prepare(statement)
    Statement.new(@handle, statement)
  end

  def commit
    $STDERR.puts "Warning: Commit ineffective while AutoCommit is on" if @attr['AutoCommit']

    case @handle.commit
    when 0
      # failed
      raise DBI::OperationalError.new("Commit failed")
    when -1
      raise DBI::OperationalError.new("Error occured during commit")
   end
  end

  def rollback
    $STDERR.puts "Warning: Rollback ineffective while AutoCommit is on" if @attr['AutoCommit']

    case @handle.rollback
    when 0
      # failed
      raise DBI::OperationalError.new("Rollback failed")
    when -1
      raise DBI::OperationalError.new("Error occured during rollback")
    end
  end

  def []=(attr, value)
    case attr
    when 'AutoCommit'
    when 'sqlrelay_debug' 
      if value == true
        @handle.debugOn
      else
        @handle.debugOff
      end
    else
      if attr =~ /^sqlrelay_/ or attr != /_/
        raise DBI::NotSupportedError, "Option '#{attr}' not supported"
      else # option for some other driver - quitly ignore
        return  
      end     
    end
    @attr[attr] = value
  end

end # class Database


class Statement < DBI::BaseStatement
  def initialize(handle, stmt)
    super(nil)  # attribs

    @db = handle 
    @handle = SQLRCursor.new(@db)
    @handle.prepareQuery(stmt)
  end

  def bind_param(param, value, attribs)
    raise InterfaceError, "only :name parameters supported" unless param.is_a? String and param.is_a? Symbol
    if value.kind_of? Float then
      precision = attribs['precision']
      scale     = attribs['scale'] 
      if precision.nil? or scale.nil?
        pr, sc = value.to_s.split(".")
        precision ||= pr || 8 
        scale     ||= sc || 2
      end
      @handle.inputBind(param.to_s, value, precision, scale)
    else
      @handle.inputBind(param.to_s, value)
    end
    # TODO: correct default precision/scale
  end

  def execute
    if @handle.executeQuery == 0 then 
      raise DBI::ProgrammingError.new(@handle.errorMessage)
    end

    if @db['AutoCommit'] 
      case @db.commit
      when 0
        # failed
        raise DBI::OperationalError.new("Commit failed")
      when -1
        raise DBI::OperationalError.new("Error occured during commit")
     end
    end

    @handle.clearBinds
    @row_index = 0
    @row_count = @handle.rowCount
  end

  def finish
    @handle = nil
  end

  def fetch
    if @row_index >= @row_count 
      nil
    else
      row = @handle.getRow(@row_index)
      @row_index += 1
      row
    end
  end

  def fetch_scroll(direction, offset=1)
    fetch_row = case direction
    when DBI::SQL_FETCH_NEXT     then @row_index
    when DBI::SQL_FETCH_PRIOR    then @row_index-1  # TODO: -2 ????
    when DBI::SQL_FETCH_FIRST    then 0
    when DBI::SQL_FETCH_LAST     then @row_count-1
    when DBI::SQL_FETCH_ABSOLUTE then offset
    when DBI::SQL_FETCH_RELATIVE then @row_index+offset-1
    end
    
    if fetch_row > -1 and fetch_row < @row_count
      row = @handle.getRow(fetch_row)
    end

    @row_index = fetch_row + 1

    if @row_index < 0 then
      @row_index = 0
    elsif @row_index > @row_count
      @row_index = @row_count
    end

    return row
  end

  def column_info
    (0...@handle.colCount).collect do |nr|
      {
        'name'      => @handle.getColumnName(nr),
        'type_name' => @handle.getColumnType(nr),
        'precision' => @handle.getColumnLength(nr)
      }
    end
  end

  def rows
    @handle.affectedRows
  end

end # class Statement

end # module SQLRelay
end # module DBD
end # module DBI
