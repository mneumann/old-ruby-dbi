# 
# DBD::Proxy
# $Id: Proxy.rb,v 1.2 2001/06/07 10:42:15 michael Exp $
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


require "drb"

module DBI
module DBD
module Proxy

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

module HelperMixin
  def check_exception(obj)
    if obj.kind_of? Exception
      raise obj
    else
      obj
    end
  end

  def define_methods(meths)
    meths.each {|d|
      eval %{
	def #{d}(*a) 
	  check_exception(@handle.#{d}(*a))
	end
      }
    } 
  end
end # module HelperMixin


class Driver < DBI::BaseDriver
  include HelperMixin 

  DEFAULT_PORT = 9001
  DEFAULT_HOSTNAME = "localhost"

  def initialize
    super(USED_DBD_VERSION)
    DRb.start_service
  end

  def connect(dsn, user, auth, attr)
    hash = Utils.parse_params(dsn)

    host = hash['hostname'] || DEFAULT_HOSTNAME
    port = (hash['port'] || DEFAULT_PORT).to_i 
    dsn  = hash['dsn']

    if dsn.nil?
      raise InterfaceError, "must specify a DSN"
    end

    handle = DRbObject.new(nil, "druby://#{host}:#{port}")

    if handle.get_used_DBD_version != USED_DBD_VERSION
      raise InterfaceError, "Proxy uses different DBD version"
    end

    db_handle = handle.DBD_connect(dsn, user, auth, attr)
    check_exception(db_handle)   

    Database.new(db_handle)
  end

end

class Database < DBI::BaseDatabase
  include HelperMixin 
  METHODS = %w(disconnect ping commit rollback tables execute
               do quote [] []=)

  def initialize(db_handle)
    @handle = db_handle
    define_methods METHODS
  end

  def prepare(statement)
    sth = @handle.prepare(statement)
    check_exception(sth)
    Statement.new(sth)
  end

end # class Database


class Statement < DBI::BaseStatement
  include HelperMixin

  METHODS = %w(bind_param execute finish fetch column_info bind_params
               cancel fetch_scroll fetch_many fetch_all)

  def initialize(handle)
    @handle = handle
    define_methods METHODS
  end

end # class Statement


end # module Proxy
end # module DBD
end # module DBI

