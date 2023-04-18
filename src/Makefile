# leave these lines alone
.SUFFIXES: .erl .beam

.erl.beam: 
	erlc -W $<

ERL = erl -boot start_clean 

# Here's a list of the erlang modules you want compiling
# If the modules don't fit onto one line add a \ character 
# to the end of the line and continue on the next line

# Edit the lines below
MODS = ambient \
	car \
	gui \
	main \
	render \
	wellknown

# The first target in any makefile is the default target.
# If you just type "make" then "make all" is assumed (because
#   "all" is the first target in this makefile)

all: compile

compile: ${MODS:%=%.beam} 

## run an application from the makefile

launch: all 
	${ERL}  -s main launch 

# remove all the code

clean: 
	rm -rf *.beam erl_crash.dump