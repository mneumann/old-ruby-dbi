#!/usr/local/bin/ruby
# Ruby Unit Tests

require 'runit/testcase'
require 'runit/cui/testrunner'

require '../row'

$last_suite = RUNIT::TestSuite.new

# ====================================================================
class TestDbRow < RUNIT::TestCase

  def test_create
    row = make_row
    assert_not_nil row
  end

  def test_size
    row = make_row
    assert_equal 3, row.length 
    assert_equal 3, row.size
  end

  def test_by_index
    row = make_row
    assert_equal "Jim", row.by_index(0)
    assert_equal "Weirich", row.by_index(1)
    assert_equal 45, row.by_index(2)
    assert_nil row.by_index(3)
  end

  def test_by_field
    row = make_row
    assert_equal "Jim", row.by_field('first')
    assert_equal "Weirich", row.by_field('last')
    assert_equal 45, row.by_field('age')
    assert_equal nil, row.by_field('unknown')
  end

  def test_indexing
    row = make_row
    assert_equal "Jim", row[0]
    assert_equal "Jim", row['first']
    assert_equal "Weirich", row[1]
    assert_equal "Weirich", row['last']
    assert_equal 45, row[2]
    assert_equal 45, row['age']
    assert_equal nil, row['unknown']
  end

  def test_iteration
    row = make_row
    expect = ["Jim", "Weirich", 45]
    row.each { |value|
      assert_equal expect.shift, value
    }
    assert_equal [], expect
    row.collect { |value| "Field=#{value}" }
  end

  def test_redefining_values
    row = make_row
    row.set_values(["John", "Doe", 23])
    assert_equal "John", row.by_index(0)
    assert_equal "Doe", row.by_index(1)
    assert_equal 23, row.by_index(2)
  end

  def test_clone_with
    row = make_row
    another_row = row.clone_with(["Jane", "Smith", 33])
    assert_equal "Jane", another_row.by_index(0)
    assert_equal "Smith", another_row.by_index(1)
    assert_equal 33, another_row.by_index(2)
    assert row != another_row
  end

  def test_to_array
    assert_equal ['Jim', 'Weirich', 45], make_row.to_a
  end

  private

  def make_row
    names  = %w(first last age)
    values = ['Jim', 'Weirich', 45]
    DBI::Row.new(names, values)
  end

end

$last_suite.add_test (TestDbRow.suite)


# --------------------------------------------------------------------

if __FILE__ == $0 then
  RUNIT::CUI::TestRunner.quiet_mode = true
  RUNIT::CUI::TestRunner.run ($last_suite)
end
