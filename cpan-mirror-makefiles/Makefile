#
# CPAN mirror and build top level Makefile
#
# for syncing with master cpan-rsync.perl.org site,
# querying latest versions on CPAN and locally,
# and compiling, upgrading and installing packages
#
# Maintained by Matt T. Yourst <yourst@yourst.com>
#
# When specifying perl module names on the command line,
# use the form 'X.Y.Z' or 'X-Y-Z' instead of 'X::Y::Z'
# since gnu make doesn't allow target names with ':'.
#

MAKEFLAGS := -r -R -j1 

.: .default

.PHONY: . .default

AUTO_GENERATED_FILES_AND_DIRS := distributions packages readmes meta all-authors metadata build installed
EXCLUDE_FROM_SYNC := Makefile ${AUTO_GENERATED_FILES_AND_DIRS}

FIND_TARGETS := $(foreach target,all package pkg module mod distribution dist readme meta author,find-${target} find-${target}s)

TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST := \
  which which-cpan which-local \
  cpan-version local-version version ver \
  unpack config build preinstall install \
  source readme man doc perldoc listdeps showdeps \
  cleanbuild cleaninstall

TARGETS_REQUIRING_OTHER_ARGS := \
  find findany findall find-local \
	${FIND_TARGETS}

PHONY_GLOBAL_TARGETS := clean all-sources sync sync-test sync help \
  metadata clean-metadata links links-to-authors clean-links \

GLOBAL_TARGETS := ${PHONY_GLOBAL_TARGETS} metadata/perl-config.mk ${AUTO_GENERATED_FILES_AND_DIRS}

.PHONY: ${TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST} ${TARGETS_REQUIRING_OTHER_ARGS} ${PHONY_GLOBAL_TARGETS}

.SILENT: ${TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST} ${TARGETS_REQUIRING_OTHER_ARGS} ${GLOBAL_TARGETS}

#----------------------------------------------------------------------------+
# Useful definitions and utility functions:                                  |
#----------------------------------------------------------------------------+

NULL :=
SPACE := ${NULL} 
TAB := ${NULL}	
COMMA := ${NULL},
COLON := ${NULL}:
POUND := ${NULL}\#
LEFT_PAREN := (
RIGHT_PAREN := )
DOLLARSIGN := $$$$
define NL :=
${NULL}

endef # NL

suffixes = $(patsubst $(firstword $(subst .,${SPACE},${1}))%,%,${1})
final_suffix = $(lastword $(subst .,${SPACE},${1}))
strip_all_suffixes = $(firstword $(subst .,${SPACE},${1}))
strip_all_suffixes_and_dirs = $(firstword $(subst .,${SPACE},$(notdir ${1})))
shell_output_lines = $(subst ${TAB},${NL},$(shell { ${1} } | tr '\n' '\t'))
eval_shell_output_lines = $(eval $(subst ${TAB},${NL},$(shell { ${1} } | tr '\n' '\t')))

# find_first_matching_file wildcard1 wildcard2 wildcard3...
define find_first_matching_file
$(if ${1},$(or $(firstword $(wildcard $(firstword ${1}))),$(call find_first_matching_file,$(wordlist 2,$(words ${1}),${1}))))
endef # find_first_matching_file

# search_dir_list_for_file filename,dir1 dir2 dir3...
search_dir_list_for_file = $(call find_first_matching_file,$(addsuffix ${1},${2}))

readlink = $(shell readlink ${1})

#----------------------------------------------------------------------------+
# Definitions and functions specific to this project:                        |
#----------------------------------------------------------------------------+

package_to_distribution = $(notdir $(shell readlink packages/${1}))
modules_starting_with = $(notdir $(wildcard packages/${1}*))

BASEDIR=$(realpath $(CURDIR))

#----------------------------------------------------------------------------+
# Determine the current Perl version and its standard library directories:   +
#----------------------------------------------------------------------------+

#
# Note that we ask perl to print tabs in place of newlines, 
# since make's $(shell) function will convert newlines to
# spaces, yet for evaluation of the variable assignments as
# makefile symtax, we want those newlines, so we use $(subst)
# to convert the tabs back to newlines after using $(shell).
#

