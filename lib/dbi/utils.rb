#
# $Id: utils.rb,v 1.1 2001/05/29 11:16:53 michael Exp $
#

module DBI
module Utils

module XMLFormatter
  def XMLFormatter.row(dbrow, output=STDOUT)
    output << "<row>\n"
    dbrow.each_with_name do |val, name|
      output << "  <#{name}>" + textconv(val) + "</#{name}>\n" 
    end
    output << "</row>\n"
  end
 
  def XMLFormatter.table(rows, rootname = "rows", output=STDOUT)
    output << '<?xml version="1.0" encoding="UTF-8" ?>'
    output << "\n<#{rootname}>\n"
    rows.each do |row|
      row(row, output)
    end
    output << "</#{rootname}>\n"
  end

  class << self
  private
  # from xmloracle.rb 
  def textconv(str)
    str = str.to_s.gsub('&', "&#38;")
    str = str.gsub('\'', "&#39;")
    str = str.gsub('\"', "&#34;")
    str = str.gsub('<', "&#60;")
    str.gsub('>', "&#62;")
  end
  end # class self
 
end # module XMLFormatter


module TableFormatter

  # TODO: add a nr-column where the number of the column is shown
  def TableFormatter.ascii(header, rows, 
    header_orient=:left, rows_orient=:left, 
    indent=2, cellspace=1, pagebreak_after=nil,
    output=STDOUT)

    # pagebreak_after n-rows (without counting header or split-lines)
    # yield block with output as param after each pagebreak

    col_lengths = (0...(header.size)).collect do |colnr|
      [
      (0...rows.size).collect { |rownr|
        (rows[rownr][colnr] || "NULL").to_s.size
      }.max,
      header[colnr].size
      ].max
    end

    indent = " " * indent

    split_line = indent + "+"
    col_lengths.each {|col| split_line << "-" * (col+cellspace*2) + "+" }

    cellspace = " " * cellspace

    output_row = proc {|row, orient|
      output << indent + "|"
      row.each_with_index {|c,i|
        output << cellspace
        str = (c || "NULL").to_s
        output << case orient
        when :left then   str.ljust(col_lengths[i])
        when :right then  str.rjust(col_lengths[i])
        when :center then str.center(col_lengths[i])
        end 
        output << cellspace
        output << "|"
      }
      output << "\n" 
    } 

    rownr = 0
 
    loop do 
      output << split_line + "\n"
      output_row[header, header_orient]    
      output << split_line + "\n"
      if pagebreak_after.nil?
        rows.each {|ar| output_row[ar, rows_orient]}
        output << split_line + "\n"
        break
      end      

      rows[rownr,pagebreak_after].each {|ar| output_row[ar, rows_orient]}
      output << split_line + "\n"
      yield output if block_given?

      rownr += pagebreak_after

      break if rownr >= rows.size
    end
    
  end



end # module TableFormatter

end # module Utils
end # module DBI


