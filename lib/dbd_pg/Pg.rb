#
# DBD::Pg
#
# Copyright (c) 2001, 2002 Jim Weirich, Michael Neumann <neumann@s-direktnet.de>
# 
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions 
# are met:
# 1. Redistributions of source code must retain the above copyright 
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright 
#    notice, this list of conditions and the following disclaimer in the 
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# $Id: Pg.rb,v 1.23 2002/07/26 17:56:43 mneumann Exp $
#

require 'postgres'

module DBI
  module DBD
    module Pg
      
      VERSION          = "0.3.0"
      USED_DBD_VERSION = "0.2"
      
      class Driver < DBI::BaseDriver
	
	def initialize
	  super(USED_DBD_VERSION)
	end
	
	## List of datasources for this database.
	def data_sources
	  []
	end
	
	## Connect to a database.
	def connect(dbname, user, auth, attr)
	  Database.new(dbname, user, auth, attr)
	end

      end
      
      ################################################################
      class Database < DBI::BaseDatabase

        # type map ---------------------------------------------------
        
        # by Eli Green
        POSTGRESQL_to_XOPEN = {
          "boolean"                   => [SQL_CHAR, 1, nil],
          "character"                 => [SQL_CHAR, 1, nil],
          "char"                      => [SQL_CHAR, 1, nil],
          "real"                      => [SQL_REAL, 4, 6],
          "double precision"          => [SQL_DOUBLE, 8, 15],
          "smallint"                  => [SQL_SMALLINT, 2],
          "integer"                   => [SQL_INTEGER, 4],
          "bigint"                    => [SQL_BIGINT, 8],
          "numeric"                   => [SQL_NUMERIC, nil, nil],
          "time with time zone"       => [SQL_TIME, nil, nil],
          "timestamp with time zone"  => [SQL_TIMESTAMP, nil, nil],
          "bit varying"               => [SQL_BINARY, nil, nil], #huh??
          "character varying"         => [SQL_VARCHAR, nil, nil],
          "bit"                       => [SQL_TINYINT, nil, nil],
          "text"                      => [SQL_VARCHAR, nil, nil],
          nil                         => [SQL_OTHER, nil, nil]
        }
	
	attr_reader :connection
	attr_accessor :autocommit

	def initialize(dbname, user, auth, attr)
	  @debug_level = 0


	  @attr = attr
	  @attr.each { |k,v| self[k] = v} 

          hash = Utils.parse_params(dbname)

          if hash['dbname'].nil? and hash['database'].nil?
            raise DBI::InterfaceError, "must specify database"
          end

          hash['options'] ||= ''
          hash['tty'] ||= ''
          hash['port'] = hash['port'].to_i unless hash['port'].nil? 

	  @connection = PGconn.new(hash['host'], hash['port'], hash['options'], hash['tty'], 
            hash['dbname'] || hash['database'], user, auth)

	  load_type_map
	  @in_transaction = false
	  initialize_autocommit
	rescue PGError => err
	  raise DBI::OperationalError.new(err.message)
	end
	
	# DBD Protocol -----------------------------------------------

	def disconnect
	  if not @autocommit and @in_transaction then
	    send_sql("COMMIT WORK", 2)
	  end
	  @connection.close
	end
	
	def ping
	  answer = send_sql("SELECT 1", 3)
          if answer
            return answer.num_tuples == 1
          else
            return false
          end
	rescue PGError
	  return false
	ensure
	  answer.clear if answer
	end

        def tables
          stmt = execute("SELECT relname FROM pg_class WHERE relkind='r'")
          res = stmt.fetch_all.collect {|row| row[0]} 
          stmt.finish
          res
        end

        ##
        # by Eli Green (cleaned up by Michael Neumann)
        #
        def columns(table)
          sql1 = %[
            SELECT a.attname, i.indisprimary, i.indisunique 
                   FROM pg_class bc, pg_class ic, pg_index i, pg_attribute a 
            WHERE bc.relkind = 'r' AND bc.relname = ? AND i.indrelid = bc.oid AND 
                  i.indexrelid = ic.oid AND ic.oid = a.attrelid
          ]

          sql2 = %[
            SELECT a.attname, a.atttypid, a.attnotnull, a.attlen, format_type(a.atttypid, a.atttypmod) 
                   FROM pg_class c, pg_attribute a, pg_type t 
            WHERE a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid AND c.relname = ?
          ]

          # by Michael Neumann (get default value)
          # corrected by Joseph McDonald
          sql3 = %[
            SELECT pg_attrdef.adsrc, pg_attribute.attname 
                   FROM pg_attribute, pg_attrdef, pg_class
            WHERE pg_class.relname = ? AND 
                  pg_attribute.attrelid = pg_class.oid AND
                  pg_attrdef.adrelid = pg_class.oid AND
                  pg_attrdef.adnum = pg_attribute.attnum
          ]

          dbh = DBI::DatabaseHandle.new(self)
	  indices = {}
          default_values = {}

          dbh.select_all(sql3, table) do |default, name|
            default_values[name] = default
          end

          dbh.select_all(sql1, table) do |name, primary, unique|
            indices[name] = [primary, unique]
          end

          ########## 

          ret = []
          dbh.execute(sql2, table) do |sth|
            ret = sth.collect do |row|
              name, pg_type, notnullable, len, ftype = row
              #name = row[2]
              indexed = false
              primary = nil
              unique = nil
              if indices.has_key?(name)
                indexed = true
                primary, unique = indices[name]
              end

              type = ftype
              pos = ftype.index('(')
              decimal = nil
              size = nil
              if pos != nil
                type = ftype[0..pos-1]
                size = ftype[pos+1..-2]
                pos = size.index(',')
                if pos != nil
                  size, decimal = size.split(',', 2)
                  size = size.to_i
                  decimal = decimal.to_i
                else
                  size = size.to_i
                end
              end
              size = len if size.nil?

              if POSTGRESQL_to_XOPEN.has_key?(type)
                sql_type = POSTGRESQL_to_XOPEN[type][0]
              else
                sql_type = POSTGRESQL_to_XOPEN[nil][0]
              end

              row = {}
              row['name']           = name
              row['sql_type']       = sql_type
              row['type_name']      = type
              row['nullable']       = ! notnullable
              row['indexed']        = indexed
              row['primary']        = primary
              row['unique']         = unique
              row['precision']      = size
              row['scale']          = decimal
              row['default']        = default_values[name]
              row
            end # collect
          end # execute

          return ret
        end

	def prepare(statement)
	  Statement.new(self, statement)
	end
	
        def [](attr)
          case attr
          when 'pg_client_encoding'
            @connection.client_encoding
          else
            @attr[attr]
          end
        end

	def []=(attr, value)
	  case attr
	  when 'AutoCommit'
	    @autocommit = value
          when 'pg_client_encoding'
            @connection.set_client_encoding(value)
	  else
            if attr =~ /^pg_/ or attr != /_/
              raise DBI::NotSupportedError, "Option '#{attr}' not supported"
            else # option for some other driver - quitly ignore
              return
            end
	  end
	  @attr[attr] = value
	end

	def commit
          if @in_transaction
  	    send_sql("COMMIT WORK", 2)
	    @in_transaction = false
          end
	end

	def rollback
          if @in_transaction
  	    send_sql("ROLLBACK WORK", 2)
	    @in_transaction = false
          end
	end

	# Other Public Methods ---------------------------------------

	def convert(obj,typeid)
	  return nil if obj.nil?
	  converter = @type_map[typeid] || :as_str
          #raise DBI::InterfaceError, "Unsupported Type (typeid=#{typeid})" if converter.nil?
	  @coerce.coerce(converter, obj)
	end

	def in_transaction?
	  @in_transaction
	end

	def start_transaction
	  send_sql("BEGIN WORK", 2)
	  @in_transaction = true
	end

	def send_sql(sql, level=1)
	  puts "SQL TRACE: |#{sql}|" if @debug_level >= level
	  @connection.exec(sql)
	end
	
	private # ----------------------------------------------------

	def initialize_autocommit
	  @autocommit = true
	  @attr['AutoCommit'] = @autocommit
	end

	def load_type_map
	  @type_map = Hash.new
          @coerce = PgCoerce.new

	  res = send_sql("SELECT typname, typelem FROM pg_type")

	  res.result.each { |name, idstr|
	    @type_map[idstr.to_i] = 
            case name
            when '_bool'                      then :as_bool
	    when '_int8', '_int4', '_int2'    then :as_int
	    when '_varchar'                   then :as_str
	    when '_float4','_float8'          then :as_float
            when '_timestamp', '_timestamptz' then :as_timestamp
            when '_date'                      then :as_date
            when '_bytea'                     then :as_bytea
            else                                   :as_str
	    end
	  }
          
          # additional conversions
          @type_map[705]  ||= :as_str       # select 'hallo'
          @type_map[1114] ||= :as_timestamp # TIMESTAMP WITHOUT TIME ZONE
	end


        # Driver-specific functions ------------------------------------------------

        public

        def __blob_import(file)
          start_transaction unless in_transaction?
          @connection.lo_import(file)
	rescue PGError => err
          raise DBI::DatabaseError.new(err.message) 
        end

        def __blob_export(oid, file)
          start_transaction unless in_transaction?
          @connection.lo_export(oid.to_i, file)
	rescue PGError => err
          raise DBI::DatabaseError.new(err.message) 
        end

        def __blob_create(mode=PGlarge::INV_READ)
          start_transaction unless in_transaction?
          @connection.lo_create(mode)
	rescue PGError => err
          raise DBI::DatabaseError.new(err.message) 
        end

        def __blob_open(oid, mode=PGlarge::INV_READ)
          start_transaction unless in_transaction?
          @connection.lo_open(oid.to_i, mode)
	rescue PGError => err
          raise DBI::DatabaseError.new(err.message) 
        end

        def __blob_unlink(oid)
          start_transaction unless in_transaction?
          @connection.lo_unlink(oid.to_i)
	rescue PGError => err
          raise DBI::DatabaseError.new(err.message) 
        end

        def __blob_read(oid, length=nil)
          start_transaction unless in_transaction?
          blob = @connection.lo_open(oid.to_i, PGlarge::INV_READ)
          blob.open
          if length.nil?
            data = blob.read
          else
            data = blob.read(length)
          end
          blob.close
          data
	rescue PGError => err
          raise DBI::DatabaseError.new(err.message) 
        end

        #
        # encodes a string as bytea value.
        #
        # for encoding rules see:
        #   http://www.postgresql.org/idocs/index.php?datatype-binary.html
        #
        def __encode_bytea(str)
          a = str.split(/\\/, -1).collect! {|s|
            s.gsub!(/'/,    "\\\\047")  # '  => \\047 
            s.gsub!(/\000/, "\\\\000")  # \0 => \\000  
            s
          }
          a.join("\\\\")                # \  => \\
        end

      end # Database

      ################################################################
      class Statement < DBI::BaseStatement
	
	include SQL::BasicQuote

	def initialize(db, sql)
	  @db  = db
          @prep_sql = DBI::SQL::PreparedStatement.new(self, sql)
	  @result = nil
	  @bindvars = []
	end
	
	def bind_param(index, value, options)
	  @bindvars[index-1] = value
	end

	def execute
          # replace DBI::Binary object by oid returned by lo_import 
          @bindvars.collect! do |var|
            if var.is_a? DBI::Binary then
              blob = @db.__blob_create(PGlarge::INV_WRITE)
              blob.open
              blob.write(var.to_s)
              oid = blob.oid
              blob.close
              oid
            else
              var
            end
          end

	  boundsql = @prep_sql.bind(@bindvars)

	  if SQL.query?(boundsql) then
	    pg_result = @db.send_sql(boundsql)
	    @result = Tuples.new(@db, pg_result)
	  elsif @db.autocommit then
	    pg_result = @db.send_sql(boundsql)
	    @result = Tuples.new(@db, pg_result)
	  else
	    @db.start_transaction if not @db.in_transaction?
	    pg_result = @db.send_sql(boundsql)
	    @result = Tuples.new(@db, pg_result)
	  end
	rescue PGError, RuntimeError => err
	  raise DBI::ProgrammingError.new(err.message)
	end
	
	def fetch
	  @result.fetchrow
	end

	def fetch_scroll(direction, offset)
	  @result.fetch_scroll(direction, offset)
	end

	def finish
	  @result.finish if @result
	  @result = nil
	  @db = nil
	end
	
	# returns result-set column informations
	def column_info
	  @result.column_info
	end
	
	# Return the row processed count (or nil if RPC not available)
	def rows
	  if @result
            @result.rows_affected
	  else
	    nil
	  end
	end

        def [](attr)
          case attr
          when 'pg_row_count'
            if @result
              @result.row_count
            else
              nil
            end
          else
            @attr[attr]
          end
        end


	private # ----------------------------------------------------

      end # Statement
      
      ################################################################
      class Tuples

	def initialize(db,pg_result)
	  @db = db
	  @pg_result = pg_result
	  @index = -1
          @result = @pg_result.result
	  @row = Array.new
	end

	def column_info
	  @pg_result.fields.collect do |str| {'name'=>str} end
	end

	def fetchrow
	  @index += 1
	  if @index < @result.size && @index >= 0
	    fill_array(@result[@index])
	    @row
	  else
	    nil
	  end
	end

	def fetch_scroll(direction, offset)
	  # Exact semantics aren't too closely defined.  I attempted to follow the DBI:Mysql example.
	  case direction
	  when SQL_FETCH_NEXT
	    # Nothing special to do, besides the fetchrow
	  when SQL_FETCH_PRIOR
	    @index -= 2
	  when SQL_FETCH_FIRST
	    @index = -1
	  when SQL_FETCH_LAST
	    @index = @result.size - 2
	  when SQL_FETCH_ABSOLUTE
	    # Note: if you go "out of range", all fetches will give nil until you get back
	    # into range, this doesn't raise an error.
	    @index = offset-1
	  when SQL_FETCH_RELATIVE
	    # Note: if you go "out of range", all fetches will give nil until you get back
	    # into range, this doesn't raise an error.
	    @index += offset - 1
	  else
	    raise NotSupportedError
	  end
	  self.fetchrow
	end

        def row_count
          @pg_result.num_tuples
        end

        def rows_affected
          @pg_result.cmdtuples
        end

	def finish
	  @pg_result.clear
	end

	private # ----------------------------------------------------

	def fill_array(rowdata)
	  rowdata.each_with_index { |value, index|
	    @row[index] = @db.convert(rowdata[index],@pg_result.type(index))
	  }
	end

      end # Tuples

      ################################################################
      class PgCoerce < DBI::SQL::BasicQuote::Coerce
        #
        # for decoding rules see:
        #   http://www.postgresql.org/idocs/index.php?datatype-binary.html
        #
        def as_bytea(str)
          a = str.split(/\\\\/, -1).collect! {|s|
            s.gsub!(/\\[0-7][0-7][0-7]/) {|o| o[1..-1].oct.chr}  #  \### => chr(###)
            s
          }
          a.join("\\")  # \\ => \
        end
      end

    end # module Pg
  end # module DBD
end # module DBI