-include metadata/perl-config.mk

PERL_CONFIG_VARS := version archname perlpath sitelib sitearch 

define get_perl_config_script
use Config; \
foreach my $$k (qw(${PERL_CONFIG_VARS})) \
  { print("perl_".lc($$k)." := ".$$Config{$$k}."\n"); }
endef # get_perl_config_script

ifeq (,${perl_version})
# Build perl-config.mk for the first time:
$(info (Querying and caching current Perl configuration details...))
$(shell mkdir -p metadata && perl -e '${get_perl_config_script}' > metadata/perl-config.mk)
include metadata/perl-config.mk
ifeq (,$(and ${perl_version},${perl_perlpath},${perl_sitelib},${perl_sitearch},${perl_archname}))
$(error Cannot query Perl configuration - is Perl installed?)
endif # (missing any of perl_*)
$(foreach var,$(addprefix perl_,${PERL_CONFIG_VARS}),$(info - ${var}${TAB}= ${${var}}))
else # perl_version is set
# Declare a rule to ensure perl-config.mk is rebuilt 
# if the perl version and/or paths have changed:
metadata/perl-config.mk: ${perl_perlpath} 
	perl -e '${get_perl_config_script}' > $@
endif # perl_version

#----------------------------------------------------------------------------+
# Set the target goals based on the make command line:                       +
#----------------------------------------------------------------------------+
ifneq (,$(filter clean sync,${MAKECMDGOALS}))
SKIP_INCLUDES := 1
endif # clean || sync || update

action := $(firstword ${MAKECMDGOALS})
module := $(wordlist 2,$(words ${MAKECMDGOALS}),${MAKECMDGOALS})

ifneq (,${MAKECMDGOALS})
ifeq (,$(filter ${action},${GLOBAL_TARGETS}))
ifeq (,${module})
ifneq (,$(filter ${TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST} ${TARGETS_REQUIRING_OTHER_ARGS},${action}))
$(if ${module},,$(error Module, package or distribution name required for target action ${action}))
else # action not in TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST nor in TARGETS_REQUIRING_OTHER_ARGS
module := ${action}
action := install
endif # action == install
endif # (module defined)
endif # action is not a global action
else # MAKECMDGOALS is empty
action := help
endif # MAKECMDGOALS

#
# Dummy default target, so make won't try to rebuild the named module 
# when some other action was requested using "make <action> <Module::Name>"
#
MODULE_AS_TARGET := $(subst ::,\:\:,${module})
.PHONY: ${MODULE_AS_TARGET}
${MODULE_AS_TARGET}: ${action}
${MODULE_AS_TARGET}: ;

ifneq (,$(filter ${TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST},${action}))
ifneq (,$(wildcard packages/${module}))
distribution_of_module_package := $(call package_to_distribution,${module})
else # packages/${module} exists
ifneq (,$(wildcard distributions/${module}))
distribution_of_module_package := ${module}
endif # distributions/${module} exists
endif # packages/${module} not found
ifeq (,${distribution_of_module_package})
$(error Cannot find distribution containing package named '${module}')
endif # distribution_of_module_package
endif # action in TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST

MAKECMDGOALS := ${action}
.DEFAULT_GOAL := ${action}
.default: ${action}

distribution_to_build := ${distribution_of_module_package}
tar_gz_to_build := $(realpath distributions/${distribution_to_build})
cpan_version := $(or $(subst ${distribution_to_build}-,,$(patsubst %.tar.gz,%,$(notdir ${tar_gz_to_build}))),(no versions of ${module} found on CPAN))
build_dir := $(BASEDIR)/build/${distribution_to_build}
install_dir_base := $(BASEDIR)/installed
install_dir := installed/${distribution_to_build}
$(info )
$(info ${SPACE}${SPACE}*****************************************)
$(info ${SPACE}${SPACE}*  CPAN Mirror Makefile Infrastructure  *)
$(info ${SPACE}${SPACE}*****************************************)
$(info )
$(info - Package ${module} is provided by distribution ${distribution_to_build})
$(info - Source in $(tar_gz_to_build) (and source/${distribution_to_build}))
$(info - Final installation directory will be ${perl_sitelib}/$(patsubst ::,/,${module}))
$(info - Using Perl version ${perl_version})
$(info )

