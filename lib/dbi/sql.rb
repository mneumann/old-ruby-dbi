#
# $Id: sql.rb,v 1.10 2001/11/25 23:25:41 michael Exp $
#
# parts extracted from Jim Weirichs DBD::Pg
#

module DBI
require "parsedate"

module SQL

  ## Is the SQL statement a query?
  def SQL.query?(sql)
    sql =~ /^\s*select\b/i
  end


  ####################################################################
  # Mixin module useful for expanding SQL statements.
  #
  module BasicQuote

    # by Masatoshi SEKI
    class Coerce
      def as_int(str)
        if str == "" then nil else str.to_i end 
      end 

      def as_float(str)
        str.to_f
      end

      def as_str(str)
        str
      end

      def as_bool(str)
        if str == "t"
          true
        elsif str == "f"
          false
        else
          nil
        end
      end

      def as_time(str)
        t = as_timestamp(str)
        DBI::Time.new(t.hour, t.min, t.sec)
      end


      def as_timestamp(str)
        ary = ParseDate.parsedate(str)
        time = ::Time.gm(*(ary[0,6]))
        if ary[6] =~ /^(\+|\-)\d+$/
          diff = ary[6].to_i * 60 * 60
          time -= diff
          time.localtime
        end 
        DBI::Timestamp.new(time)
      end


      def as_date(str)
        ary = ParseDate.parsedate(str)
        DBI::Date.new(*ary[0,3])
      rescue
        nil
      end


      def coerce(sym, str)
        self.send(sym, str)
      end

    end # class Coerce

    
    ## Quote strings appropriately for SQL statements
    def quote(value)
      case value
      when String
	value = value.gsub(/'/, "''")	# ' (for ruby-mode)
	"'#{value}'"
      when NilClass
	"NULL"
      when TrueClass
        "'t'"
      when FalseClass
        "'f'"
      when Array
	value.collect { |v| quote(v) }.join(", ")
      when DBI::Date, DBI::Time, DBI::Timestamp, ::Date, ::Time
        "'#{value.to_s}'"
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


  class PreparedStatement
    include BasicBind # for method tokens(sql)

    attr_accessor :unbound

    def initialize(quoter, sql)
      @quoter, @sql = quoter, sql
      prepare
    end

    def bind(args)
      if @arg_index < args.size
        raise "Too many SQL parameters"
      elsif @arg_index > args.size
        raise "Not enough SQL parameters"
      end

      @unbound.each do |res_pos, arg_pos|
        @result[res_pos] = @quoter.quote(args[arg_pos])
      end

      @result.join("")
    end

    private

    def prepare
      @result = [] 
      @unbound = {}
      pos = 0
      @arg_index = 0

      tokens(@sql).each { |part|
	case part
	when '?'
          @result[pos] = nil
          @unbound[pos] = @arg_index
          pos += 1
          @arg_index += 1
	when '??'
          if @result[pos-1] != nil
            @result[pos-1] << "?"
          else
            @result[pos] = "?"
            pos += 1
          end
	else
          if @result[pos-1] != nil
            @result[pos-1] << part
          else
            @result[pos] = part
            pos += 1
          end
	end
      }
    end
  end

end # module SQL
end # module DBI
