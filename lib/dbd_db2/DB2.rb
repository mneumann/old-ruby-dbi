# DBD DB2 driver for Ruby's DBI
#
# Based on (and requires) the "IBM DB2 Module for Ruby"
# by myself (Michael Neumann) <neumann@s-direktnet.de> http://www.fantasy-coders.de/ruby
# 
# Version : $Id: DB2.rb,v 1.4 2001/08/30 14:10:51 michael Exp $
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
      raise DBI::DatabaseError.new(msg) unless rc_ok(rc)
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
      @cols = get_col_info
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
      do_fetch(SQLFetch(@handle))
    end

    def fetch_scroll(direction, offset)
      direction = case direction
      when DBI::SQL_FETCH_FIRST    then ::DB2CLI::SQL_FETCH_FIRST
      when DBI::SQL_FETCH_LAST     then ::DB2CLI::SQL_FETCH_LAST
      when DBI::SQL_FETCH_PRIOR    then ::DB2CLI::SQL_FETCH_PRIOR
      when DBI::SQL_FETCH_NEXT     then ::DB2CLI::SQL_FETCH_NEXT
      when DBI::SQL_FETCH_RELATIVE then ::DB2CLI::SQL_FETCH_RELATIVE
      when DBI::SQL_FETCH_ABSOLUTE then ::DB2CLI::SQL_FETCH_ABSOLUTE
      else
        raise
      end
      do_fetch(SQLFetchScroll(@handle, direction, offset))
    end

    def column_info
      @cols
      #get_col_names.collect do |n| {'name' => n} end
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

    # TODO: check typenames
    DB2_to_DBI_type_mapping = {
      DB2CLI::SQL_DOUBLE         => [DBI::SQL_DOUBLE,        'DOUBLE'],
      DB2CLI::SQL_FLOAT          => [DBI::SQL_FLOAT,         'FLOAT'],
      DB2CLI::SQL_REAL           => [DBI::SQL_REAL,          'REAL'],

      DB2CLI::SQL_INTEGER        => [DBI::SQL_INTEGER,       'INTEGER'],
      DB2CLI::SQL_BIGINT         => [DBI::SQL_BIGINT,        'BIGINT'],
      DB2CLI::SQL_SMALLINT       => [DBI::SQL_SMALLINT,      'SMALLINT'],

      DB2CLI::SQL_DECIMAL        => [DBI::SQL_DECIMAL,       'DECIMAL'],
      DB2CLI::SQL_NUMERIC        => [DBI::SQL_NUMERIC,       'NUMERIC'],

      DB2CLI::SQL_TYPE_DATE      => [DBI::SQL_DATE,          'DATE'],
      DB2CLI::SQL_TYPE_TIME      => [DBI::SQL_TIME,          'TIME'],
      DB2CLI::SQL_TYPE_TIMESTAMP => [DBI::SQL_TIMESTAMP,     'TIMESTAMP'],

      DB2CLI::SQL_CHAR           => [DBI::SQL_CHAR,          'CHAR'],
      DB2CLI::SQL_VARCHAR        => [DBI::SQL_VARCHAR,       'VARCHAR'],
      DB2CLI::SQL_LONGVARCHAR    => [DBI::SQL_LONGVARCHAR,   'LONG VARCHAR'],
      DB2CLI::SQL_CLOB           => [DBI::SQL_CLOB,          'CLOB'],        

      DB2CLI::BINARY             => [DBI::SQL_BINARY,        'BINARY'],
      DB2CLI::VARBINARY          => [DBI::SQL_VARBINARY,     'VARBINARY'],
      DB2CLI::LONGVARBINARY      => [DBI::SQL_LONGVARBINARY, 'LONG VARBINARY'],
      DB2CLI::SQL_BLOB           => [DBI::SQL_BLOB,          'BLOB'],        

      DB2CLI::SQL_BLOB_LOCATOR   => [DBI::SQL_OTHER,         'BLOB LOCATOR'],        
      DB2CLI::SQL_CLOB_LOCATOR   => [DBI::SQL_OTHER,         'CLOB LOCATOR'],        
      DB2CLI::SQL_DBCLOB_LOCATOR => [DBI::SQL_OTHER,         'DBCLOB LOCATOR'],        

      DB2CLI::SQL_DBCLOB         => [DBI::SQL_OTHER,         'DBCLOB'],        
      DB2CLI::SQL_GRAPHIC        => [DBI::SQL_OTHER,         'GRAPHIC'],        
      DB2CLI::SQL_VARGRAPHIC     => [DBI::SQL_OTHER,         'VARGRAPHIC'],        
      DB2CLI::SQL_LONGVARGRAPHIC => [DBI::SQL_OTHER,         'LONG VARGRAPHIC']
    }

    MAX_COL_SIZE = 256

    #
    # returns array of hashs
    #
    def get_col_info
      rc, nr_cols = SQLNumResultCols(@handle)
      error(rc, "Could not get number of result columns")
    
      (1..nr_cols).collect do |c| 
        rc, column_name, buflen, data_type, column_size, decimal_digits, nullable = SQLDescribeCol(@handle, c, MAX_COL_SIZE)
        error(rc, "Could not describe column")
    
        sql_type, type_name = DB2_to_DBI_type_mapping[data_type]

        { 
          'name'       => column_name,
          'sql_type'   => sql_type,
          'type_name'  => type_name,
          'precision'  => column_size,
          'scale'      => decimal_digits,
          'nullable'   => nullable,
          'db2_type'   => data_type
        }
      end 
    end

    def do_fetch(rc)
      return nil if rc == SQL_NO_DATA_FOUND
      error(rc, "Could not fetch row")

      @cols.each_with_index do |c, i|
        rc, content = SQLGetData(@handle, i+1, c['db2_type'], c['precision']) 
        error(rc, "Could not get data")

        @arr[i] = 
        if content.is_a? ::DB2CLI::Date 
          DBI::Date.new(content.year, content.month, content.day)
        elsif content.is_a? ::DB2CLI::Time
          DBI::Time.new(content.hour, content.minute, content.second)
        elsif content.is_a? ::DB2CLI::Timestamp 
          DBI::Timestamp.new(content.year, content.month, content.day,
            content.hour, content.minute, content.second, content.fraction)
        elsif content.is_a? ::DB2CLI::Null
          nil
        else  
          content
        end
      end 

      return @arr
    end

  end # class Statement



end # module DB2
end # module DBD
end # module DBI

