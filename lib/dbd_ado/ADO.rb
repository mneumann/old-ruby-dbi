# 
# DBD::ADO
# $Id: ADO.rb,v 1.5 2001/06/07 10:42:11 michael Exp $
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



require "win32ole"

module DBI
module DBD
module ADO

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end

  def connect(dbname, user, auth, attr)
    # connect to database

    handle = WIN32OLE.new('ADODB.Connection')
    handle.Open(dbname)
    handle.BeginTrans()  # start new Transaction

    return Database.new(handle, attr)
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

end

class Database < DBI::BaseDatabase
 
  def disconnect
    @handle.RollbackTrans()
    @handle.Close()
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def prepare(statement)
    # TODO: create Command instead?
    Statement.new(@handle, statement, self)
  end

  def commit
    # TODO: raise error if AutoCommit on => better in DBI?
    @handle.CommitTrans()
    @handle.BeginTrans()
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def rollback
    # TODO: raise error if AutoCommit on => better in DBI?
    @handle.RollbackTrans()
    @handle.BeginTrans()
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def []=(attr, value)
    if attr == 'AutoCommit' then
      # TODO: commit current transaction?
      @attr[attr] = value
    else
      super
    end
  end


end # class Database


class Statement < DBI::BaseStatement
  include SQL::BasicBind
  include SQL::BasicQuote

  def initialize(handle, statement, db)
    @handle = handle
    @statement = statement
    @params = []
    @db = db
  end

  def bind_param(param, value, attribs)
    raise InterfaceError, "only ? parameters supported" unless param.is_a? Fixnum

    @params[param-1] = value 
  end

  def execute
    # TODO: use Command and Parameter
    # TODO: substitute all ? by the parametes
    sql = bind(self, @statement, @params)
    @res_handle = @handle.Execute(sql) 

    # TODO: SELECT and AutoCommit finishes the result-set
    #       what to do?
    if @db['AutoCommit'] == true and not SQL.query?(@statement) then
      @db.commit
    end

  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def finish
    # if DCL, DDL or INSERT UPDATE and DELETE, this gives an Error
    # because no Result-Set is available
    if @res_handle.Fields.Count() != 0 then
      @res_handle.Close()
    end
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def fetch        
    retval = fetch_currentrow
    @res_handle.MoveNext() unless retval.nil?
    retval
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end



  def fetch_scroll(direction, offset)
    case direction
    when DBI::SQL_FETCH_NEXT
      return fetch
    when DBI::SQL_FETCH_PRIOR
      # TODO: check if already the first?
      #return nil if @res_handle.AbsolutePosition()
      @res_handle.MovePrevious()
      return fetch_currentrow
    when DBI::SQL_FETCH_FIRST
      @res_handle.MoveFirst()
      return fetch_currentrow
    when DBI::SQL_FETCH_LAST
      @res_handle.MoveLast()
      return fetch_currentrow
    when DBI::SQL_FETCH_RELATIVE
      @res_handle.Move(offset)
      return fetch_currentrow
    when DBI::SQL_FETCH_ABSOLUTE
      ap = @res_handle.AbsolutePositon()      
      @res_handle.Move(offset-ap)
      return fetch_currentrow      
    else
      raise DBI::InterfaceError
    end    
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def column_info
    num_cols = @res_handle.Fields().Count()
    retval = Array.new(num_cols)

    for i in 0...num_cols do
      retval[i] = {'name' => @res_handle.Fields(i).Name()}
    end

    retval
  rescue RuntimeError => err
    raise DBI::DatabaseError.new(err.message)
  end

  def rows
    # TODO: how to get the RPC in ADO? 
    nil
  end

  
  private

  def fetch_currentrow    
    return nil if @res_handle.EOF() or @res_handle.BOF()
      
    # TODO: don't create new Array each time
    num_cols = @res_handle.Fields().Count()
    retval = Array.new(num_cols)

    for i in 0...num_cols do
      retval[i] = @res_handle.Fields(i).Value()
    end
  
    retval
  end
  

end


end # module ADO
end # module DBD
end # module DBI

