#!/usr/local/bin/ruby
# Ruby Unit Tests

require 'runit/testcase'
require 'runit/cui/testrunner'

require "dbi/sql"

$last_suite = RUNIT::TestSuite.new

# ====================================================================
class TestSqlBind < RUNIT::TestCase

  include DBI::SQL::BasicQuote
  include DBI::SQL::BasicBind

  def test_one
    assert_equal "10", bind(self, "?", [10])
    assert_equal "'hi'", bind(self, "?", ["hi"])
    assert_equal "I 'don''t' know", bind(self, "I ? know", ["don't"])
  end

  def test_many
    assert_equal "WHERE age=12 AND name='Jim'",
      bind(self, "WHERE age=? AND name=?", [12, 'Jim'])
  end

  def test_too_many
    assert_exception (RuntimeError) {
      bind(self, "age=?", [10, 11])
    }
  end

  def test_too_few
    assert_exception (RuntimeError) {
      bind(self, "age in (?, ?, ?)", [10, 11])
    }
  end

  def test_embedded_questions
    assert_equal "10 ? 11", bind(self, "? ?? ?", [10, 11])
    assert_equal "????", bind(self, "????????", [])
  end
end

$last_suite.add_test (TestSqlBind.suite)




######################################################################

if __FILE__ == $0 then
  RUNIT::CUI::TestRunner.quiet_mode = true
  RUNIT::CUI::TestRunner.run ($last_suite)
end
