# Ruby/DBI 
# $Id: dbi.rb,v 1.17 2001/08/23 20:59:41 michael Exp $
# 
# Version : 0.0.9
# Author  : Michael Neumann (neumann@s-direktnet.de)
#
# adapted from Rainer Perl's Ruby/DBI version 0.0.4
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


require "dbi/row"
require "dbi/utils"
require "dbi/sql"
require "date"

module DBI

module DBD
  DIR = "DBD"
  API_VERSION = "0.2"
end


#----------------------------------------------------
#  Constants
#----------------------------------------------------

VERSION = "0.0.9"

##
# Constants for fetch_scroll
#
SQL_FETCH_NEXT, SQL_FETCH_PRIOR, SQL_FETCH_FIRST, SQL_FETCH_LAST, 
SQL_FETCH_ABSOLUTE, SQL_FETCH_RELATIVE = (1..6).to_a


##
# SQL type constants
# 
SQL_BIT = -7
SQL_TINYINT = -6
SQL_SMALLINT = 5
SQL_INTEGER = 4
SQL_BIGINT = -5

SQL_FLOAT = 6
SQL_REAL = 7
SQL_DOUBLE = 8

SQL_NUMERIC = 2
SQL_DECIMAL = 3

SQL_CHAR = 1
SQL_VARCHAR = 12
SQL_LONGVARCHAR = -1

SQL_DATE = 91
SQL_TIME = 92
SQL_TIMESTAMP = 93

SQL_BINARY = -2
SQL_VARBINARY = -3
SQL_LONGVARBINARY = -4

# TODO
# Find types for these (XOPEN?)
#SQL_ARRAY = 
#SQL_BLOB = 
#SQL_CLOB = 
#SQL_DISTINCT = 
#SQL_OBJECT = 
#SQL_NULL = 
SQL_OTHER = 100
#SQL_REF = 
#SQL_STRUCT = 

class ColumnInfo

  # define attribute accessors for the following attributes:
  attrs = %w(name type type_name size decimal_digits default nullable indexed primary unique)
  attrs.each do | attr |
    eval %{
      def #{ attr }()         @hash['#{ attr }']         end
      def #{ attr }=( value ) @hash['#{ attr }'] = value end
    }
  end

  alias nullable? nullable
  alias is_nullable? nullable

  alias indexed? indexed
  alias is_indexed? indexed

  alias primary? primary
  alias is_primary? primary

  alias unique? unique
  alias is_unique unique

  # Constructor methods ------------------------------------------------------------------------

  def initialize( hash=nil )
    @hash = hash || Hash.new
  end

  # Attribute getter/setter --------------------------------------------------------------------
  
  def []( attr ) 
    @hash[attr]
  end

  def []=( attr, value ) 
    @hash[attr] = value
  end

end





##
# Constants for bind_param (not yet in use)
#
#SQL_BIGINT, SQL_BLOB, SQL_BLOB_LOCATOR, SQL_CHAR, SQL_BINARY,
#SQL_CLOB, SQL_CLOB_LOCATOR, SQL_TYPE_DATE, SQL_DBCLOB, SQL_DBCLOB_LOCATOR,
#SQL_DECIMAL, SQL_DOUBLE, SQL_FLOAT, SQL_GRAPHIC, SQL_INTEGER,
#SQL_LONGVARCHAR, SQL_LONGVARBINARY, SQL_LONGVARGRAPHIC, SQL_NUMERIC, SQL_REAL,
#SQL_SMALLINT, SQL_TYPE_TIME, SQL_TYPE_TIMESTAMP, SQL_VARCHAR, SQL_VARBINARY,
#SQL_VARGRAPHIC = (7..33).to_a


#----------------------------------------------------
#  Exceptions
#----------------------------------------------------


#
# Exception classes "borrowed" from Python API 2.0
#

##
# for important warnings like data truncation etc.
class Warning < RuntimeError
end

##
# base class of all other error exceptions
# use this to catch all errors
class Error < RuntimeError
end


##
# exception for errors related to the DBI interface
# rather than the database itself
class InterfaceError < Error
end

##
# exception raised if the DBD driver has not specified
# a mandantory method [not in Python API 2.0]
class NotImplementedError < InterfaceError
end


##
# exception for errors related to the database 
class DatabaseError < Error
  attr_reader :err, :errstr, :state

  def initialize(errstr, err=nil, state=nil)
    super(errstr)
    @err, @errstr, @state = err, errstr, state
  end
end

