# -*- makefile-gmake -*-
#
# Makefile for mty-perl distribution
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#

default: all

.PHONY: default sync-modules install-modules sync-scripts install-scripts sync install-without-sync install info clean all

GENERATED_MAKE_INCLUDES := build/perl-version.mk build/modules.mk build/perl-scripts.mk build/deps.mk

include functions.mk

ifneq (,$(filter clean,${MAKECMDGOALS}))
SKIP_MAKE_INCLUDES := 1
endif # MAKECMDGOALS != clean

PERL_MOD_DEPS_QUIET := -quiet
ifdef V
PERL_MOD_DEPS_QUIET := 
endif # V

print_build = $(info ${SPACER}${SPACER}${1}${TAB}${2})

INSTALLED_PERL_SCRIPTS_DIR := /usr/local/bin

ifndef SKIP_MAKE_INCLUDES

# Set the following make variables related to the local Perl installation:
PERL_CONFIG_VARS := PERL_VERSION PERL_PERLPATH PERL_SITELIB PERL_SITEARCH PERL_ARCHNAME PERL_MODULE_DIRS PERL_MODULES PERL_SCRIPTS
QUERY_PERL_VER_AND_DIR := 'use Config; foreach my $$k (qw(version sitelib sitearch archname)) { print("PERL_".uc($$k)." := ".$$Config{$$k}."\t"); }'

-include build/perl-version.mk
ifeq (,${PERL_VERSION})
PERL_VERSION_OUTPUT := $(subst ${TAB},${NL},$(shell perl -e ${QUERY_PERL_VER_AND_DIR}))
$(eval ${PERL_VERSION_OUTPUT})
endif # ! PERL_VERSION

build:
	@mkdir -p build

build/perl-version.mk: ${PERLPATH} | build
	$(call print_build,(config),Running under Perl version ${PERL_VERSION} (${PERL_PERLPATH}, ${PERL_SITELIB} on ${PERL_ARCHNAME}))
	$(file >$@,${PERL_VERSION_OUTPUT})

#
# PERL_MODULES / MTY/build/modules.mk (persistent cached make variable)
#
-include build/modules.mk
ifeq (,${PERL_MODULES})
GENERATE_MODULES_LIST := 1
endif # ! PERL_MODULES

ifdef GENERATE_MODULES_LIST
PERL_MODULES := $(call find_files_recursively,MTY,*.pm)
endif # GENERATE_MODULES_LIST

PERL_MODULE_DIRS := $(sort $(patsubst %/,%,$(dir ${PERL_MODULES})))

PERL_BUNDLE_MODULES := $(addsuffix /All.pm,${PERL_MODULE_DIRS})

ifdef GENERATE_MODULES_LIST
# (We only do this at installation time now):
# PERL_MODULES += ${PERL_BUNDLE_MODULES}
endif

build/modules.mk: ${PERL_MODULE_DIRS} build/perl-version.mk | build
	$(file >$@,PERL_MODULES := ${PERL_MODULES})

build/modules.list: ${PERL_MODULE_DIRS} build/perl-version.mk | build
	$(file >$@,$(subst ${SPACE},${NL},${PERL_MODULES}))

