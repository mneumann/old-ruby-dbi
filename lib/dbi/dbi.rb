# (Another) DBI for Ruby. Perl-like.
# 
# Version : 0.0.4
# Author  : Rainer Perl (rainer.perl@sprytech.com)
# Homepage: http://www.sprytech.com/~rainer.perl/ruby/
#
# Copyright (c) 2001 Rainer Perl
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

module DBI

 @@driverMap = Hash.new 
 
 def DBI.register(driverName, driverClass)
  @@driverMap[driverName] = driverClass
 end
 
 def DBI.get_driver(driverName)
  return @@driverMap[driverName]
 end
 
 def DBI.connect(db_path, db_user, db_pass)
  if db_path !~ /^DBI:([^:]+)(:(.*))?$/ then raise 'Invalid path (1)' end
  db_driver = $1
  db_args = $3
  require "dbi/dbd_#{db_driver}"
  return DBHandle.new(db_driver, db_user, db_pass, db_args)
 rescue LoadError
  raise "Unable to load driver '#{db_driver}' - check driver-installation (1)"
 end
 
 
 class DBHandle 
  def initialize(db_driver, db_user, db_pass, db_args)
   @lastDoDur = 0
   @db_handle=(DBI.get_driver(db_driver))::DBHandle.new(db_user, db_pass, db_args)
  rescue NameError
   raise "Unable to load driver '#{db_driver}' - are you sure it should work with this DBI-version?"
  end
  
  def disconnect
   raise 'Not supported (1)' unless @db_handle.respond_to?('disconnect')
   
   # I'll use this "raise 'Not supported..." line for every method that
   # the driver is expected to provide. I'm wondering if there is a better
   # way to do this error-check - something I don't have to copy&paste for
   # every new method I add - because this feels like bad programming.
   
   @db_handle.disconnect
  end

  def do(sqlstring)
   raise 'Not supported (1)' unless @db_handle.respond_to?('do')
   starttime=Time.now
   @db_handle.do(sqlstring)
   @lastDoDur=Time.now-starttime
  end
  
  def prepare(sqlstring)
   raise 'Not supported (1)' unless @db_handle.respond_to?('do_store')
   return StatementHandle.new(@db_handle, sqlstring)
  end
  
  def quote(aString)
   raise 'Not supported (1)' unless @db_handle.respond_to?('quote')
   return @db_handle.quote(aString)
  end
  
  attr_reader :lastDoDur     
 end
 
 class StatementHandle

  def name
   @fieldInfos.get('name')
  end

  def num_of_fields
   @fieldInfos.get('name').length
  end
  
  def initialize(db_handle, sqlstring)
   @db_handle = db_handle
   @sqlstring = sqlstring
   @myArray = Array.new
   @myHash = Hash.new
   @lastExecDur = 0
  end
  
  def execute
   raise 'Already executed (1)' if defined? @res_handle
   starttime=Time.now
   @res_handle = ResultHandle.new(@db_handle, @sqlstring)  
   @lastExecDur=Time.now-starttime
   @fieldInfos = FieldInfos.new(@res_handle)
  end
  
  def finish
   @res_handle.finish
   @res_handle=nil
  end
  
  def fetchrow_array
   return @res_handle.fetchrow
  end

  def fetchrow_arrayref

   # It seems that I need to do some funny things to return a _reference_ to an
   # array. Using @myArray.clear and @myArray.concat was the only way I found
   # to get fetchrow_arrayref to behave like in Perl, e.g.:
   #
   # Perl DBI-documentation:
   #
   #        Note that currently the same array ref will be
   #        returned for each fetch so don't store the ref and
   #        then use it after a later fetch.   
   #

   @myArray.clear
   @myArray.concat(@res_handle.fetchrow) # will cause TypeError if
   return @myArray                       # @res_handle.fetchrow is null
  rescue TypeError
   return nil # no more rows 
  end
  
  def fetchrow_hashref   
   @myHash.clear                   # See fetchrow_arrayref to explain this line
   myNames = self.name
   return nil unless myVals = @res_handle.fetchrow  # if @res_handle.fetchrow
   0.upto(self.num_of_fields-1) do |aIndex|         # returns nil, exit
    @myHash[myNames[aIndex]] = myVals[aIndex]       
   end
   return @myHash
  end

  attr_reader :lastExecDur
 end
 
 class ResultHandle
  def initialize(db_handle, sqlstring)
   @dbd_res_handle = db_handle.do_store(sqlstring)
  end
  
  def finish
   @dbd_res_handle.finish
   @dbd_res_handle=nil
  end  
  
  def fetch_fields
   return @dbd_res_handle.fetch_fields
  end
  
  def fetchrow
   return @dbd_res_handle.fetchrow
  end
 end

 class FieldInfos
  def initialize(res_handle)
   @dbFields=Array.new
   (res_handle.fetch_fields).each do |field|
    @dbFields.push(Hash['name' => field['name']])
   end
  end
  
  def get(property)
   myResult = Array.new
   @dbFields.each { |field| myResult.push(field[property]) }
   return myResult
  end
 end
 
end
