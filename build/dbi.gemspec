require 'rubygems'
require 'lib/dbi/version'

spec = Gem::Specification.new do |s|
  s.name = 'dbi'
  s.version = DBI::VERSION
  s.summary = "DataBase Indepentent API"
  s.description = <<-EOF
    Ruby/DBI is a database independent interface for accessing databases,
    similar to Perl's DBI.
  EOF

  s.files = (['LICENSE', 'README'] +
             Dir['contrib/**/*'] + 
             Dir['doc/**/*'] +
             Dir['examples/**/*'] +
             Dir['lib/**/*'] +
             Dir['test/**/*']).
             delete_if {|item| item.include?(".svn") }

  s.require_path = 'lib'
  s.autorequire = 'dbi'

  s.author = "Michael Neumann"
  s.email = "mneumann@ntecs.de"
  s.homepage = "ruby-dbi.rubyforge.org"
  s.rubyforge_project = "ruby-dbi"
end
