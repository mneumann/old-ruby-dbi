#
# $Id: sql.rb,v 1.3 2001/06/17 20:04:07 jweirich Exp $
#
# extracted from Jim Weirichs DBD::Pg
#

module DBI

module SQL

  ## Is the SQL statement a query?
  def SQL.query?(sql)
    sql =~ /^\s*select\b/i
  end


  ####################################################################
  # Mixin module useful for expanding SQL statements.
  #
  module BasicQuote
    
    ## Quote strings appropriately for SQL statements
    def quote(value)
      case value
      when String
	value.gsub!(/'/, "''")	# ' (for ruby-mode)
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


  ####################################################################
  # Mixin module useful for binding arguments to an SQL string.
  #
  module BasicBind

    ## Bind the :sql string to an array of :args, quoting with :quoter.
    #
    def bind(quoter, sql, args)
      arg_index = 0
      result = ""
      tokens(sql).each { |part|
	case part
	when '?'
	  result << quoter.quote(args[arg_index])
	  arg_index += 1
	when '??'
	  result << "?"
	else
	  result << part
	end
      }
      if arg_index < args.size
        raise "Too many SQL parameters"
      elsif arg_index > args.size
        raise "Not enough SQL parameters"
      end
      result
    end

    ## Break the sql string into parts.
    #
    # This is NOT a full lexer for SQL.  It just breaks up the SQL
    # string enough so that question marks, double question marks and
    # quoted strings are separated.  This is used when binding
    # arguments to "?" in the SQL string.  Note: comments are not
    # handled.  
    #
    def tokens(sql)
      toks = sql.scan(/('([^'\\]|''|\\.)*'|"([^"\\]|""|\\.)*"|\?\??|[^'"?]+)/)
      toks.collect {|t| t[0]}
    end

  end # module BasicBind

end # module SQL
end # module DBI
