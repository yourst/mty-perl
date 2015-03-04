# -*- makefile-gmake -*-
#
# Makefile for mty-perl distribution
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#

PROJECT := mty-perl

default: all

.PHONY: default sync-modules install-modules sync-scripts install-scripts sync install-without-sync install info clean commit push all
.SILENT:

GENERATED_MAKE_INCLUDES := build/perl-config.mk build/modules.mk build/perl-scripts.mk build/deps.mk build/extdeps.mk

include scripts/functions.mk

#
# Ensure all of our scripts we need for the build process
# are actually in the PATH exported to child processes when
# Makefile recipes are executed. Also ensure the PERLLIB 
# variable includes our current project directory:
#

SOURCEDIR := $(realpath ${CURDIR})
BUILDDIR := ${SOURCEDIR}/build

PATH := $(call prepend_if_missing,${SOURCEDIR}/scripts:,${PATH})
PERLLIB := $(call prepend_if_missing,${SOURCEDIR}:,${PERLLIB})
PERL5LIB := $(call prepend_if_missing,${SOURCEDIR}:,${PERL5LIB})

#
# Set important make control variables:
#
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

#----------------------------------------------------------------------------+
# Determine the current Perl version and its standard library directories,   |
# then cache these details in build/perl-config.mk for future builds.        |
#----------------------------------------------------------------------------+

build:
	@mkdir -p ${SOURCEDIR}/build

PERL_CONFIG_MK := build/perl-config.mk
PERL_CONFIG_VARS := VERSION ARCHNAME PERLPATH SITELIB SITEARCH 
query-perl-config: ${PERL_CONFIG_MK}
${PERL_CONFIG_MK}: ${perl_perlpath} Makefile | build
	$(call print_build,(config),Querying and caching current Perl configuration details...)
	scripts/query-perl-config ${PERL_CONFIG_VARS} > ${PERL_CONFIG_MK} || \
		{ echo 'Cannot query Perl configuration - is Perl installed?'; false; }	

-include ${PERL_CONFIG_MK}

#----------------------------------------------------------------------------+
# Check that the machine on which we're compiling this actually has all      |
# of the aforementioned required external dependencies properly installed:   |
# (This is only done the first time make is run from a given source tree).   |
#----------------------------------------------------------------------------+

EXTDEPS_REQUIRED_MK := scripts/extdeps-required.mk
-include ${EXTDEPS_REQUIRED_MK}

EXTDEPS_CHECKED_MK := build/extdeps-checked.mk
check-ext-deps: ${EXTDEPS_CHECKED_MK}
${EXTDEPS_CHECKED_MK}: ${EXTDEPS_REQUIRED_MK} ${PERL_CONFIG_MK} scripts/check-ext-deps ${perl_perlpath} | build
	$(call print_build,(config),Checking availability and versions of required external Perl modules...)
	scripts/check-ext-deps ${EXTERNAL_PERL_PACKAGE_DEPS} > ${EXTDEPS_CHECKED_MK}

#	$(if $(filter 1,${ALL_EXT_PERL_PACKAGE_DEPS_SATISFIED}),,$(info ${missing_or_outdated_deps_warning})$(error (Aborting make)))

-include ${EXTDEPS_CHECKED_MK}

#
# PERL_MODULES / MTY/build/modules.mk (persistent cached make variable)
#

-include build/modules.mk

ifeq (,${PERL_MODULES})
PERL_MODULES := $(call find_files_recursively,MTY,*.pm)
endif # ! PERL_MODULES

PERL_MODULE_DIRS := $(sort $(patsubst %/,%,$(dir ${PERL_MODULES})))

SKIP_BUNDLE_FOR := MTY/ListDeps MTY/PerlModDeps MTY/MakeAnalyzer MTY/System
PERL_MODULE_BUNDLE_DIRS := $(filter-out ${SKIP_BUNDLE_FOR},${PERL_MODULE_DIRS})
# PERL_MODULE_BUNDLES := $(addsuffix .pm,${PERL_MODULE_BUNDLE_DIRS})
PERL_MODULE_BUNDLES := 

build/modules.mk build/modules.list: ${PERL_MODULE_DIRS} ${EXTDEPS_CHECKED_MK} | build
	$(call print_build,(prep),Finding all Perl modules (*.pm) to create lists in build/modules.mk and build/modules.list)
	$(file >build/modules.mk,PERL_MODULES := ${PERL_MODULES})
	$(file >build/modules.list,$(subst ${SPACE},${NL},${PERL_MODULES}))

