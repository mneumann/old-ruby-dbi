all: ChangeLog.html

ChangeLog:
	ruby create_changelog.rb

ChangeLog.html: ChangeLog
	./cl2html.sh

clean:
	rm ChangeLog ChangeLog.html
