require 'postgres'

module DBI
  module DBD
    module Pg
      
      VERSION          = "0.1"
      USED_DBD_VERSION = "0.1"
      
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
	  answer = send_sql("SELECT typname FROM pg_type", 3)
	  return answer.result.size > 1
	rescue PGError
	  return false
	ensure
	  answer.clear
	end

        def tables
          stmt = execute("SELECT relname FROM pg_class WHERE relkind='r'")
          res = stmt.fetch_all.collect {|row| row[0]} 
          stmt.finish
          res
        end

	def prepare(statement)
	  Statement.new(self, statement)
	end
	
	def [](attr)
	  @attr[attr]
	end
	
	def []=(attr, value)
	  case attr
	  when 'AutoCommit'
	    @autocommit = value
	  else
	    raise NotSupportedError
	  end
	  @attr[attr] = value
	end

	def commit
	  send_sql("COMMIT WORK", 2)
	  @in_transaction = false
	end

	def rollback
	  send_sql("ROLLBACK WORK", 2)
	  @in_transaction = false
	end

	# Other Public Methods ---------------------------------------

	def convert(obj,typeid)
	  return nil if obj.nil?
	  converter = @type_map[typeid]
	  raise DBI::InterfaceError, "Unsupported Type (typeid=#{typeid})" if converter.nil?
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
          @coerce = DBI::SQL::BasicQuote::Coerce.new

	  res = send_sql("SELECT typname, typelem FROM pg_type")

	  res.result.each { |name, idstr|
	    @type_map[idstr.to_i] = 
            case name
            when '_bool'                     then :as_bool
	    when '_int8', '_int4', '_int2'   then :as_int
	    when '_varchar'                  then :as_str
	    when '_float4','_float8'         then :as_float
            when '_timestamp'                then :as_timestamp
            when '_date'                     then :as_date
            else                                  :as_str
	    end
	  }
	end

      end # Database

      ################################################################
      class Statement < DBI::BaseStatement
	
	include SQL::BasicQuote
	include SQL::BasicBind

	def initialize(db, sql)
	  @db  = db
	  @sql = sql
	  @result = nil
	  @bindvars = []
	end
	
	def bind_param(index, value, options)
	  @bindvars[index-1] = value
	end

	def execute
	  boundsql = bind(self, @sql, @bindvars)
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
	    @result.row_count
	  else
	    nil
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
	  @row = Array.new
	end

	def column_info
	  @pg_result.fields.collect do |str| {'name'=>str} end
	end

	def fetchrow
	  @index += 1
	  if @index < @pg_result.result.size 
	    fill_array(@pg_result.result[@index])
	  else
	    @row = nil
	  end
	  @row
	end

	def row_count
	  @pg_result.num_tuples
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
      
    end # module Pg
  end # module DBD
end # module DBI
