require 'test/unit'
require 'dbi'

class TC_SQLite < Test::Unit::TestCase
  def setup
    @dbh = DBI.connect("dbi:SQLite:testdb.sqlite")
  end
  
  def teardown
    @dbh.disconnect
  end
  
  def test_column_names
    sth = @dbh.execute("SELECT bar, baz AS test FROM foo")
    assert_equal("foo.bar", sth.column_names[0])
    assert_equal("test", sth.column_names[1])
    sth.finish
  end

  def test_fetch_array
    sth = @dbh.execute("SELECT bar, baz AS test FROM foo")
    assert_equal([1, "asd"], sth.fetch_array)
    assert_equal([2, "asd"], sth.fetch_array)
    assert_equal([3, nil], sth.fetch_array)
    assert_equal(nil, sth.fetch_array)
    #assert_equal(nil, sth.fetch_array)
    sth.finish
  end

  def test_fetch_hash
    sth = @dbh.execute("SELECT bar, baz AS test FROM foo")
    assert_equal({"foo.bar" => 1, "test" => "asd"}, sth.fetch_hash)
    assert_equal({"foo.bar" => 2, "test" => "asd"}, sth.fetch_hash)
    assert_equal({"foo.bar" => 3, "test" => nil}, sth.fetch_hash)
    assert_equal(nil, sth.fetch_hash)
    #assert_equal(nil, sth.fetch_hash)
    sth.finish
  end
  
  def test_placeholders
    assert_raises(RuntimeError) {
      @dbh.execute("SELECT ?", nil, nil).finish
    }

    assert_raises(RuntimeError) {
      @dbh.execute("SELECT ?, ?", nil).finish
    }
    
    sth = @dbh.execute("SELECT ?, ?, ?, ?", "test", -22, 0.5, nil)
    assert_equal(["test", "-22", "0.5", nil], sth.fetch_array)
    sth.finish

    sth = @dbh.prepare("SELECT ?, ?")
    assert_raises(DBI::InterfaceError) {
      sth.fetch
    }
    sth.execute(1, 2)
    assert_equal(["1", "2"], sth.fetch)
    sth.finish
  end

  def test_fetch_scroll
    sth = @dbh.execute("SELECT 1")
    assert_raises(DBI::NotImplementedError) {
      sth.fetch_scroll(nil)
    }
    sth.finish
  end

  def test_syntax_error
    assert_raises(DBI::DatabaseError) {
      @dbh.execute("XYZ").finish
    }
  end

  def test_insert_update
    @dbh.do("DROP TABLE sequences") rescue nil
    
    assert_equal(0, @dbh.do("create table sequences (name varchar(30), val integer)"))
    
    sth = @dbh.execute("insert into sequences (name,val) values ('test',1000)")
    assert_equal(1, sth.rows)
    assert_equal(nil, sth.fetch)
    sth.finish
    
    sth = @dbh.prepare("update sequences set val=? where val=? and name=?")
    sth.execute(1001,1000,"test")
    assert_equal(1, sth.rows)
    sth.finish

    assert_equal(1, @dbh.do("UPDATE sequences SET val=?", 1))
  end

  def test_null_char
    assert_raises(DBI::DatabaseError) {
      @dbh.do("SELECT ?", "\0")
    }
    assert_raises(DBI::DatabaseError) {
      @dbh.do("SELECT '\0'")
    }
  end

  def test_escape
    teststring = "\n;\\'"
    sth = @dbh.execute("SELECT ?", teststring)
    assert_equal([teststring], sth.fetch)
    sth.finish
  end

  def test_multiple_statements
    assert_raises(DBI::DatabaseError) {
      @dbh.execute("SELECT 1; SELECT 2; SELECT 3").finish
    }
  end
  
end
