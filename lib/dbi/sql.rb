#
# $Id: sql.rb,v 1.2 2001/06/11 00:11:29 michael Exp $
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
      boundsql = sql.gsub(/\?\?/, "\001")

      indices = []
      i = -1
      while i = boundsql.index("?", i+1)
        indices.unshift(i)
      end
 
      case indices.size <=> args.size
      when -1 
        raise "Too many SQL parameters"
      when 1
        raise "Not enough SQL parameters"
      end

      indices.each_with_index {|inx, i| boundsql[inx,1] = quoter.quote(args[-(i+1)])}

      boundsql.gsub(/\001/, "?")
    end

  end # module BasicBind

end # module SQL
end # module DBI
