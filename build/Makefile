all: doc ChangeLog.html

ChangeLog:
	ruby create_changelog.rb

ChangeLog.html: ChangeLog
	./cl2html.sh

doc:
	./create_html

clean:
	rm ChangeLog ChangeLog.html
