require 'TC_Common'

class TC_SQLite < Test::Unit::TestCase
  include TC_Common

  def connect
    @dbh = DBI.connect("dbi:SQLite:testdb.sqlite")
  end
  
  def test_full_column_names
    @dbh['sqlite_full_column_names'] = true

    sth = @dbh.execute("SELECT bar, baz AS test FROM foo")
    assert_equal({"foo.bar" => 1, "test" => "asd"}, sth.fetch_hash)
    assert_equal({"foo.bar" => 2, "test" => "asd"}, sth.fetch_hash)
    assert_equal({"foo.bar" => 3, "test" => nil}, sth.fetch_hash)
    assert_equal(nil, sth.fetch_hash)
    #assert_equal(nil, sth.fetch_hash)
    sth.finish

    @dbh['sqlite_full_column_names'] = false
  end
  
  def test_fetch_scroll
    sth = @dbh.execute("SELECT 1")
    assert_raises(DBI::NotImplementedError) {
      sth.fetch_scroll(nil)
    }
    sth.finish
  end
  
end

