# DBD DB2 driver for Ruby's DBI
#
# Based on (and requires) the "IBM DB2 Module for Ruby"
# by myself (Michael Neumann) <neumann@s-direktnet.de> http://www.fantasy-coders.de/ruby
# 
# Version : $Id: DB2.rb,v 1.1 2001/05/30 12:40:14 michael Exp $
# Author  : Michael Neumann (neumann@s-direktnet.de)
# Homepage: http://www.s-direktnet.de/homepages/neumann/
# DBD API : 0.1
#
# Copyright (c) 2001 Michael Neumann
#
# This program is released under the same terms as Ruby.


require 'db2/db2cli.rb'

module DBI
module DBD
module DB2

USED_DBD_VERSION = "0.1"

  module Util
    include DB2CLI 

    private

    def rc_ok(rc)
      rc == SQL_SUCCESS or rc == SQL_SUCCESS_WITH_INFO
    end
   
    def error(rc, msg)
      raise DBI::Error.new(msg) unless rc_ok(rc)
    end
  end # module DB2Util


  class Driver < DBI::BaseDriver
    include Util

    def initialize
      super(USED_DBD_VERSION)  

      rc, @env = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE)
      error(rc, "Could not allocate Environment")
    end

    def connect(dbname, user, auth, attr)
      rc, dbc = SQLAllocHandle(SQL_HANDLE_DBC, @env) 
      error(rc, "Could not allocate Database Connection") 

      rc = SQLConnect(dbc, dbname, user, auth) 
      error(rc, "Could not connect to Database")

      return Database.new(dbc, attr)
    end
 
    def data_sources
      data_sources_buffer.collect {|s| "dbi:DB2:#{s}"}
    end


    private

    def data_sources_buffer(buffer_length = 1024)
      retval = []
      max_buffer_length = buffer_length

      a = SQLDataSources(@env, DB2CLI::SQL_FETCH_FIRST, SQL_MAX_DSN_LENGTH+1, buffer_length)
      return retval if a[0] == SQL_NO_DATA_FOUND 
      retval << a[1]
      max_buffer_length = [max_buffer_length, a[4]].max

      loop do
        a = SQLDataSources(@env, DB2CLI::SQL_FETCH_NEXT, SQL_MAX_DSN_LENGTH+1, buffer_length)
        break if a[0] == SQL_NO_DATA_FOUND

        retval << a[1]
        max_buffer_length = [max_buffer_length, a[4]].max
      end 
     
      if max_buffer_length > buffer_length then
        data_sources_buffer(max_buffer_length)
      else
        retval
      end
    end




  end # class Driver

  class Database < DBI::BaseDatabase
    include Util
  
    def disconnect
      rollback
      rc = SQLDisconnect(@handle)
      error(rc, "Could not disconnect from Database")

      rc = SQLFreeHandle(SQL_HANDLE_DBC, @handle)
      error(rc, "Could not free Database handle")
    end


    def tables
      rc, stmt = SQLAllocHandle(SQL_HANDLE_STMT, @handle)
      error(rc, "Could not allocate Statement")

      rc = SQLTables(stmt, "", "%", "%", "TABLE, VIEW")
      error(rc, "Could not execute SQLTables") 
      
      st = Statement.new(stmt)
      res = st.fetch_all
      st.finish

      res.collect {|row| row[1].to_s + "." + row[2].to_s} 
    end


    def ping
      begin
        stmt = execute("SELECT 1 FROM SYSCAT.TABLES")
        stmt.fetch
        stmt.finish
        return true
      rescue DBI::Error, DBI::Warning
        return false
      end 
    end

    def prepare( statement )
      rc, stmt = SQLAllocHandle(SQL_HANDLE_STMT, @handle)
      error(rc, "Could not allocate Statement")

      rc = SQLPrepare(stmt, statement)
      error(rc, "Could not prepare SQL")

      Statement.new(stmt)
    end

    # TODO
    #def []=(attr, value)
    #end


    def commit
      rc = SQLEndTran(SQL_HANDLE_DBC, @handle, SQL_COMMIT)
      error(rc, "Could not commit transaction")
    end

    def rollback
      rc = SQLEndTran(SQL_HANDLE_DBC, @handle, SQL_ROLLBACK)
      error(rc, "Could not rollback transaction")
    end

  end # class Database


  class Statement < DBI::BaseStatement
    include Util

    def initialize(handle)
      @handle = handle
      @arr = []
    end

    # TODO:
    #def bind_param(param, value, attribs)
    #end

    def execute
      rc = SQLExecute(@handle)      
      error(rc, "Could not execute statement")
    end

    def finish
      rc = SQLFreeHandle(SQL_HANDLE_STMT, @handle)
      error(rc, "Could not free Statement")
    end

    def fetch
      cols = get_col_info

      rc = SQLFetch(@handle)
      return nil if rc == SQL_NO_DATA_FOUND
      error(rc, "Could not fetch row")

      cols.each_with_index do |c, i|
        rc, content = SQLGetData(@handle, i+1, c[1], c[2]) 
        error(rc, "Could not get data")
        @arr[i] = content
      end 

      return @arr
    end

    def column_info
      get_col_names.collect do |n| {'name' => n} end
    end

    def cancel
      rc = SQLFreeStmt(@handle, SQL_CLOSE)
      error(rc, "Cannot close/cancel statment") 
    end

    def rows
      rc, rpc = SQLRowCount(@handle)
      error(rc, "Cannot get RPC") 
      return rpc 
    end


    private

    #
    # returns array of [name, type, column_size]
    #
    def get_col_info
      rc, nr_cols = SQLNumResultCols(@handle)
      error(rc, "Could not get number of result columns")
    
      (1..nr_cols).collect do |c| 
        rc, name, bl, type, col_sz = SQLDescribeCol(@handle, c, 200)
        error(rc, "Could not describe column")
        [name, type, col_sz]
      end 
    end

    def get_col_names
      get_col_info.collect {|i| i[0] }
    end

  end # class Statement



end # module DB2
end # module DBD
end # module DBI

