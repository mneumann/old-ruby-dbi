#!/usr/bin/env ruby -I ..

require "dbi"

class ReadlineControl
  
  def initialize
    begin
      require "readline"
      @readline = true
    ensure LoadError
      @readline = false
    end
      
    @keywords = []
    set_prompt
    if @readline
      Readline.completion_proc = proc {|str| complete(str) }
    end
  end

  def add_keywords(arr)
    @keywords += arr
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
      readline
    end
  end

end

if ARGV.size < 1 or ARGV.size > 3
  puts
  puts "USAGE: #{$0} driver_url [user [password] ]"
  puts

  puts "Available driver and datasources:"
  puts
  for driver in DBI.available_drivers do
    puts driver + ":"
    for datasource in DBI.data_sources(driver)
      puts "  " + datasource
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


PROMPT      = "dbi => "
PROMPT_CONT = "dbi =| "

SQL_KEYWORDS = %w(
  INSERT DELETE UPDATE SELECT FROM WHERE IN LIKE SET VALUES INTO
  CREATE TABLE DROP 
  COMMIT ROLLBACK
  CHAR VARCHAR VARCHAR2 INT INTEGER NUMBER FLOAT REAL LONG CLOB BLOB DECIMAL 
  DBCLOB DBBLOB
)

rd = ReadlineControl.new
rd.add_keywords SQL_KEYWORDS
rd.set_prompt(PROMPT)



loop {
  line = rd.readline
  line.chomp!
  next if line.empty?
 
  begin

    if line =~ /^\\/ then

      if line =~ /^\\q(uit)?/i then
        puts
        puts "BYE"
        puts
        Conn.disconnect
        break 
      elsif line =~ /^\\h(elp)?/i then
        head = %w(Function Description)
        rows = [
          ["\\h[elp]",   "Display this help screen"],
          ["\\t[ables]", "Display all available tables"],
          ["\\q[uit]",   "Quit this program"]
        ]
          
        puts
        puts "Help: "
        DBI::Utils::TableFormatter.ascii(head, rows)
        puts
        next 
      elsif line =~ /^\\t(ables)?/i then
        head = ["Table name"]
        rows = Conn.tables.collect {|name| [name]}
          
        puts
        puts "Tables: "
        DBI::Utils::TableFormatter.ascii(head, rows)
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

  
    # multi-line
    if line[-1].chr == "\\" then
      line.chop!
      rd.set_prompt(PROMPT_CONT)
      loop {
        ln = rd.readline
        line.chomp!
        next if line.empty?
         
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
      next
    end

    rows = stmt.fetch_all
    tm = ::Time.now - start

    puts
    DBI::Utils::TableFormatter.ascii(head, rows || [])
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

  rescue DBI::Error => err
    puts
    puts err.message
    puts
  end
}