##
# exception for errors due to problems with the processed 
# data like division by zero, numeric value out of range etc.
class DataError < DatabaseError
end

##
# exception for errors related to the database's operation which
# are not necessarily under the control of the programmer like
# unexpected disconnect, datasource name not found, transaction
# could not be processed, a memory allocation error occured during
# processing etc.
class OperationalError < DatabaseError
end

##
# exception raised when the relational integrity of the database
# is affected, e.g. a foreign key check fails
class IntegrityError < DatabaseError
end

##
# exception raised when the database encounters an internal error, 
# e.g. the cursor is not valid anymore, the transaction is out of
# sync
class InternalError < DatabaseError
end

##
# exception raised for programming errors, e.g. table not found
# or already exists, syntax error in SQL statement, wrong number
# of parameters specified, etc.
class ProgrammingError < DatabaseError
end

##
# raised if e.g. commit() is called for a database which do not
# support transactions
class NotSupportedError < DatabaseError
end


#----------------------------------------------------
#  Datatypes
#----------------------------------------------------


# TODO: do we need Binary?
# perhaps easier to call #bind_param(1, binary_string, 'type' => SQL_BLOB)
class Binary
  attr_accessor :data
  def initialize(data)
    @data = data
  end

  def to_s
    @data
  end
end

class Date
  attr_accessor :year, :month, :day
  def initialize(year=0, month=0, day=0)
    if year.is_a? ::Date
      @year, @month, @day = year.year, year.month, year.day 
    elsif year.is_a? ::Time
      @year, @month, @day = year.year, year.month, year.day 
    else
      @year, @month, @day = year, month, day
    end
  end

  def mon() @month end
  def mon=(val) @month=val end

  def to_s
    "#{@year}-#{@month}-#{@day}"
  end
end


class Time
  attr_accessor :hour, :minute, :second
  def initialize(hour=0, minute=0, second=0)
    if hour.is_a? ::Time
      @hour, @minute, @second = hour.hour, hour.min, hour.sec
    else
      @hour, @minute, @second = hour, minute, second
    end
  end

  def min() @minute end
  def min=(val) @minute=val end
  def sec() @second end
  def sec=(val) @second=val end


  def to_s
    "#{@hour}:#{@minute}:#{@second}"
  end
end


class Timestamp
  attr_accessor :year, :month, :day
  attr_accessor :hour, :minute, :second, :fraction
  def initialize(year=0, month=0, day=0, hour=0, minute=0, second=0, fraction=0)
    if year.is_a? ::Time
      @year, @month, @day = year.year, year.month, year.day 
      @hour, @minute, @second, @fraction = year.hour, year.min, year.sec, 0
    elsif year.is_a? ::Date
      @year, @month, @day = year.year, year.month, year.day 
      @hour, @minute, @second, @fraction = 0, 0, 0, 0
    else
      @year, @month, @day = year, month, day
      @hour, @minute, @second, @fraction = hour, minute, second, fraction
    end
  end

  def mon() @month end
  def mon=(val) @month=val end
  def min() @minute end
  def min=(val) @minute=val end
  def sec() @second end
  def sec=(val) @second=val end

  def to_s
    "#{@year}-#{@month}-#{@day} #{@hour}:#{@minute}:#{@second}.#{@fraction}"
  end

  # TODO: conversion functions to_date and to_time, perhaps to_date2
  # (date2/3.rb)
end


