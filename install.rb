require "rbconfig"
require "ftools"

dst = Config::CONFIG["sitelibdir"]

File.mkpath(dst, true)
File.mkpath(File.join(dst, "dbi"), true)

Dir.chdir('lib') do
  Dir['**/*.rb'].each do |file|
    File.install(file, File.join(dst, file), 0644, true)
  end
end