#
# PERL_SCRIPTS / scripts/build/perl-scripts.mk (persistent cached make variable)
#
-include build/perl-scripts.mk
ifeq (,${PERL_SCRIPTS})
PERL_SCRIPTS := $(call find_scripts_handled_by_interpreter,perl,scripts/*)
endif # ! PERL_SCRIPTS

build/perl-scripts.mk: scripts build/perl-version.mk | build
	$(file >$@,PERL_SCRIPTS := ${PERL_SCRIPTS}) 

build/perl-scripts.list: scripts build/perl-version.mk | build
	$(file >$@,$(subst ${SPACE},${NL},$(notdir ${PERL_SCRIPTS})))

#
# Dependencies of scripts and Perl modules on other Perl modules
#

#
# We use build/deps.mk as a timestamp to ensure several actions
# are invoked whenever any perl modules are newer than build/deps.mk:
#
# - automatically update the set of symbols exported from each module
#   (this does not actually create any dummy timestamp file of its own)
#
# - compute the dependencies amongst the perl modules and scripts,
#   to ensure we rebuild any other targets which depend on the output
#   of our scripts
#

find_included_perl_file = $(call find_file_in_directory_list_named,${1},PERL_LIB_DIRS)
find_included_pm_file = $(find_included_perl_file)
find_included_pl_file = $(find_included_perl_file)

find_direct_deps_of_pm_file = $(find_direct_deps_of_perl_file)
find_direct_deps_of_pl_file = $(find_direct_deps_of_perl_file)

find_direct_deps_of_perl_file = $(addsuffix .pm,$(subst ::,/,$(subst ${NL}, ,$(sort $(shell grep -P -o '\buse\s*+\K[A-Z\_]\w*[\w\:]*' ${1})))))
find_direct_deps_of_perl_files = $(subst ${SPACE},${NL},$(addprefix deps[,$(subst :,]+=,$(addsuffix .pm,$(subst ::,/,$(sort $(shell grep -H -P -o '\buse\s*+\K[A-Z\_]\w*[\w\:]*' ${1})))))))

-include build/deps.mk
ifeq (,${DEPS_AVAILABLE})
DEPS_AVAILABLE := ${PERL_MODULES} ${PERL_SCRIPTS}
$(foreach m,${PERL_MODULES} ${PERL_SCRIPTS},$(eval deps[${m}] :=))
$(eval $(call find_direct_deps_of_perl_files,${PERL_MODULES} ${PERL_SCRIPTS}))
endif # ! DEPS_AVAILABLE

find_updated_modules = $(filter ${PERL_MODULES},${1})
find_updated_scripts = $(filter ${PERL_SCRIPTS},${1})

build/deps.mk: ${PERL_MODULES} ${PERL_SCRIPTS} build/modules.mk build/perl-scripts.mk build/perl-version.mk 
	$(eval UPDATED_MODULES := $(call find_updated_modules,$?))
	$(eval UPDATED_SCRIPTS := $(call find_updated_scripts,$?))
	$(if ${UPDATED_MODULES},$(call print_build,(status),$(words ${UPDATED_MODULES}) out-of-date Perl modules:${NL}$(call summarize_paths_across_lines,$(patsubst MTY/%,%,${UPDATED_MODULES}),${TAB}${TAB} - )))
	$(if ${UPDATED_SCRIPTS},$(call print_build,(status),$(words ${UPDATED_SCRIPTS}) out-of-date Perl scripts:${NL}$(call summarize_paths_across_lines,${UPDATED_SCRIPTS},${TAB}${TAB} - )))
	$(call print_build,PerlDeps,Updating dependencies for all out-of-date Perl modules and scripts)
	$(file >$@,DEPS_AVAILABLE := ${DEPS_AVAILABLE})
	$(file >>$@,$(subst ${SPACE}^,${NL}, $(foreach m,${PERL_MODULES} ${PERL_SCRIPTS},^deps[${m}] := $(filter MTY/%,${deps[${m}]}))))
	$(if ${UPDATED_MODULES},$(call print_build,Exports,Generating exports for $(words ${UPDATED_MODULES}) out-of-date Perl modules))
	@[ -n "${UPDATED_MODULES}" ] && scripts/perl-mod-deps ${PERL_MOD_DEPS_QUIET} -exports ${UPDATED_MODULES} >& build/perl-mod-deps.exports.log

endif # ! SKIP_MAKE_INCLUDES

#
# Module bundle generation (MTY::*::All):
#
define generate_module_bundle_rule
${1}/All.pm: ${1} | build
	$$(call print_build,Bundle,Updating module bundle $$@ for $$(words $$(filter ${1}/%,$${PERL_MODULES})) Perl modules)
	@scripts/perl-mod-deps ${PERL_MOD_DEPS_QUIET} -bundle=$(subst /,::,${1})::All $$(filter ${1}/%,$${PERL_MODULES}) >& build/perl-mod-deps.bundle.$(subst /,-,${1}).log
endef # generate_module_bundle_rule

$(foreach d,${PERL_MODULE_DIRS},$(eval $(call generate_module_bundle_rule,${d})))

#
# Installation and synchronization with possibly updated installed modules
#

USE_SUDO := $(shell [[ -w ${DESTDIR}/ && -w ${INSTALLED_PERL_SCRIPTS_DIR}/ ]] && echo "" || echo sudo)
DESTDIR ?= ${PERL_SITELIB}

RSYNC_OPTIONS := -aAXxuc --omit-dir-times --out-format='%n'
RSYNC_DRY_RUN_OPTIONS := ${RSYNC_OPTIONS} --dry-run

sync-modules: ${PERL_MODULES}
	$(call print_build,SYNC,Synchronizing source tree with any newer Perl modules in ${PERL_SITELIB})
	@cp -avu --parents -t ./ $(addprefix ${PERL_SITELIB}/,${PERL_MODULES})

install-modules: ${PERL_MODULES} ${PERL_BUNDLE_MODULES}
	$(call print_build,INSTALL,Installing $(words ${PERL_MODULES}) Perl modules into ${DESTDIR})
	@${USE_SUDO} cp -avu --parents -t ${DESTDIR}/ ${PERL_MODULES} ${PERL_BUNDLE_MODULES}

test-install-modules: ${PERL_MODULES} ${PERL_BUNDLE_MODULES} build/modules.list
	$(call print_build,TESTinst,(dry run) Installing $(words ${PERL_MODULES}) Perl modules into ${DESTDIR})
	@rsync ${RSYNC_DRY_RUN_OPTIONS} MTY/ ${DESTDIR}/MTY/ | grep -v -P '/\Z'

sync-scripts: ${PERL_SCRIPTS}
	$(call print_build,SYNC,Synchronizing source tree with any newer Perl scripts in ${INSTALLED_PERL_SCRIPTS_DIR})
	@cp -avu -t scripts/ $(addprefix ${INSTALLED_PERL_SCRIPTS_DIR}/,$(notdir ${PERL_SCRIPTS}))

install-scripts: ${PERL_SCRIPTS} 
	$(call print_build,INSTALL,Installing $(words ${PERL_SCRIPTS}) Perl scripts into ${INSTALLED_PERL_SCRIPTS_DIR})
	@${USE_SUDO} cp -avu -t ${INSTALLED_PERL_SCRIPTS_DIR}/ ${PERL_SCRIPTS}

test-install-scripts: ${PERL_SCRIPTS} build/perl-scripts.list
	$(call print_build,TESTinst,(dry-run) Installing $(words ${PERL_SCRIPTS}) Perl scripts into ${INSTALLED_PERL_SCRIPTS_DIR})
	@rsync ${RSYNC_DRY_RUN_OPTIONS} scripts/ ${INSTALLED_PERL_SCRIPTS_DIR}/ | grep -v -P '/\Z'

sync: sync-modules sync-scripts
install-without-sync: install-modules install-scripts
install: install-modules install-scripts

#
# Miscellaneous targets:
#

info:
	$(foreach v,${PERL_CONFIG_VARS},$(info ${v} := ${${v}}))

#
# Just clean up the log files and temporaries, 
# but still leave the auto-generated module bundles
# as well as the build/modules.{mk,list}, build/deps.mk, 
# build/perl-scripts.{mk,list} files to help speed up
# builds by new users:
#
distclean:
	$(call print_build,DISTCLEAN,Cleaning and removing temporary files prior to distribution)
	@rm -f -v build/perl-version.mk build/perl-mod-deps*.log

clean:
	$(call print_build,CLEAN,Cleaning and removing all generated files)
	@rm -r -f -v build/ $(addsuffix /All.pm,${PERL_MODULE_DIRS}) $(wildcard MTY/*/All.pm) $(wildcard MTY/All.pm)

all: $(addsuffix /All.pm,${PERL_MODULE_DIRS}) build/modules.list build/perl-scripts.list 