#----------------------------------------------------
#  Module functions (of DBI)
#----------------------------------------------------

  @@driver_map = Hash.new 

  DEFAULT_TRACE_MODE = 2
  DEFAULT_TRACE_OUTPUT = STDERR

  @@trace_mode   = DEFAULT_TRACE_MODE
  @@trace_output = DEFAULT_TRACE_OUTPUT







  ##
  # establish a database connection
  # 
  def DBI.connect(driver_url, user=nil, auth=nil, params=nil, &p)
    db_driver, db_args = parse_url(driver_url)
    db_driver = load_driver(db_driver)
    dh = @@driver_map[db_driver][0]

    dh.connect(db_args, user, auth, params, &p)
  end

  class << self
  ##
  # load a DBD and get the Driver object
  # 
  def get_driver(driver_url)
    db_driver, db_args = parse_url(driver_url)
    db_driver = load_driver(db_driver)
    dr = @@driver_map[db_driver]

    [dr, db_args]
  end

  def trace(mode=nil, output=nil)
    @@trace_mode   = mode   || @@trace_mode   || DBI::DEFAULT_TRACE_MODE
    @@trace_output = output || @@trace_output || DBI::DEFAULT_TRACE_OUTPUT
  end




  private

  ##
  # extended by John Gorman <jgorman@webbysoft.com> for
  # case insensitive DBD names
  # 
  def load_driver(driver_name)
    if @@driver_map[driver_name].nil?

      dc = driver_name.downcase

      # caseless look for drivers already loaded
      found = @@driver_map.keys.find {|key| key.downcase == dc}
      return found if found

      # try a quick load and then a caseless scan
      begin
        require "#{DBD::DIR}/#{driver_name}/#{driver_name}"
      rescue LoadError
        $:.each do |dir|
          path = "#{dir}/#{DBD::DIR}"
          next unless FileTest.directory?(path)
          found = Dir.entries(path).find {|e| e.downcase == dc}
          next unless found

          require "#{DBD::DIR}/#{found}/#{found}"
          break
        end
      end

      found ||= driver_name
 
      dr = DBI::DBD.const_get(found.intern)
      dbd_dr = dr::Driver.new
      drh = DBI::DriverHandle.new(dbd_dr)
      drh.trace(@@trace_mode, @@trace_output)
      @@driver_map[found] = [drh, dbd_dr]
      return found
    else
      return driver_name
    end
  rescue LoadError, NameError
    raise InterfaceError, "Could not load driver (#{$!.message})"
  end

  def parse_url(driver_url)
    if driver_url =~ /^(DBI|dbi):([^:]+)(:(.*))?$/ 
      [$2, $4]
    else
      raise InterfaceError, "Invalid Data Source Name"
    end
  end

  end # self

  def DBI.available_drivers
    found_drivers = []
    $:.each do |path|
      Dir["#{path}/#{DBD::DIR}/*"].each do |dr| 
        if FileTest.directory? dr then
          dir = File.basename(dr)
          Dir["#{path}/#{DBD::DIR}/#{dir}/*"].each do |fl|
            next unless FileTest.file? fl 
            found_drivers << dir if File.basename(fl) =~ /^#{dir}\./
          end
        end
      end
    end
    found_drivers.uniq.collect {|dr| "dbi:#{dr}:" }
  end

  def DBI.data_sources(driver)
    db_driver, = parse_url(driver)
    db_driver = load_driver(db_driver)
    dh = @@driver_map[db_driver][0]
    dh.data_sources
  end

  def DBI.disconnect_all( driver = nil )
    if driver.nil?
      @@driver_map.each {|k,v| v[0].disconnect_all}
    else
      db_driver, = parse_url(driver)
      @@driver_map[db_driver][0].disconnect_all
    end
  end



#----------------------------------------------------
#  Dispatch classes
#----------------------------------------------------


##
# Dispatch classes (Handle, DriverHandle, DatabaseHandle and StatementHandle)
#

class Handle
  attr_reader :trace_mode, :trace_output

  def initialize(handle)
    @handle = handle
  end

  def trace(mode=nil, output=nil)
    @trace_mode   = mode   || @trace_mode   || DBI::DEFAULT_TRACE_MODE
    @trace_output = output || @trace_output || DBI::DEFAULT_TRACE_OUTPUT
  end


  ##
  # call a driver specific function
  #
  def func(function, *values)
    if @handle.respond_to? function then
      @handle.send(function, *values)  
    else
      raise InterfaceError, "Driver specific function <#{function}> not available."
    end
  rescue ArgumentError
    raise InterfaceError, "Wrong # of arguments for driver specific function"
  end

  # error functions?
end

class DriverHandle < Handle

  def connect(db_args, user, auth, params)

    user = @handle.default_user[0] if user.nil?
    auth = @handle.default_user[1] if auth.nil?

    # TODO: what if only one of them is nil?
    #if user.nil? and auth.nil? then
    #  user, auth = @handle.default_user
    #end

    params ||= {}
    new_params = @handle.default_attributes
    params.each {|k,v| new_params[k] = v} 


    db = @handle.connect(db_args, user, auth, new_params)
    dbh = DatabaseHandle.new(db)
    dbh.trace(@trace_mode, @trace_output)

    if block_given?
      begin
        yield dbh
      ensure  
        dbh.disconnect if dbh.connected?
      end  
    else
      return dbh
    end
  end

  def data_sources
    @handle.data_sources
  end

  def disconnect_all
    @handle.disconnect_all
  end
end