#
# Code to maintain various metadata caches of our mirror of CPAN:
#

# $1 = module, $2 = module_version, $3 = source_tar_gz_dir, $4 = distribution_base_name, $5 = distribution_version
PARSE_PACKAGES_DETAILS_RE := '^ (\S+) \s+ (\S+) \s+ ((?: [\w\-]+ /)+) ([^/]+) - ([\d\.]+)\.tar\.gz $$'

# Reformat into: <module> <dist_base_name> <dist_tar_gz_dir> <dist_ver> <mod_ver>
metadata/packages-distributions-and-versions: modules/02packages.details.txt
	mkdir -p metadata
	perlre -x ${PARSE_PACKAGES_DETAILS_RE} '$$1\t$$4\t$$3\t$$5\t$$2\n' < modules/02packages.details.txt > $@

PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE := '^ (\S++) \t (\S++) \t (\S++) \t (\S++) \t'
SORT_SYMLINK_LIST_CMD := sort -r -k 2 | uniq -f 1
SYMLINK_LIST_CMD := ${SORT_SYMLINK_LIST_CMD} | symlink-list -v

distributions: metadata/packages-distributions-and-versions
	mkdir -p distributions
	perlre -x ${PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE} '../authors/id/$$3$$2-$$4.tar.gz\tdistributions/$$2\n' < $< | ${SYMLINK_LIST_CMD}
	touch $@

packages: distributions metadata/packages-distributions-and-versions 
	mkdir -p packages
	perlre -x ${PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE} '../distributions/$$2\tpackages/$$1\n' < $< | ${SYMLINK_LIST_CMD}
	touch $@

readmes: metadata/packages-distributions-and-versions
	mkdir -p readmes
	perlre -x ${PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE} '../authors/id/$$3$$2-$$4.readme\treadmes/$$2\n' < $< | ${SYMLINK_LIST_CMD}
	touch $@

meta: metadata/packages-distributions-and-versions
	mkdir -p meta
	perlre -x ${PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE} '../authors/id/$$3$$2-$$4.meta\tmeta/$$2\n' < $< | ${SYMLINK_LIST_CMD}
	touch $@