#
# PERL_SCRIPTS / scripts/build/perl-scripts.mk (persistent cached make variable)
#
-include build/perl-scripts.mk

ifeq (,${PERL_SCRIPTS})
PERL_SCRIPTS := $(call find_scripts_handled_by_interpreter,perl,scripts/*)
endif # ! PERL_SCRIPTS

build/perl-scripts.mk build/perl-scripts.list: scripts ${EXTDEPS_CHECKED_MK} | build
	$(call print_build,(prep),Finding all Perl scripts in scripts/ to create lists in build/perl-scripts.mk and build/perl-scripts.list)
	$(file >build/perl-scripts.mk,PERL_SCRIPTS := ${PERL_SCRIPTS}) 
	$(file >build/perl-scripts.list,$(subst ${SPACE},${NL},$(notdir ${PERL_SCRIPTS})))

#----------------------------------------------------------------------------+
# Determine which external Perl packages and modules we actually require:    |
# Note that extdeps-required.mk is *NOT* automatically regenerated every     |
# time the source code is altered to add or remove imported packages,        |
# since that would be a waste of time, given how rarely these dependencies   |
# genuinely change. Therefore, 'make extdeps-required' must be run manually. |
#----------------------------------------------------------------------------+

LSDEPS_EXTDEPS_ARGS := -symbolic -external -one-per-line -raw ${PERL_SCRIPTS} ${PERL_MODULES} 2>/dev/null | sort -u

define extdeps_mk_contents
$(info Executing: lsdeps -sysdeps ${LSDEPS_EXTDEPS_ARGS})
$(info Executing: lsdeps -coredeps ${LSDEPS_EXTDEPS_ARGS})
EXTERNAL_PERL_PACKAGE_DEPS := $(shell lsdeps -sysdeps ${LSDEPS_EXTDEPS_ARGS})
PERL_CORE_PACKAGE_DEPS := $(shell lsdeps -coredeps ${LSDEPS_EXTDEPS_ARGS})
ALL_REQUIRED_EXTERNAL_PERL_PACKAGES = ${EXTERNAL_PERL_PACKAGE_DEPS} ${PERL_CORE_PACKAGE_DEPS}
PERL_VERSION_REQUIRED  := ${PERL_VERSION}
endef # extdeps_mk_contents

EXTDEPS_REQUIRED_MK := scripts/extdeps-required.mk
extdeps-required: ${EXTDEPS_REQUIRED_MK}

${EXTDEPS_REQUIRED_MK}: ${perl_perlpath} scripts/lsdeps $(wildcard MTY/ListDeps/*.pm) | build
	$(file >$@,${extdeps_mk_contents})
	$(eval include ${EXTDEPS_REQUIRED_MK})
	$(info )
	$(info This project (${PROJECT}) depends on $(words ${EXTERNAL_PERL_PACKAGE_DEPS}) separately distributed Perl packages:)
	$(info )
	$(shell ${SCRIPT_DIR}/perlwhich -p -v -f ${EXTERNAL_PERL_PACKAGE_DEPS} 1>&2)
	$(info )
	$(info This project also requires the following $(words ${PERL_CORE_PACKAGE_DEPS}) packages)
	$(info from the core Perl version ${PERL_VERSION} distribution itself:)
	$(info )
	$(shell ${SCRIPT_DIR}/perlwhich -p -v -f ${EXTERNAL_PERL_PACKAGE_DEPS} 1>&2)
	$(info )
	$(shell ${SCRIPT_DIR}/perlwhich -p -v -f ${PERL_CORE_PACKAGE_DEPS} 1>&2)
	$(info )
	$(info Perl version ${PERL_VERSION} is also required.)
	$(info )

ifndef EXTERNAL_PERL_PACKAGE_DEPS
-include ${EXTDEPS_REQUIRED_MK}
endif

#ifdef EXTERNAL_PERL_PACKAGE_DEPS
#$(info extdeps => $(shell perlwhich -missing-only ${EXTERNAL_PERL_PACKAGE_DEPS}))
#endif 

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

build/deps.mk: ${PERL_MODULES} ${PERL_SCRIPTS} build/modules.mk build/perl-scripts.mk ${PERL_CONFIG_MK} 
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
# Module bundle generation (MTY::*):
#
define generate_module_bundle_rule
${1}.pm: ${1}/ | build
	$$(call print_build,Bundle,Updating module bundle $$@ for $$(words $$(filter ${1}/%,$${PERL_MODULES})) Perl modules)
	@scripts/perl-mod-deps -bundle=$(subst /,::,${1}) $$(filter ${1}/%,$${PERL_MODULES}) >& build/perl-mod-deps.bundle.$(subst /,-,${1}).log
endef # generate_module_bundle_rule

$(foreach d,${PERL_MODULE_BUNDLE_DIRS},$(eval $(call generate_module_bundle_rule,${d})))

#scripts/colors.mk:
#	@text-in-a-box -print $(foreach color,R G B C M Y K W U X,'${color} := %${color}') 'UX := %!U' >& $@

# -include scripts/colors.mk

#
# Installation and synchronization with possibly updated installed modules
#

USE_SUDO := $(shell [[ -w ${DESTDIR}/ && -w ${INSTALLED_PERL_SCRIPTS_DIR}/ ]] && echo "" || echo sudo)
DESTDIR ?= ${PERL_SITELIB}

RSYNC_OPTIONS := -aAXxuc --omit-dir-times --out-format=$$'\t\t - %n'
RSYNC_DRY_RUN_OPTIONS := ${RSYNC_OPTIONS} --dry-run

sync-modules: ${PERL_MODULES}
	$(call print_build,SYNC,Synchronizing source tree with any newer Perl modules in ${PERL_SITELIB})
	@cp -avu --parents -t ./ $(addprefix ${PERL_SITELIB}/,${PERL_MODULES})

install-modules: ${PERL_MODULES} ${PERL_MODULE_BUNDLES}
	$(call print_build,INSTALL,Installing $(words ${PERL_MODULES}) Perl modules into ${DESTDIR})
	@${USE_SUDO} cp -avu --parents -t ${DESTDIR}/ ${PERL_MODULES} ${PERL_MODULE_BUNDLES}

test-install-modules: ${PERL_MODULES} ${PERL_MODULE_BUNDLES} build/modules.list
	$(call print_build,TESTinst,(dry run) Installing $(words ${PERL_MODULES}) Perl modules into ${DESTDIR})
	@rsync ${RSYNC_DRY_RUN_OPTIONS} MTY/ ${DESTDIR}/MTY/ | grep -v -P '/\Z' || true

sync-scripts: ${PERL_SCRIPTS}
	$(call print_build,SYNC,Synchronizing source tree with any newer Perl scripts in ${INSTALLED_PERL_SCRIPTS_DIR})
	@cp -avu -t scripts/ $(addprefix ${INSTALLED_PERL_SCRIPTS_DIR}/,$(notdir ${PERL_SCRIPTS}))

install-scripts: ${PERL_SCRIPTS} 
	$(call print_build,INSTALL,Installing $(words ${PERL_SCRIPTS}) Perl scripts into ${INSTALLED_PERL_SCRIPTS_DIR})
	@${USE_SUDO} cp -avu -t ${INSTALLED_PERL_SCRIPTS_DIR}/ ${PERL_SCRIPTS}

test-install-scripts: ${PERL_SCRIPTS} build/perl-scripts.list
	$(call print_build,TESTinst,(dry-run) Installing $(words ${PERL_SCRIPTS}) Perl scripts into ${INSTALLED_PERL_SCRIPTS_DIR})
	@rsync ${RSYNC_DRY_RUN_OPTIONS} scripts/ ${INSTALLED_PERL_SCRIPTS_DIR}/ | grep -v -P '/\Z' || true

sync: sync-modules sync-scripts
install-without-sync: install-modules install-scripts
install: install-modules install-scripts
test-install: test-install-modules test-install-scripts

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
	@rm -f ${PERL_CONFIG_MK} ${EXTDEPS_CHECKED_MK} build/perl-mod-deps*.log

clean:
	$(call print_build,CLEAN,Cleaning and removing all generated files)
	@rm -r -f build/ ${PERL_MODULE_BUNDLES} 

commit:
	git add -v .
	git commit

push:
	git push origin master


all: ${PERL_MODULE_BUNDLES} build/modules.list build/perl-scripts.list 

