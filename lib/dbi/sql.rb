#
# $Id: sql.rb,v 1.1 2001/05/31 13:26:59 michael Exp $
#
# extracted from Jim Weirichs DBD::Pg
#

module DBI

module SQL

  # Is the SQL statement a query?
  def SQL.query?(sql)
    sql =~ /^\s*select\b/i
  end


  # ====================================================================
  module BasicQuote
    
    # Mixin module useful for expanding SQL statements.
    
    def quote(value)
      # Quote strings appropriately for SQL statements
      case value
      when String
	value.gsub!(/'/, "''")	# " (for ruby-mode)
	"'#{value}'"
      when NilClass
	"NULL"
      when Array
	value.collect { |v| quote(v) }.join(", ")
      else
	value.to_s
      end
    end
  end # module BasicQuote

  module BasicBind

    def bind(quoter, sql, args)
      boundsql = sql.dup
      boundsql.gsub! (/\?\?/, "\001")
      args.each { |arg|
	if ! boundsql.sub! (/\?/, quoter.quote(arg))
	  raise "Too many SQL parameters"
	end
      }
      raise "Not enough SQL parameters" if boundsql =~ /\?/
      boundsql.gsub!(/\001/, "?")
      boundsql
    end

  end # module BasicBind

end # module SQL
end # module DBI