metadata/all-readmes: readmes
	cat-with-filename-headers readmes/* > $@

metadata: distributions packages readmes meta metadata/all-readmes 

clean-metadata:
	rm -rf metadata/packages-distributions-and-versions metadata/all-readmes

clean-links:	
	rm -rf distributions packages readmes meta

links: metadata

#
# The author linking process is slow and rarely if ever needs 
# to be re-run, so don't waste time on it unless it's explicitly
# specified as a target:
#
links-to-authors:
	rm -rf all-authors
	mkdir -p all-authors
	echo -n "Finding all authors and creating symlinks to their directories in all-authors/*..."
	find authors/ -mindepth 4 -maxdepth 4 -type d -printf "../authors/%P\tall-authors/%f\n" | symlink-list -v
	echo "done (found $(find all-authors/ -type l | wc -l) authors)"

local_module  = $(shell perlwhich -f ${module})
local_version = $(shell perlwhich -v ${module})

define make_wildcard
$(if $(findstring *,${1}),${1},*${1}*)
endef # make_wildcard

define make_prefix_wildcard
$(if $(findstring *,${1}),${1},${1}*)
endef # make_prefix_wildcard

DIRS_FOR_FIND_all := packages distributions
DIRS_FOR_FIND_package := packages
DIRS_FOR_FIND_pkg := packages
DIRS_FOR_FIND_module := packages
DIRS_FOR_FIND_mod := packages
DIRS_FOR_FIND_distribution := distributions
DIRS_FOR_FIND_dist := distributions
DIRS_FOR_FIND_readme := readmes
DIRS_FOR_FIND_meta := metas
DIRS_FOR_FIND_author := all-authors

ABBREV_FOR_FIND_distributions = Dist
ABBREV_FOR_FIND_packages      = Pkg 
ABBREV_FOR_FIND_authors       = Auth
ABBREV_FOR_FIND_readmes       = Rdme
ABBREV_FOR_FIND_meta          = Meta

define format_find_result
${SPACE}${SPACE}${ABBREV_FOR_FIND_${3}}  ${1}  $(if $(filter distributions,${3}),(ver $(patsubst ${1}-%,%,$(patsubst %.tar.gz,%,$(notdir ${2})))))
endef # format_find_result

${FIND_TARGETS}:
	$(info Searching for ${DIRS_FOR_FIND_$(patsubst find-%,%,$(patsubst %s,%,$@))} with (case sensitive) names containing:)
	$(info )
	$(info ${SPACE}${SPACE}${module})
	$(info )	
	$(info Results:)
	$(info )
	$(foreach f,$(sort $(wildcard $(addsuffix /*${module}*,${DIRS_FOR_FIND_$(patsubst find-%,%,$(patsubst %s,%,$@))}))),$(info $(call format_find_result,$(notdir ${f}),$(realpath ${f}),$(lastword $(subst /,${SPACE},$(dir ${f}))))))
	$(info )

find findany findall: find-all

man doc perldoc: source/${distribution_to_build}/lib/$(subst ::,/,${module}).pm
	@perldoc $<

which-cpan:
	$(info $(or ${tar_gz_to_build},Cannot find CPAN module ${module}))

which-local:
	$(info Local file for module ${module} is ${local_module})

which: 
	ls -latr ${local_module} ${tar_gz_to_build}
	[ ${tar_gz_to_build} -nt ${local_module} ] && echo "(CPAN source is newer than locally installed module)"

readme:
	less all-readmes/latest/${distribution_to_build}.readme

cpan-version:
	@$(info CPAN version of ${module} = $(cpan_version))

find-local:
	@$(info $(or ${local_module},[Cannot find local module ${module}]))

local-version:
	@$(info Local version of ${module} = $(or ${local_version},[${module} is not installed locally]))

ver version: cpan-version local-version

#
# Synchronize any source/<PackageName> directories where
# the tar.gz is newer than the unpacked source tree:
#
#		$(info Extracting source from $< into $@)
#	[[ -d "$@" ]] && echo rm -rf $@

.SILENT: source/%
source/%:
	@echo "Extracting source from $< into $@"; \
  [[ -d "$@" ]] && rm -rf $@; \
  mkdir -p $@; \
  tar --no-same-owner --no-same-permissions -x -f $< --strip-components=1 -C $@; \
	touch $@

ifneq (,$(filter all-sources,${action}))
#
# Only include this part of the Makefile if we really want all the sources,
# since it takes make a very long time just to read in the names of all the
# CPAN distributions and track their dependencies:
#

ALL_DISTRIBUTIONS := $(notdir $(wildcard distributions/*))

$(foreach d,${ALL_DISTRIBUTIONS},$(eval source/${d}: $(realpath distributions/${d})))

all-sources: $(addprefix source/,${ALL_DISTRIBUTIONS})

endif # action == all-sources

#
# Download and synchronize this local mirror with the CPAN mirror network:
#
CPAN_MIRROR_SITE := ftp.osuosl.org/cpan
EXCLUDE_FROM_SYMC := Makefile 
RSYNC_CMD := /usr/bin/rsync -a -v -x --omit-dir-times $(addprefix --exclude ,${EXCLUDE_FROM_SYNC}) rsync://${CPAN_MIRROR_SITE}/CPAN/ ./

sync-dryrun sync-test:
	$(RSYNC_CMD) --dry-run --stats | /usr/bin/grep -P -v '\/\Z'

#all-modules/.rsync-timestamp:
sync:
	$(RSYNC_CMD)
	@mkdir -p all-modules all-readmes
	@touch all-modules/.rsync-timestamp

#
# Building distributions, modules and packages:
#

SEPARATOR := ===============
SEPARATOR := $(subst _,${SEPARATOR},_________)

${build_dir}: ${tar_gz_to_build}
	$(info ${SEPARATOR})$(info Preparing to build package ${distribution_to_build} from source ${tar_gz_to_build} in directory ${build_dir}...)
	@rm -rf ${build_dir} ${install_dir}; \
	mkdir -p ${build_dir} ${install_dir}; \
	echo 'Extracting ${tar_gz_to_build} into ${build_dir}...'; \
	tar --no-same-owner --no-same-permissions -x -f ${tar_gz_to_build} --strip-components=1 -C ${build_dir};

CONFIG_SCRIPT_FILENAMES := Makefile.PL Build.PL Makefile.pl Build.pl

define find_config_script_filename
$(firstword $(wildcard $(addprefix ${BASEDIR}/build/$1/,${CONFIG_SCRIPT_FILENAMES})))
endef # config_script_filename

config_script_filename = $(call find_config_script_filename,${distribution_to_build})

ifneq (,$(filter build install listdeps showdeps,${action}))
ifneq (,${distribution_to_build})
ifneq (,$(wildcard deps/${distribution_to_build}))
include deps/${distribution_to_build}
installed_deps := $(shell perlwhich ${redeps[${distribution_to_build}]})
deps_of_dist := ${redeps[${distribution_to_build}]}
deps_to_build := $(filter-out ${installed_deps},${deps_of_dist})
listdeps showdeps:
	$(info Prerequisite dependencies to build ($(words ${deps_to_build})):)
	$(foreach d,${deps_to_build},$(info ${SPACE}${SPACE}${d}))
	$(info )
	$(info Previously installed and satisfied prerequisite dependencies ($(words $(filter-out ${installed_deps},${deps_to_build}))):)
	$(foreach d,$(filter-out ${installed_deps},${deps_to_build}),$(info ${SPACE}${SPACE}${d}))
	$(info )
else # deps/${distribution_to_build} not found
$(warning Prerequisite dependencies of ${distribution_to_build} in deps/${distribution_to_build} not found)
endif # deps/${distribution_to_build} not found
endif # ${distribution_to_build}
endif # action is one of {build, install, listdeps, showdeps}
${build_dir}/Makefile: ${build_dir} $(config_script_filename)
	$(eval CONFIG_SCRIPT_FILENAME := $(config_script_filename))
	$(info ${SEPARATOR})
	$(info Configuring distribution ${distribution_to_build})
	$(info Generating Makefile by running configuration script ${CONFIG_SCRIPT_FILENAME}...)
	@cd ${build_dir}; pwd; \
	perl ${CONFIG_SCRIPT_FILENAME} |& tee config.log && echo "Done with configuration"; \
	echo "(end of config.log)";
ifndef NODEPS
	@grep -F -i -e 'warning' -e 'not found' ${build_dir}/config.log && WARNINGS_OR_ERRORS=1; \
  if [[ -n "$$WARNINGS_OR_ERRORS" ]]; then \
	  echo; \
	  echo -e "$$RED(Warnings or errors detected during prep: aborting)$$NOCOLOR"; \
    exit 255; \
	else \
	  true; \
	fi
endif
	if [[ ! -f ${build_dir}/Makefile ]]; then \
	  if [[ -f ${build_dir}/Build ]]; then \
	    echo "(Copying invoke-Build-file.mk to ${build_dir}/Makefile)"; \
	    cat ${BASEDIR}/invoke-Build-file.mk > ${build_dir}/Makefile; \
	  else \
	    echo "ERROR: Configuration script created neither a Makefile nor a Build script"; \
			exit 255; \
		fi; \
	fi

build: ${build_dir}/Makefile
	$(info ${SEPARATOR})$(info Building distribution ${distribution_to_build} in ${build_dir}...)
	@$(MAKE) -C ${build_dir};
ifndef NOTEST
	$(info Testing distribution ${distribution_to_build}...)
	@$(MAKE) -C ${build_dir} test
endif # ! NOTEST

${install_dir} preinstall: build
	$(info ${SEPARATOR})$(info Installing distribution ${distribution_to_build} into staging directory ${install_dir})
	@rm -rf ${install_dir}
	@$(MAKE) -C ${build_dir} DESTDIR=${install_dir_base}/${distribution_to_build} install && \
    touch ${install_dir}/ && echo 'Done!';

install: preinstall
	$(info ${SEPARATOR})$(info Installing distribution ${distribution} in /usr/lib/perl5/site_perl/...)
	@sudo /usr/bin/cp -v -d -R --preserve=mode,timestamps,links ${install_dir}/* /

cleanbuild: 
	$(info Cleaning build directory ${build_dir}...)
	@rm -rf ${build_dir}

cleaninstall: 
	$(info Cleaning install staging directory ${install_dir}...)
	@rm -rf ${install_dir}

#endif # perl_version

clean:
	$(info Cleaning all automatically generated files and directories...)
	@rm -rf ${AUTO_GENERATED_FILES_AND_DIRS}

Makefile: ;

ifeq (${action},help)
define help_text

Syntax is:

  make <package|module|distribution>
  make <action> <package|module|distribution>
  make find-<type> <substring|wildcards|regexp>
  make <global-action>

  The supported actions are listed below. If no action is specified, and the
	first argument is recognized as a valid package, module or distribution,
	this is equivalent to 'make build ...'.

  <package> or <module> is a Perl package name of the form Package::Name::Here
  <distribution> is a CPAN distribution name of the form Dist-Name-Here

  The <package|module|distribution> argument may be omitted for some global 
  actions listed below, but is required for most actions.

Actions which require a package, module or distribution name:

  which-cpan     Show the path of the .tar.gz file of the specified distribution
  which-local    Show the path of the .pm file of the specified module or package
  which          Invokes both which-cpan and which-local

  cpan-version   Show the latest CPAN version of the specified target
  local-version  Show the installed version of the specified module or package
  version | ver  Show both cpan-version and local-version

  unpack         Extract the target distribution .tar.gz archive into 
                 build/<distribution-name>

  config         Determine how to configure the target (e.g. by running either
                 Makefile.PL or Build.PL), and run this configuration script

  build          Run make on the target distribution (in build/<distribution>)
                 to compile any necessary files (including .xs sources, etc)

  preinstall     Copy the .pm, .so, .al, etc. files to be installed into their
                 proper directories relative to installed/<distribution>/

  install        Copy the pre-installed files from installed/<distribution>/
                 into the /usr/lib/perl5/site_perl/<perl.version>/ directory.
                 (NOTE: This must be run as root, e.g. 'sudo make install ...')

  source         Extract the target distribution .tar.gz archive into
                 source/<distribution-name> (similar to 'make unpack')

  readme         Show the README file for the target (piped through 'less')

  man            Show the manual page for the target

  listdeps       Show all other prerequisite distributions on which the 
                 specified target depends; these other prerequisites will
                 be built before the target itself is built.

  cleanbuild     Remove the build/<distribution>/ directory
  cleaninstall   Remove the installed/<distribution>/ directory

Actions which require a search substring, wildcards or regexps:

  find-<type>    Find filenames of the specified <type> which contain the target 
                 string, where <type> may be one of: package, pkg, module, mod, 
                 distribution, dist, readme, meta, author

  find           Find any of the file types listed above for find-<type>

Global actions which do not require any module, package or distribution:

  sync           Synchronize this local mirror with the latest files on CPAN
                 by using rsync to download any updated files and delete any
                 older versions

  sync-test      Show what would be downloaded or deleted using 'make sync'

  clean          Remove all files which are generated by this Makefile and not
                 part of the official CPAN mirror

  clean-metadata Remove the generated metadata/ directory but not the links

  clean-links    Remove packages/, distributions/, meta/, readmes/ directories

  links-to-authors  Find all known authors and symlink their CPAN / PAUSE user
                    names into all-authors/<username>

  all-sources    Run 'make source' on all distributions which are newer than
                 their unpacked sources in source/<distribution>

endef # help_text

$(info ${help_text})
endif # action == help

none: ;


