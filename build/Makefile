all: ChangeLog.html doc

ChangeLog.html: ChangeLog
	./cl2html.sh

ChangeLog:
	ruby create_changelog.rb

doc:
	./create_html

clean:
	rm -f ../ChangeLog ../doc/html/ChangeLog.html ../doc/html/ToDo.html ../doc/html/DBD_SPEC.html ../doc/html/DBI_SPEC.html ../doc/html/index.html
