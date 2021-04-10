# This file represents the workhorse of your website, invoked by running `make`.
# It manages rendering your source material into a filesystem structure suitable for publishing.
# It provides stock commands for "publishing" by way of pushing to a remote, you are free to customize this.
#
# Currently this build automation depends on availability of the following command-line scripts:
#
#  * markdown_py
#  * sassc
#
# Choice of Markdown renderer can be configured below.

# Change this if needed, e.g. if separating your source from final result is desired.
ORIGIN=.
DESTINATION=.
PRODUCER=markdown_py
FLAGS=-e utf-8 -o html

# Recursive wildcard utility.
rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

SOURCES := $(call rwildcard,$(ORIGIN),*.md)
TARGETS := $(patsubst $(ORIGIN)/%.md, $(DESTINATION)/%.html, $(SOURCES))
STYLES := $(call rwildcard,$(ORIGIN)/scss,*.scss) $(call rwildcard,$(ORIGIN)/scss,*.sass)

.PHONY: all clean help deploy stage


# Project Meta-Automation

all: $(DESTINATION)/style.css $(TARGETS)  ## Attempt to build all out-of-date HTML files and styles from their sources.

styles: $(DESTINATION)/style.css  ## Recompile site styles.

clean:
	rm -f $(TARGETS) $(DESTINATION)/style.css

help:  ## Show this help message and exit.
	@echo "Usage: make <\033[4mtarget\033[0m|\033[4mcommand\033[0m>"
	@echo "A target may be any valid destination HTML file name, a command is one of:\n\033[36m\033[0m"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "\033[1;36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST) | sort

watch:  ## Watch the filesystem for changes and automatically rebuild.
	find $(ORIGIN) -name \*.md -or -name *.scss -or -name \*.sass | \
		entr -c time make


# Local Testing

serve: all  ## Start an HTTP server serving the current directory.
	python3 -m http.server


# Deployment Automation

deploy:  ## Deploy the "master" branch to a remote named "production".
	git push production master:master

stage:  ## Deploy the current branch as the master branch of a remote named "staging".
	git push staging $(shell git rev-parse --abbrev-ref HEAD):master


# SASS Compilation

$(DESTINATION)/style.css: $(STYLES)
	sassc -t compact -m $(ORIGIN)/scss/style.scss $(DESTINATION)/style.css


# Markdown Compilation

NORMAL = \e[0m
BOLD = \e[1m
GREEN = \e[32m
CEOL = \e[K

YEAR = $(date +%Y)
export YEAR

MAKE_ENV := $(shell echo '$(.VARIABLES)' | awk -v RS=' ' '/^[a-zA-Z0-9]+$$/')
SHELL_EXPORT := $(foreach v,$(MAKE_ENV),$(v)='$($(v))')

test:
	@$(SHELL_EXPORT) /bin/echo "\${YEAR}"

# These form generic rules for producing one file type from the invocation of a command against another.
$(DESTINATION)/%.html: $(ORIGIN)/%.md Makefile _prefix.html _suffix.html  ## Produce an HTML file from a Markdown one.
	@printf "$(BOLD)$<$(NORMAL)  Constructing directory tree...$(CEOL)"
	@mkdir -p $(@D)
	@printf "\r$(BOLD)$<$(NORMAL)  HTML boilerplate...$(CEOL)"
	@echo "<!DOCTYPE html>" > $@
	
	@#echo
	@#echo JQ $(cat $$<.json | jq .lang)
	@#[ -e "$<.json" ] && [ "$$(cat $$<.json | jq .lang)" != "null" ] && echo "<html lang=$$(cat $$<.json | jq .lang)>" >> $@ || true
	@echo "<title>My Awesome Blog</title>" >> $@  # TODO: Rudimentary metadata extraction.
	
	@echo "<meta charset=utf-8>" >> $@
	@echo "<meta name=viewport content=\"width=device-width,initial-scale=1\">" >> $@
	@echo "<link rel=stylesheet href=/style.css>" >> $@
	@printf "\r$(BOLD)$<$(NORMAL)  Applying prefix...$(CEOL)"
	@cat _prefix.html | envsubst >> $@
	@printf "\r$(BOLD)$<$(NORMAL)  Rendering content...$(CEOL)"
	@$(PRODUCER) < $< | envsubst >> $@
	@printf "\r$(BOLD)$<$(NORMAL)  Applying suffix...$(CEOL)"
	@cat _suffix.html | envsubst >> $@
	@printf "\r$(GREEN)$(BOLD)$@$(NORMAL)$(CEOL)\n"
