
require 'dbi'

dbh = DBI.connect("DBI:mysql:#{ARGV[0]}", ARGV[1], ARGV[2])
dbh.do('CREATE TABLE dbi_test1 (SongID INT, SongName VARCHAR(255))')

puts "inserting..."
execTime=0
1.upto(20) do |i|
 mySongName = dbh.quote("Song #{i}")
 dbh.do("INSERT INTO dbi_test1 (SongID, SongName) VALUES (#{i}, #{mySongName})")
 execTime+=dbh.lastDoDur
end 
puts "Loop Execution-time was #{execTime} seconds."

puts "selecting..."
sth=dbh.prepare('SELECT * FROM dbi_test1')
sth.execute
puts "Execution-time was #{sth.lastExecDur} seconds."

while dat=sth.fetchrow_hashref do
 puts dat.inspect
end

puts "deleting..."
dbh.do('DELETE FROM dbi_test1 WHERE SongID > 10')
puts "Execution-time was #{dbh.lastDoDur} seconds."

dbh.do('DROP TABLE dbi_test1')
dbh.disconnect

