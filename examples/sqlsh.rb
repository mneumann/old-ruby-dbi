#
# $Id: sqlsh.rb,v 1.10 2001/11/13 14:53:50 michael Exp $
# by Michael Neumann
#

require "dbi"

class ReadlineControl
  
  attr_accessor :keywords

  def initialize
    begin
      require "readline"
      @readline = true
    rescue LoadError
      @readline = false
    end
      
    @keywords = []
    set_prompt
    if @readline
      Readline.completion_proc = proc {|str| complete(str) }
    end
  end

  def complete(str)
    @keywords.grep(/^#{Regexp.escape(str)}/i)
  end

  def set_prompt(prompt="> ")
    @prompt = prompt
  end

  def readline
    if @readline
      Readline.readline(@prompt, true)
    else
      print @prompt
      $stdin.readline
    end
  end

end

def output_table(header, rows)
  DBI::Utils::TableFormatter.ascii(header, rows, nil, nil, nil, nil, $page_len) do   
    break if $stdin.readline.chomp == "a"
  end
end


if ARGV.size < 1 or ARGV.size > 3
  puts
  puts "USAGE: #{$0} driver_url [user [password] ]"
  puts

  puts "Available driver and datasources:"
  puts
  for driver in DBI.available_drivers do
    puts driver 
    begin
      ds = DBI.data_sources(driver)
      for datasource in ds
        puts "  " + datasource
      end
    rescue => err
    end
    puts
  end
  puts 

  exit 1
else
  DRIVER_URL = ARGV.shift
  USER       = ARGV.shift
  PASS       = ARGV.shift
end

puts
begin
  Conn = DBI.connect(DRIVER_URL, USER, PASS)
  print "CONNECT TO #{DRIVER_URL} "
  print "USER #{USER} " unless USER.nil?
  print "PASS #{PASS} " unless PASS.nil?
  print "\n"

rescue DBI::Error, DBI::Warning => err
    p err
    exit
end

puts

DEFAULT_PAGE_LENGTH = 37 

$output     = nil
$input      = nil
$page_len   = DEFAULT_PAGE_LENGTH 
PROMPT      = "dbi => "
PROMPT_CONT = "dbi =| "
INPUT       = " >> "

SQL_KEYWORDS = %w(
  INSERT DELETE UPDATE SELECT FROM WHERE IN LIKE SET VALUES INTO
  CREATE TABLE DROP 
  COMMIT ROLLBACK
  CHAR VARCHAR VARCHAR2 INT INTEGER NUMBER FLOAT REAL LONG CLOB BLOB DECIMAL 
  DBCLOB DBBLOB
)

rd = ReadlineControl.new
rd.keywords = SQL_KEYWORDS + Conn.tables
rd.set_prompt(PROMPT)



loop {
  if $input.nil?
    line = rd.readline
  else
    line = $input.gets
    if line.nil?
      $input = nil
      line = ""
    end
  end
  line.chomp!
  next if line.empty?

  puts $file + INPUT + line unless $input.nil?

 
  begin

    if line =~ /^\\/ then

      if line =~ /^\\q(uit)?/i then
        break
      elsif line =~ /^\\h(elp)?/i then
        head = %w(Function Description)
        rows = [
          ["\\h[elp]",     "Display this help screen"],
          ["", ""],

          ["\\t[ables]",   "Display all available tables"],
          ["\\dt table",   "Describe columns of 'table'"],
          ["\\s[elect] table", "short for SELECT * FROM 'table'"],
 
          ["", ""],
          ["\\c[ommit]",   "Commits the current transaction"],
          ["\\r[ollback]", "Rolls back the current transaction"],
          ["\\a[utocommit]", "Show current autocommit mode"],
          ["\\a[utocommit] on|off", "Switch autocommit mode on/off"],
          ["", ""],

          ["\\i[nput] filename", "Read and execute lines from 'filename'"],
          ["\\o[utput]", "Disable output"],
          ["\\o[utput] filename", "Store SQL statments the user inputs into 'filename'"],
          ["", ""],

          ["\\pl n", "Set page length to 'n'"],
          ["", ""],

          ["\\q[uit]",     "Quit this program"]
        ]
          
        puts
        puts "Help: "
        #DBI::Utils::TableFormatter.ascii(head, rows)
        output_table(head, rows)
        puts
        next 
      elsif line =~ /^\\t(ables)?/i then
        head = ["Table name"]
        rows = Conn.tables.collect {|name| [name]}
          
        puts
        puts "Tables: "
        #DBI::Utils::TableFormatter.ascii(head, rows)
        output_table(head, rows)
        puts
        next 

      elsif line =~ /^\\dt/i then
        table = $'.strip
        
        head = %w(name type_name precision scale default nullable indexed primary unique)

        rows = Conn.columns(table).collect {|col| head.collect{|a| col[a]} }

        puts
        puts "Table '#{table}': "
        output_table(head, rows)
        puts
        next 

      elsif line =~ /^\\s(select)?/i then
        table = $'.strip
        line = "SELECT * FROM #{table}\n"

      elsif line =~ /^\\c(ommit)?/i then
        $output.puts line unless $output.nil?
        Conn.commit
        puts
        puts "COMMIT"
        puts
        next
      elsif line =~ /^\\r(ollback)?/i then
        $output.puts line unless $output.nil?
        Conn.rollback
        puts
        puts "ROLLBACK"
        puts
        next
      elsif line =~ /^\\a(utocommit)?(\s+(on|off)?)?/i then
        $output.puts line unless $output.nil?
        mode = $3
        if mode =~ /on/i
          Conn['AutoCommit'] = true
          puts
          puts "AUTOCOMMIT IS NOW ON"
          puts
        elsif mode =~ /off/i
          Conn['AutoCommit'] = false
          puts
          puts "AUTOCOMMIT IS NOW OFF"
          puts
        else
          puts
          if Conn['AutoCommit'] == true
            puts "AUTOCOMMIT is currently switched ON"
          elsif Conn['AutoCommit'] == false
            puts "AUTOCOMMIT is currently switched OFF"
          else
            puts "AUTOCOMMIT is in unknown state"
          end
          puts 
          
        end 
        next

      elsif line =~ /^\\i(nput)?/i then
        puts
        $file = $'.strip

        begin
        $input = File.open($file)
        rescue
          puts "Couldn't read from file #{$file}"
          puts
          next
        end
        puts "EXECUTE file #{$file}" 
        puts
        next

      elsif line =~ /^\\o(utput)?/i then
        puts
        file = $'.strip

        if file.empty?
          $output = nil
          puts "Disabled OUTPUT"
          puts
          next
        end

        begin
        $output = File.new(file, "w+")
        rescue
          puts "Couldn't set OUTPUT to file #{file}"
          puts
          next
        end
        puts "Set OUTPUT to file #{file}" 
        puts
        next

      elsif line =~ /^\\pl/i then
        puts
        $page_len = $'.strip.to_i
        $page_len = DEFAULT_PAGE_LENGTH if $page_len <= 0

        puts "New page length is #{$page_len}."
        puts
        next


      else
        puts
        puts "Unknown command!"
        puts
        next
      end
    end
    
    # else  
    $output.puts line unless $output.nil?

    # multi-line
    if line[-1].chr == "\\" then
      line.chop!
      rd.set_prompt(PROMPT_CONT)
      loop {
	if $input.nil?
	  ln = rd.readline
	else
	  ln = $input.gets
	  if ln.nil?
	    $input = nil
	    ln = ""
	  end
	end

        ln.chomp!
        next if ln.empty?

        puts $file + INPUT + ln unless $input.nil?
         
        $output.puts line unless $output.nil?

        if ln[-1].chr == "\\" then
          line += ln.chop
        else
          line += ln
          break
        end
      }
    end

    rd.set_prompt(PROMPT)

    start = ::Time.now
    stmt = Conn.execute(line)

    head = stmt.column_names
    
    # DDL, DCL
    if head.empty? 
      puts
      nr = stmt.rows
      if nr == 0
        puts "  No rows affected"
      elsif nr == 1
        puts "  1 row affected"
      else 
        puts "  #{nr} rows affected"
      end
      puts
      rd.keywords = SQL_KEYWORDS + Conn.tables
      next
    end

    rows = stmt.fetch_all
    tm = ::Time.now - start

    puts
    output_table(head, rows || [])
    print "  "
    if rows.nil?
      print "No rows in set"
    elsif rows.size == 1
      print "1 row in set"
    else
      print "#{rows.size} rows in set"
    end

    puts " (#{(tm.to_f*1000).to_i / 1000.0} sec)"
    puts

    rd.keywords = SQL_KEYWORDS + Conn.tables

  rescue DBI::Error => err
    puts
    puts err.message
    p err.backtrace if $DEBUG
    puts
  end
}


# exit the program

puts
puts "BYE"
puts

begin
  Conn.disconnect
rescue DBI::Error => err
  puts
  puts err.message
  p err.backtrace if $DEBUG
  puts
end

