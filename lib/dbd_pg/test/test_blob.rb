#$Id: test_blob.rb,v 1.1 2001/11/12 19:40:55 michael Exp $

require "dbi"

DATA = "this is my new binary object"

DBI.connect("dbi:Pg:michael", "michael", "michael") do |dbh|
  begin
    dbh.do("DROP TABLE blob_test") 
  rescue; end

  dbh.do("CREATE TABLE blob_test (name VARCHAR(30), data OID)")

  dbh.do("INSERT INTO blob_test (name, data) VALUES (?,?)",
    "test", DBI::Binary.new(DATA))

  oid = dbh.select_one("SELECT data FROM blob_test")['data']
  if dbh.func(:blob_read, oid) != DATA
    raise "Test failed"
  end

end

puts "Test succeeded"