class DatabaseHandle < Handle

  include DBI::Utils::ConvParam

  def connected?
    not @handle.nil?
  end

  def disconnect
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.disconnect
    @handle = nil
  end

  def prepare(stmt)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    sth = StatementHandle.new(@handle.prepare(stmt), false)
    sth.trace(@trace_mode, @trace_output)

    if block_given?
      begin
        yield sth
      ensure
        sth.finish unless sth.finished?
      end
    else
      return sth
    end 
  end

  def execute(stmt, *bindvars)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    sth = StatementHandle.new(@handle.execute(stmt, *conv_param(*bindvars)), true, false)
    sth.trace(@trace_mode, @trace_output)

    if block_given?
      begin
        yield sth
      ensure
        sth.finish unless sth.finished?
      end
    else
      return sth
    end 
  end

  def do(stmt, *bindvars)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.do(stmt, *conv_param(*bindvars))
  end

  def select_one(stmt, *bindvars)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    row = nil
    execute(stmt, *bindvars) do |sth|
      row = sth.fetch 
    end
    row
  end

  def select_all(stmt, *bindvars, &p)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    rows = nil
    execute(stmt, *bindvars) do |sth|
      if block_given?
        sth.each(&p)
      else
        rows = sth.fetch_all  
      end
    end
    return rows
  end

  def tables
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.tables
  end

  def columns( table )
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.columns( table ).collect {|col| ColumnInfo.new(col) }
  end

  def ping
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.ping
  end

  def quote(value)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.quote(value)
  end

  def commit
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.commit
  end

  def rollback
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle.rollback
  end

  def transaction
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    raise InterfaceError, "No block given" unless block_given?
    
    commit
    begin
      yield self
      commit
    rescue Exception
      rollback
      raise
    end
  end


  def [] (attr)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle[attr]
  end

  def []= (attr, val)
    raise InterfaceError, "Database connection was already closed!" if @handle.nil?
    @handle[attr] = val
  end

end

class StatementHandle < Handle

  include Enumerable
  include DBI::Utils::ConvParam

  def initialize(handle, fetchable=false, prepared=true)
    super(handle)
    @fetchable = fetchable
    @prepared  = prepared     # only false if immediate execute was used
    @cols = nil

    # TODO: problems with other DB's?
    #@row = DBI::Row.new(column_names,nil)
    if @fetchable
      @row = DBI::Row.new(column_names,nil)
    else
      @row = nil
    end
  end

  def finished?
    @handle.nil?
  end

  def fetchable?
    @fetchable
  end

  def bind_param(param, value, attribs=nil)
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement wasn't prepared before." unless @prepared
    @handle.bind_param(param, conv_param(value)[0], attribs)
  end

  def execute(*bindvars)
    cancel     # cancel before 
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement wasn't prepared before." unless @prepared
    @handle.bind_params(*conv_param(*bindvars))
    @handle.execute
    @fetchable = true

    # TODO:?
    #if @row.nil?
      @row = DBI::Row.new(column_names,nil)
    #end
  end

  def finish
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    @handle.finish
    @handle = nil
  end

  def cancel
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    @handle.cancel if @fetchable
    @fetchable = false
  end

  def column_names
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    return @cols unless @cols.nil?
    @cols = @handle.column_info.collect {|col| col['name'] }
  end

  def column_info
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    @handle.column_info.collect {|col| ColumnInfo.new(col) }
  end

  def rows
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    @handle.rows
  end


  def fetch(&p)
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement must first be executed" unless @fetchable

    if block_given? 
      while (res = @handle.fetch) != nil
        @row.set_values(res)
        yield @row
      end
      @handle.cancel
      @fetchable = false
      return nil
    else
      res = @handle.fetch
      if res.nil?
        @handle.cancel
        @fetchable = false
      else
        @row.set_values(res)
        res = @row
      end
      return res
    end
  end

  def each(&p)
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement must first be executed" unless @fetchable
    raise InterfaceError, "No block given" unless block_given?

    fetch(&p)
  end

  def fetch_array
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement must first be executed" unless @fetchable

    if block_given? 
      while (res = @handle.fetch) != nil
        yield res
      end
      @handle.cancel
      @fetchable = false
      return nil
    else
      res = @handle.fetch
      if res.nil?
        @handle.cancel
        @fetchable = false
      end
      return res
    end
  end

  def fetch_hash
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement must first be executed" unless @fetchable

    cols = column_names

    if block_given? 
      while (row = @handle.fetch) != nil
        hash = {}
        row.each_with_index {|v,i| hash[cols[i]] = v} 
        yield hash
      end
      @handle.cancel
      @fetchable = false
      return nil
    else
      row = @handle.fetch
      if row.nil?
        @handle.cancel
        @fetchable = false
        return nil
      else
        hash = {}
        row.each_with_index {|v,i| hash[cols[i]] = v} 
        return hash
      end
    end
  end

  def fetch_many(cnt)
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement must first be executed" unless @fetchable

    cols = column_names
    rows = @handle.fetch_many(cnt)
    if rows.nil?
      @handle.cancel
      @fetchable = false
      return nil
    else
      return rows.collect{|r| Row.new(cols, r)}
    end
  end

  def fetch_all
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement must first be executed" unless @fetchable

    cols = column_names
    rows = @handle.fetch_all
    if rows.nil?
      @handle.cancel
      @fetchable = false
      return nil
    else
      return rows.collect{|r| Row.new(cols, r)}
    end
  end

  def fetch_scroll(direction, offset=1)
    raise InterfaceError, "Statement was already closed!" if @handle.nil?
    raise InterfaceError, "Statement must first be executed" unless @fetchable

    row = @handle.fetch_scroll(direction, offset)
    if row.nil?
      #@handle.cancel
      #@fetchable = false
      return nil
    else
      @row.set_values(row)
      return @row
    end
  end


