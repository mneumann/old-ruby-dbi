#!/usr/bin/env ruby
# -*- ruby -*-

# $Id: row.rb,v 1.1 2001/05/29 11:16:53 michael Exp $

module DBI

  # ==================================================================
  class Row
    
    # A row of values from a database.
    
    # Values can be accessed ...
    #   - by index:           row[index]
    #   - or by field name:   row.field('field_name')
    
    include Enumerable
    
    def initialize(names, values)
      # Initialize a new row with values from 'values' and field names
      # from 'names'.
      @names = make_hash(names)
      @orig_names = names
      @values = values
    end
    
    # Queries ----------------------------------------------------------
    
    def size
      # Number of elements in the row.
      @values.size
    end
    alias :length :size
    
    def by_index(index)
      # Value at 'index'.
      @values[index]
    end
    
    def by_field(field_name)
      # Value of the field named 'field_name'.
      @values[@names[field_name]]
    rescue TypeError
      nil
    end
    
    def [](key)
      case key
      when String
	by_field(key)
      else
	by_index(key)
      end
    end
    
    def each(&block)
      # Iterate over each value in a row.
      @values.each &block
    end

    def each_with_name
      @values.each_with_index {|v, i|
        yield v, @orig_names[i] 
      }
    end

    # Modifiers --------------------------------------------------------
    
    def set_values(new_values)
      # Accept an array of new values
      @values = new_values
    end
    
    # Cloning and Conversion -------------------------------------------
    
    def clone_with(new_values)
      # Create a new row with 'new_values', reusing the field name hash. 
      Row.new(@names, new_values)
    end
    
    def to_a
      # Convert to an array
      @values
    end
    
    private # ----------------------------------------------------------
    
    def make_hash(names)
      # Return a hash mapping field names to array indicies.
      result = Hash.new
      names.each_with_index do |name, index|
	result[name] = index
      end
      result
    end
  end
    
end
