require "mysql"

module DBI
module DBD
module Mysql

VERSION          = "0.1"
USED_DBD_VERSION = "0.1"

class Driver < DBI::BaseDriver

  def initialize
    super(USED_DBD_VERSION)
  end

  def connect(dbname, user, auth, attr)
    # connect to database
    hash = Utils.parse_params(dbname)

    if hash['database'].nil? 
      raise InterfaceError, "must specify database"
    end

    hash['host'] ||= 'localhost'

    handle = ::Mysql.connect(hash['host'], user, auth)
    handle.select_db(hash['database'])
    return Database.new(handle, attr)
  end

  def data_sources
    handle = ::Mysql.new
    res = handle.list_dbs.collect {|db| "dbi:Mysql:database=#{db}" }
    handle.close
    return res
  end


end

class Database < DBI::BaseDatabase
 
  def disconnect
    @handle.close
  end

  def ping
    klass = ::MysqlError
    begin
      @handle.ping
      return true
    rescue klass
      return false
    end
  end

  def tables
    @handle.list_tables
  end

  # TODO: 
  # def do
  
  def prepare(statement)
    Statement.new(@handle, statement)
  end

  # TODO: Raise Error
  def commit
  end

  # TODO: Raise Error
  def rollback
  end

  def quote(value)
    '#{::Mysql.quote(value)}'
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
    @handle.query_with_result = true
    # TODO: substitute all ? by the parametes
    @res_handle = @handle.query(@statement)
    @rows = @handle.affected_rows
  end

  def finish
    @res_handle.free
  end

  def fetch
    @res_handle.fetch_row
  end

  def column_info
    retval = []

    return [] if @res_handle.nil?

    @res_handle.fetch_fields.each {|col| 
      retval << {'name' => col.name }
    }
    retval
  end

  def rows
    @rows
  end

end


end # module Mysql
end # module DBD
end # module DBI




