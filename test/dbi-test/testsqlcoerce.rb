#!/usr/bin/env ruby
# Ruby Unit Tests

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'require_dispatch'
require "dbi"
require "sql"

$last_suite = RUNIT::TestSuite.new

# ====================================================================
class TestSqlCoerce < RUNIT::TestCase

  def setup
    @coerce = DBI::SQL::BasicQuote::Coerce.new
  end
 
  def test_int
    assert_equal 78787, @coerce.as_int("78787")
    assert_equal 78787, @coerce.as_int("     78787    \n\n")
    assert_equal -8,    @coerce.as_int("-8")

    assert_equal nil,   @coerce.as_int("")
    assert_equal 0,     @coerce.as_int("j133")

    assert_equal nil,   @coerce.as_int(nil) 
  end


  def test_float
    assert_equal 3.1415, @coerce.as_float("3.1415")
    assert_equal 3.1415, @coerce.as_float("   3.1415  \n")
    assert_equal -8.0,   @coerce.as_float("-8")

    assert_equal 0.0,    @coerce.as_int("j133.0")

    assert_equal nil,    @coerce.as_float(nil)
  end

  def test_str
    assert_equal nil,    @coerce.as_str(nil) 
    assert_equal "test", @coerce.as_str("test") 

    a = [1,2,3]
    assert_equal a.id,   @coerce.as_str(a).id 
  end

  def test_bool
    assert_equal true,  @coerce.as_bool("t")
    assert_equal false, @coerce.as_bool("f")

    assert_equal nil,   @coerce.as_bool(nil)
    assert_equal nil,   @coerce.as_bool("x")
    assert_equal nil,   @coerce.as_bool("333")
    assert_equal nil,   @coerce.as_bool(333)
  end

  def test_time
    assert_equal nil, @coerce.as_time(nil)
  end

  def test_timestamp
    assert_equal nil, @coerce.as_timestamp(nil)
    assert_equal nil, @coerce.as_timestamp("")
    assert_equal DBI::Timestamp.new(2003, 1, 2, 12, 34, 56), @coerce.as_timestamp("2003-01-02 12:34:56")

    assert_equal Time.gm(2003, 1, 2, 12, 34, 56), @coerce.as_timestamp("2003-01-02 12:34:56+00").to_time.getutc
    assert_equal Time.gm(2003, 1, 2, 11, 34, 56), @coerce.as_timestamp("2003-01-02 12:34:56+01").to_time.getutc
    assert_equal Time.gm(2003, 1, 2, 14, 34, 56), @coerce.as_timestamp("2003-01-02 12:34:56-02").to_time.getutc

    assert_equal Time.gm(2003, 1, 2, 10, 34, 56), @coerce.as_timestamp("2003-01-02 12:34:56+02:00").to_time.getutc

    assert_equal(nil, DBI::Timestamp.new == nil)
    assert_equal(false, DBI::Timestamp.new == DBI::Timestamp.new(2004))
    assert_equal(true, DBI::Timestamp.new(2004, 04, 04) == DBI::Timestamp.new(2004, 04, 04))
  end

  def test_date
    assert_equal nil, @coerce.as_date(nil)
  end

end

$last_suite.add_test(TestSqlCoerce.suite)


######################################################################

if __FILE__ == $0 then
  RUNIT::CUI::TestRunner.quiet_mode = false
  RUNIT::CUI::TestRunner.run($last_suite)
end
