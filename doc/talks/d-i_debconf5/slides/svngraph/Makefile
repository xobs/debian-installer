all: plot.png

clean:
	rm -f plot.png log commits committers
	
log: svndir
	svn log $(shell cat svndir) > log

commits: log svncommits
	./svncommits log > commits

committers: log svncommitters
	./svncommitters log > committers

plot.png: commits committers plotdata
	./plotdata > plot.png