end # class StatementHandle





#----------------------------------------------------
#  Fallback classes
#----------------------------------------------------


##
# Fallback classes for default behavior of DBD driver
# must be inherited by the DBD driver classes
#

class Base
end


class BaseDriver < Base

  def initialize(dbd_version)
    unless DBD::API_VERSION == dbd_version
      raise InterfaceError, "Wrong DBD API version used"
    end
  end
 
  def connect(dbname, user, auth, attr)
    raise NotImplementedError
  end

  def default_user
    ['', '']
  end

  def default_attributes
    {}
  end

  def data_sources
    []
  end

  def disconnect_all
    raise NotImplementedError
  end

end # class BaseDriver

class BaseDatabase < Base

  def initialize(handle, attr)
    @handle = handle
    @attr   = {}
    attr.each {|k,v| self[k] = v} 
  end

  def disconnect
    raise NotImplementedError
  end

  def ping
    raise NotImplementedError
  end

  def prepare(statement)
    raise NotImplementedError
  end

  #============================================
  # OPTIONAL
  #============================================

  def commit
    raise NotSupportedError
  end

  def rollback
    raise NotSupportedError
  end

  def tables
    []
  end

  def columns(table)
    []
  end


  def execute(statement, *bindvars)
    stmt = prepare(statement)
    stmt.bind_params(*bindvars)
    stmt.execute
    stmt
  end

  def do(statement, *bindvars)
    stmt = execute(statement, *bindvars)
    res = stmt.rows
    stmt.finish
    return res
  end

  # includes quote
  include DBI::SQL::BasicQuote

  def [](attr)
    @attr[attr]
  end

  def []=(attr, value)
    raise NotSupportedError
  end

end # class BaseDatabase


class BaseStatement < Base

  def bind_param(param, value, attribs)
    raise NotImplementedError
  end

  def execute
    raise NotImplementedError
  end

  def finish
    raise NotImplementedError
  end
 
  def fetch
    raise NotImplementedError
  end

  ##
  # returns result-set column information as array
  # of hashs, where each hash represents one column
  def column_info
    raise NotImplementedError
  end

  #============================================
  # OPTIONAL
  #============================================

  def bind_params(*bindvars)
    bindvars.each_with_index {|val,i| bind_param(i+1, val, nil) }
    self
  end

  def cancel
  end

  def fetch_scroll(direction, offset)
    case direction
    when SQL_FETCH_NEXT
      return fetch
    when SQL_FETCH_LAST
      last_row = nil
      while (row=fetch) != nil
        last_row = row
      end
      return last_row
    when SQL_FETCH_RELATIVE
      raise NotSupportedError if offset <= 0
      row = nil
      offset.times { row = fetch; break if row.nil? }
      return row
    else
      raise NotSupportedError
    end
  end

  def fetch_many(cnt)
    rows = []
    cnt.times do
      row = fetch
      break if row.nil?
      rows << row.dup
    end

    if rows.empty?
      nil
    else
      rows
    end
  end

  def fetch_all
    rows = []
    loop do
      row = fetch
      break if row.nil?
      rows << row.dup
    end

    if rows.empty?
      nil
    else
      rows
    end
  end

end # class BaseStatement


end # module DBI


