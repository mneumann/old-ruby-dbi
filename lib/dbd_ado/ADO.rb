# 
# DBD::ADO
# $Id: ADO.rb,v 1.1 2001/05/30 18:43:05 michael Exp $
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
  end

end

class Database < DBI::BaseDatabase
 
  def disconnect
    rollback
    @handle.Close()
  end

  def prepare(statement)
    # TODO: create Command instead?
    Statement.new(@handle, statement)
  end

  def commit
    @handle.CommitTrans()
  end

  def rollback
    @handle.RollbackTrans()
  end

end # class Database


class Statement < DBI::BaseStatement

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
    # TODO: use Command and Parameter
    # TODO: substitute all ? by the parametes
    @res_handle = @handle.Execute(@statement) 
  end

  def finish
    @res_handle.Close()
  end

  def fetch
    # TODO: don't create new Array each time
    num_cols = @res_handle.Fields().Count()
    retval = Array.new(num_cols)

    for i in 0...num_cols do
      retval[i] = @res_handle.Fields(i).Value()
    end
    retval
  end

  def column_info
    num_cols = @res_handle.Fields().Count()
    retval = Array.new(num_cols)

    for i in 0...num_cols do
      retval[i] = {'name' => @res_handle.Fields(i).Name()}
    end

    retval
  end

  def rows
    # TODO: how to get the RPC in ADO? 
    nil
  end

end


end # module ADO
end # module DBD
end # module DBI




