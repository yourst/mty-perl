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

#
# Set default make flags: -r/-R = disable implicit rules, 
# -s = silent (no echo), -j1 = non-parallel (we don't need
# it, and it tends to break things specific to CPAN builds)
#

MAKEFLAGS := -r -R -s -j1

.: .default

.PHONY: . .default

AUTO_GENERATED_FILES_AND_DIRS := distributions packages readmes meta all-authors metadata metadata/% deps/% deps build installed m r s
EXCLUDE_FROM_SYNC := Makefile ${AUTO_GENERATED_FILES_AND_DIRS}

FIND_TARGETS := $(foreach target,all package pkg module mod distribution dist readme meta author,find-${target} find-${target}s)

TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST := \
  which which-cpan which-local \
  cpan-version local-version version ver \
  deps unpack config build preinstall install \
  source readme man doc perldoc listdeps showdeps \
  cleanbuild cleaninstall

TARGETS_REQUIRING_OTHER_ARGS := \
  find findany findall find-local \
	${FIND_TARGETS}

PHONY_GLOBAL_TARGETS := clean all-sources sync sync-test sync help \
  metadata clean-metadata links links-to-authors clean-links all-deps clean-deps

GLOBAL_TARGETS := ${PHONY_GLOBAL_TARGETS} ${AUTO_GENERATED_FILES_AND_DIRS}

.PHONY: ${TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST} ${TARGETS_REQUIRING_OTHER_ARGS} ${PHONY_GLOBAL_TARGETS}

.SILENT: ${TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST} ${TARGETS_REQUIRING_OTHER_ARGS} ${GLOBAL_TARGETS} \
	$(addprefix metadata/,perl-config.mk packages-distributions-and-versions distributions.mk all-readmes)

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
search_dir_list_for_file = $(call find_first_matching_file,$(addsuffix /${1},${2}))

readlink = $(shell readlink ${1})

# i.e. MAX_INT = (2**31) - 1
MAX_INT := 2147483647

MISSING_INCLUDE_MESSAGE = Failed to include '${1}', which does not exist and/or cannot be accessed

print_indented_makefile_stack = $(info $(patsubst %,${SPACE}${SPACE},$(wordlist 2,${MAX_INT},${MAKEFILE_STACK}))${2})

define __include
ifndef included[${1}]
  MAKEFILE := $$(call search_dir_list_for_file,${1},. $${.INCLUDE_DIRS})
  ifneq (,$${MAKEFILE})
    included[${1}] := $${MAKEFILE}
    MAKEFILE_STACK := $${MAKEFILE} $${MAKEFILE_STACK}
    $(if ${TRACE_INCLUDES},$$(call print_indented_makefile_stack,$${MAKEFILE},[include $${MAKEFILE}]))
    include $${MAKEFILE}
    MAKEFILE_STACK := $$(wordlist 2,${MAX_INT},$${MAKEFILE_STACK})
  else # ${1} does not exist
    $$(if ${TRACE_INCLUDES},$$(call print_indented_makefile_stack,$${1},<Cannot include $${1}>))
    ifeq (,${2}) # ${2} (include_if_exists) is unset
      $$(error $$(MISSING_INCLUDE_MESSAGE))
    else # ${2} (include_if_exists) is set
      # Cache negative results too (off by default so makefiles can be rebuilt):
      # included[${1}] := <missing ${1}>
      $$(if ${WARN_IF_MISSING_INCLUDE},$$(info $$(MISSING_INCLUDE_MESSAGE)))
    endif # ${2} (include_if_exists) is set
  endif # ${2} does not exist
else # included[${1}] defined
  $(if ${TRACE_INCLUDES},$$(call print_indented_makefile_stack,$${MAKEFILE},${SPACE}${SPACE}[already-included ${1}]))
endif # included[${1}]
MAKEFILE := $$(firstword $${MAKEFILE_STACK})
endef # __include

include = $(foreach f,${1},$(eval $(call __include,${f})))
include_if_exists = $(foreach f,${1},$(eval $(call __include,${f},1)))

MAKEFILE := $(realpath $(lastword ${MAKEFILE_LIST}))
TOPLEVEL_MAKEFILE := ${MAKEFILE}
included[$(lastword ${MAKEFILE_LIST})] := ${MAKEFILE}
MAKEFILE_STACK := ${TOPLEVEL_MAKEFILE}
$(if ${TRACE_INCLUDES},$(info [makefile $${MAKEFILE}]))

BASEDIR := $(realpath $(CURDIR))

#----------------------------------------------------------------------------+
# Definitions and functions specific to this project:                        |
#----------------------------------------------------------------------------+

package_to_distribution = $(notdir $(shell readlink packages/${1}))
modules_starting_with = $(notdir $(wildcard packages/${1}*))

#----------------------------------------------------------------------------+
# Determine the current Perl version and its standard library directories:   |
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
$(call include,metadata/perl-config.mk)
ifeq (,$(and ${perl_version},${perl_perlpath},${perl_sitelib},${perl_sitearch},${perl_archname}))
$(error Cannot query Perl configuration - is Perl installed?)
endif # (missing any of perl_*)
$(foreach var,$(addprefix perl_,${PERL_CONFIG_VARS}),$(info - ${var}${TAB}= ${${var}}))
else # perl_version is set
#
# Declare a rule to ensure perl-config.mk is rebuilt 
# if the perl version and/or paths have changed:
#
metadata/perl-config.mk: ${perl_perlpath} 
	perl -e '${get_perl_config_script}' > $@
endif # perl_version

#----------------------------------------------------------------------------+
# Set the target goals based on the make command line:                       |
#----------------------------------------------------------------------------+
ifneq (,$(filter clean sync,${MAKECMDGOALS}))
SKIP_INCLUDES := 1
endif # clean || sync || update

action := $(firstword ${MAKECMDGOALS})
module := $(wordlist 2,$(words ${MAKECMDGOALS}),${MAKECMDGOALS})

ifneq (,${MAKECMDGOALS})
ifeq (,$(filter ${GLOBAL_TARGETS},${action}))
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
$(error Cannot find distribution containing package named '${module}' for action '${action}')
endif # distribution_of_module_package
endif # action in TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST

MAKECMDGOALS := ${action}
.DEFAULT_GOAL := ${action}
.default: ${action}

#----------------------------------------------------------------------------+
# Set important variables based on the specified package/module/distribution |
#----------------------------------------------------------------------------+

distribution := ${distribution_of_module_package}
tar_gz_to_build := $(realpath distributions/${distribution})
cpan_version := $(or $(subst ${distribution}-,,$(patsubst %.tar.gz,%,$(notdir ${tar_gz_to_build}))),(no versions of ${module} found on CPAN))
build_dir := $(BASEDIR)/build/${distribution}
install_dir_base := $(BASEDIR)/installed
install_dir := installed/${distribution}

TIMESTAMP_NOW := $(shell date '+%s')
TIMESTAMP_LAST_SYNC := $(shell date -r modules/02STAMP '+%s')
TIMESTAMP_LAST_SYNC_AS_TEXT := $(shell date -r modules/02STAMP '+%b %d, %Y')

calc = $(shell echo $$((${1})))

LAST_UPDATE_DAYS_AGO := $(call calc,(${TIMESTAMP_NOW}-${TIMESTAMP_LAST_SYNC})/(60*60*24))

define MAKEFILE_BANNER
%{align=left}%Y%[star]%{align=center}%G%UCPAN Mirror Makefile%!U%{align=right}%Y%[star] 
%{div=dashed}
%BLast updated on %C${TIMESTAMP_LAST_SYNC_AS_TEXT}%B (%C${LAST_UPDATE_DAYS_AGO}%B days ago)
%BUsing Perl version %M${perl_version}
endef # MAKEFILE_BANNER

text_in_a_box_prep = text-in-a-box '$(subst ${NL},'${SPACE}',${1})'

define text_in_a_box
$(shell $(call text_in_a_box_prep,${1}) ${2} ${3} ${4} ${5} ${6} ${7} ${8} ${9} 1>&2)
endef # text_in_a_box

print_makefile_banner = $(call text_in_a_box,${MAKEFILE_BANNER},-style,heavy,-color,R)

ifeq (,${MAKE_RESTARTS})
$(print_makefile_banner)
endif # ! MAKE_RESTARTS

ifneq (,$(filter ${TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST},${action}))
$(info - Selected action: ${action})
$(info - Package ${module} is provided by distribution ${distribution})
$(info - Source in $(tar_gz_to_build) (and source/${distribution}))
$(info - Final installation directory will be ${perl_sitelib}/$(patsubst ::,/,${module}))
$(info )
endif # action in TARGETS_REQUIRING_MODULE_OR_PACKAGE_OR_DIST

#----------------------------------------------------------------------------+
# Maintain various metadata caches of our mirror of CPAN:                    |
#----------------------------------------------------------------------------+

# $1 = module, $2 = module_version, $3 = source_tar_gz_dir, $4 = distribution_base_name, $5 = distribution_version
PARSE_PACKAGES_DETAILS_RE := '^ (\S++) \s++ (\S++) \s++ ((?: [\w\-]++ /)++) ([^/]+?) - (v? [\d\.]+)\.tar\.gz $$'
METADATA := metadata/packages-distributions-and-versions

# Reformat into: <module> <dist_base_name> <dist_tar_gz_dir> <dist_ver> <mod_ver>
${METADATA}: modules/02packages.details.txt
	echo -n '- Parsing modules/02packages.details.txt published by CPAN into $@...'
	mkdir -p metadata
	perlre -x ${PARSE_PACKAGES_DETAILS_RE} '$$1\t$$4\t$$3\t$$5\t$$2\n' < modules/02packages.details.txt > $@
	echo 'done'

PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE := '^ (\S++) \t (\S++) \t (\S++) \t (\S++) \t'

#SORT_SYMLINK_LIST_CMD := sort -r -k 2 | uniq -f 1
#SYMLINK_LIST_CMD := ${SORT_SYMLINK_LIST_CMD} | symlink-list -check -warn

format_metadata = perlre -x ${PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE} ${1} < ${METADATA}
#format_metadata_and_symlink = $(format_metadata) | ${SYMLINK_LIST_CMD}
#format_metadata_and_symlink_and_count_missing = MISSIN |& fgrep -c 'not creating dangling link'`; 

define update_symlinks
	echo -n '- Updating symlinks in ${1}...'
	mkdir -p ${1}
	perlre -x ${PARSE_PACKAGES_DISTRIBUTIONS_AND_VERSIONS_RE} ${2} < ${METADATA} \
    | sort -r -k 2 | uniq -f 1 | symlink-list -check -summary
	touch ${1}
endef # update_symlinks

distributions: ${METADATA}
	$(call update_symlinks,$@,'../authors/id/$$3$$2-$$4.tar.gz\tdistributions/$$2\n')
	ln -sf distributions d

packages: ${METADATA} distributions
	$(call update_symlinks,$@,'../distributions/$$2\tpackages/$$1\n')
	ln -sf packages p

readmes: ${METADATA}
	$(call update_symlinks,$@,'../authors/id/$$3$$2-$$4.readme\treadmes/$$2\n')
	ln -sf readmes r

meta: ${METADATA}
	$(call update_symlinks,$@,'../authors/id/$$3$$2-$$4.meta\tmeta/$$2\n')
	ln -sf meta m

metadata/all-readmes: readmes
	echo -n '- Building index of all readme files...'; \
	cat-with-filename-headers readmes/* > $@; \
	echo 'done'

metadata/distributions.mk: distributions
	$(info - Creating $@...)
	$(file >$@,ALL_DISTRIBUTIONS := $(notdir $(wildcard distributions/*)))

-include metadata/distributions.mk

metadata: distributions packages readmes meta metadata/distributions.mk metadata/all-readmes links all-deps

clean-metadata:
	rm -rf metadata

clean-links:	
	rm -rf distributions packages readmes meta

links: distributions packages readmes meta

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

#----------------------------------------------------------------------------+
# Finding packages, modules or distributions ("make find-xxx <target>")      |
#----------------------------------------------------------------------------+

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

ABBREV_FOR_FIND_distributions = dist
ABBREV_FOR_FIND_packages      = pkg 
ABBREV_FOR_FIND_authors       = user
ABBREV_FOR_FIND_readmes       = read
ABBREV_FOR_FIND_meta          = meta

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

#----------------------------------------------------------------------------+
# Determining latest versions of packages locally or on CPAN:                |
#----------------------------------------------------------------------------+

local_module  = $(shell perlwhich -f ${module})
local_version = $(shell perlwhich -v ${module})

which-cpan:
	$(info $(or ${tar_gz_to_build},Cannot find CPAN module ${module}))

which-local:
	$(info Local file for module ${module} is ${local_module})

which: 
	ls -latr ${local_module} ${tar_gz_to_build}
	[ ${tar_gz_to_build} -nt ${local_module} ] && echo "(CPAN source is newer than locally installed module)"

cpan-version:
	@$(info CPAN version of ${module} = $(cpan_version))

find-local:
	@$(info $(or ${local_module},[Cannot find local module ${module}]))

local-version:
	@$(info Local version of ${module} = $(or ${local_version},[${module} is not installed locally]))

ver version: cpan-version local-version

#----------------------------------------------------------------------------+
# Show man pages or readmes for target ("make man|doc|perldoc|readme ...")   |
#----------------------------------------------------------------------------+

man doc perldoc: source/${distribution}/lib/$(subst ::,/,${module}).pm
	@perldoc $<

readme:
	less readmes/${distribution}.readme

#----------------------------------------------------------------------------+
# Maintain source/<distribution> directories for every package on CPAN:      |
#----------------------------------------------------------------------------+

#
# Synchronize any source/<PackageName> directories where
# the tar.gz is newer than the unpacked source tree:
#
# *** NOTE *** This will expand to over 10+ GB of data for the current CPAN
#

.SILENT: source/%
source/%:
	@echo "Extracting source from $< into $@"; \
  [[ -d "$@" ]] && rm -rf $@; \
  mkdir -p $@; \
  tar --no-same-owner --no-same-permissions -x -f $< --strip-components=1 -C $@; \
	touch $@

ifneq (,$(filter all-sources deps,${action}))
#
# Only include this part of the Makefile if we really want all the sources,
# since it takes make a very long time just to read in the names of all the
# CPAN distributions and track their dependencies:
#
$(foreach d,${ALL_DISTRIBUTIONS},$(eval source/${d}: $(realpath distributions/${d})))

all-sources: $(addprefix source/,${ALL_DISTRIBUTIONS})

endif # action == all-sources

#----------------------------------------------------------------------------+
# Download and synchronize this local mirror with the CPAN mirror network:   |
#----------------------------------------------------------------------------+

#
# CPAN_MIRROR_SITE can be changed here or via "make CPAN_MIRROR_SITE=... sync"
# to a mirror server and directory of your choice, which must support rsync:
#
CPAN_MIRROR_SITE := ftp.osuosl.org/cpan
EXCLUDE_FROM_SYMC := Makefile 
RSYNC_CMD := /usr/bin/rsync -a -v -x --omit-dir-times $(addprefix --exclude ,${EXCLUDE_FROM_SYNC}) rsync://${CPAN_MIRROR_SITE}/ ./

sync-dryrun sync-test:
	$(RSYNC_CMD) --dry-run --stats | /usr/bin/grep -P -v '\/\Z'

sync:
	$(RSYNC_CMD)

#----------------------------------------------------------------------------+
# Determine which distributions each distribution depends on:                |
#----------------------------------------------------------------------------+

#ifneq (,$(filter build install listdeps showdeps,${action}))
#ifneq (,${distribution})
#ifneq (,$(wildcard deps/${distribution}))
#$(call include,deps/${distribution})
#installed_deps := $(shell perlwhich ${redeps[${distribution}]})
#deps_of_dist := ${redeps[${distribution}]}
#deps_to_build := $(filter-out ${installed_deps},${deps_of_dist})
#else # deps/${distribution} not found
#$(warning Prerequisite dependencies of ${distribution} in deps/${distribution} not found)
#endif # deps/${distribution} not found
#endif # ${distribution}
#endif # action is one of {build, install, listdeps, showdeps}

metadata/alldeps.mk: $(addprefix source/,${ALL_DISTRIBUTIONS})
	${BASEDIR}/find-packages-and-deps-in-cpan-dist -m ${BASEDIR}/packages -a ${BASEDIR}/source -u ${BASEDIR}/metadata/alldeps.mk

metadata/distdeps.mk: metadata/alldeps.mk
	grep -P '^distdeps\[' $< > $@

define build_dist_deps_rule
${1}: ${2}
endef # build_dist_deps_rule

define find_recursive_deps
$(info ${2}find_recursive_deps(${1}): distdeps = ${distdeps[${1}]}, redeps = ${redeps[${1}]}, depschecked = ${depschecked[${1}]})\
$(if ${depschecked[${1}]},$(info Already did ${1}),$(if ${redeps[${1}]},$(info ${2}Already have redeps[${1}] = ${redeps[${1}]}),\
$(eval depschecked[${1}] := 1)$(info ${2}Must recurse on ${1}: deps ${redeps[${1}]})$(eval redeps[${1}] := * ${distdeps[${1}]} $(foreach dist,${distdeps[${1}]},$(call find_recursive_deps,${dist},${2}  )))))
endef # find_recursive_deps
#${redeps[${1}]}
#$(eval redeps[${1}] += #
#  ${redeps[${1}]})
ifneq (,$(filter build install listdeps showdeps,${action}))
include metadata/distdeps.mk

#$(error recdeps = $(filter-out !%,$(call find_recursive_deps,${distribution})))
#redeps[${distribution}] := $(call find_recursive_deps,${distribution})
# $(foreach dist,${ALL_DISTRIBUTIONS},$(eval $(call build_dist_deps_rule,${dist},${distdeps[${dist}]})))
# $(foreach dist,${ALL_DISTRIBUTIONS},$(eval $(call build_dist_deps_rule,${dist},${distdeps[${dist}]})))
endif # action is one of {build, install, listdeps, showdeps}


.SILENT: deps/% deps
deps/%: source/%
	@$(info Finding dependencies of distribution $*)
	@mkdir -p deps; \
	${BASEDIR}/find-packages-and-deps-in-cpan-dist $* ${BASEDIR}/source/$* ${BASEDIR}/packages > $@

#	cd source && ${BASEDIR}/perl-dist-deps -path-to-dist-re \
#    -package-to-dist-symlinks-dir=${BASEDIR}/packages \
#     -output-to-per-dist-files-in-dir=${BASEDIR}/deps \
#     `/usr/bin/find $* -type f -printf '%p\n' | /usr/bin/grep -P '\.(p[ml]|PM|al)$$'`

#define get_direct_deps
#$(if $(filter perl,${1}),,$(if ${packages[${1}]},$(info ${2}[Have deps for ${1} = ${distdeps[${1}]}]),$(info ${2}[Load deps for ${1}])$(eval -include deps/${1}))${distdeps[${1}]}
#endef # include_deps

#define find_recursive_deps
#$(if ${havealldeps[${1}]},$(info ${2}[All deps for ${1} = ${alldeps[${1}]}])${alldeps[${1}]},$(eval alldeps[${1}] := $(call get_direct_deps,${1},${2}) $(foreach d,${distdeps[${1}]},$(call find_recursive_deps,${d},${2}  )))${alldeps[${1}]})
#endef # find_recursive_deps

#$(error recdeps = $(call find_recursive_deps,Regexp-Common-Other))

deps: deps/${distribution}

listdeps showdeps:
	$(info Prerequisite dependencies to build ($(words ${deps_to_build})):)
	$(foreach d,${deps_to_build},$(info ${SPACE}${SPACE}${d}))
	$(info )
	$(info Previously installed and satisfied prerequisite dependencies ($(words $(filter-out ${installed_deps},${deps_to_build}))):)
	$(foreach d,$(filter-out ${installed_deps},${deps_to_build}),$(info ${SPACE}${SPACE}${d}))
	$(info )

deps/.timestamp: $(addprefix source/,${ALL_DISTRIBUTIONS})
	@$(info Updating dependencies for $(words $?) distributions...)
	@$(file >${BASEDIR}/deps/.updated-dists,$(subst ${SPACE},${NL},$(notdir $?)))
	@mkdir -p deps; \
	cd source; \
  rm -f ${BASEDIR}/deps/.updated-dist-files; \
	echo '  Finding relevant files in $(words $?) updated distributions...'; \
	for d in `cat ${BASEDIR}/deps/.updated-dists`; do \
	  /usr/bin/find $$d -type f -printf '%p\n' | /usr/bin/grep -P '\.(p[ml]|PM|al)$$' >> ${BASEDIR}/deps/.updated-dist-files; \
  done; \
	echo '  Updating dependencies for `wc -l ${BASEDIR}/deps/.updated-dist-files` files in $(words $?) distributions...'; \
  ${BASEDIR}/perl-dist-deps -path-to-dist-re \
  -package-to-dist-symlinks-dir=${BASEDIR}/packages \
  -output-to-per-dist-files-in-dir=${BASEDIR}/deps \
  -filenames-from-stdin < ${BASEDIR}/deps/.updated-dist-files; \
	touch ${BASEDIR}/deps/.timestamp

all-deps: metadata/distdeps.mk

#$(addprefix deps/,${ALL_DISTRIBUTIONS})

#deps/.timestamp

#----------------------------------------------------------------------------+
# Build distributions specified by name or by packages they provide:         |
#----------------------------------------------------------------------------+

# Separator bar to separate sections of output from this Makefile:
SEPARATOR := ===============
SEPARATOR := $(subst _,${SEPARATOR},_________)

${build_dir}: ${tar_gz_to_build}
	$(info ${SEPARATOR})$(info Preparing to build package ${distribution} from source ${tar_gz_to_build} in directory ${build_dir}...)
	@rm -rf ${build_dir} ${install_dir}; \
	mkdir -p ${build_dir} ${install_dir}; \
	echo 'Extracting ${tar_gz_to_build} into ${build_dir}...'; \
	tar --no-same-owner --no-same-permissions -x -f ${tar_gz_to_build} --strip-components=1 -C ${build_dir};

#
# Each distribution's Makefile is dynamically built by running either 
# Makefile.PL or Build.PL, depending on whether the distribution was
# prepared for CPAN using MakeMaker or Module::Build, respectively.
#
# Since some distributions don't include this information in their
# metadata, we simply look for Makefile.PL or Build.PL in their
# source directory and execute whichever one was found.
#
CONFIG_SCRIPT_FILENAMES := Makefile.PL Build.PL Makefile.pl Build.pl

define find_config_script_filename
$(firstword $(wildcard $(addprefix ${BASEDIR}/build/$1/,${CONFIG_SCRIPT_FILENAMES})))
endef # config_script_filename

config_script_filename = $(call find_config_script_filename,${distribution})

# |& tee config.log && echo "Done with configuration"; 
# 		echo "(end of config.log)";

${build_dir}/Makefile: ${build_dir} $(config_script_filename)
	$(eval CONFIG_SCRIPT_FILENAME := $(config_script_filename))
	$(info ${SEPARATOR})
	$(info Configuring distribution ${distribution})
	$(info Generating Makefile by running configuration script ${CONFIG_SCRIPT_FILENAME}...)
	@cd ${build_dir}; pwd; perl ${CONFIG_SCRIPT_FILENAME}; $(if ${NODEPS},true;)

ifdef CHECK_DEPS
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
	$(info ${SEPARATOR})$(info Building distribution ${distribution} in ${build_dir}...)
	@$(MAKE) -C ${build_dir};
ifndef NOTEST
	$(info Testing distribution ${distribution}...)
	@$(MAKE) -C ${build_dir} test
endif # ! NOTEST

${install_dir} preinstall: build
	$(info ${SEPARATOR})$(info Installing distribution ${distribution} into staging directory ${install_dir})
	@rm -rf ${install_dir}
	@$(MAKE) -C ${build_dir} DESTDIR=${install_dir_base}/${distribution} install && \
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

#----------------------------------------------------------------------------+
# Utility targets (package/module/distribution name not required):           |
#----------------------------------------------------------------------------+

clean:
	$(info Cleaning all automatically generated files and directories...)
	@rm -rf ${AUTO_GENERATED_FILES_AND_DIRS}

Makefile: ;

#----------------------------------------------------------------------------+
# Print help for this Makefile when running "make help" or without a command |
#----------------------------------------------------------------------------+

define help_text

%C%UCPAN makefile infrastructure developed and maintained by:%X

  %GMatt T. Yourst %B<yourst@yourst.com>%X

%C%USyntax is:%X

  %Gmake%X %B<%Mpackage|module|distribution%B>%X
  %Gmake%X %B<%Maction%B>%X %B<%Mpackage|module|distribution%B>%X
  %Gmake%X find-%B<%Mtype%B>%X %B<%Msubstring|wildcards|regexp%B>%X
  %Gmake%X %B<%Mglobal-action%B>%X

  The supported actions are listed below. If no action is specified, and the
  first argument is recognized as a valid package, module or distribution,
  this is equivalent to "make build ...".

  %B<%Mpackage%B>%X or %B<%Mmodule%B>%X is a Perl package name of the form Package::Name::Here
  %B<%Mdistribution%B>%X is a CPAN distribution name of the form Dist-Name-Here

  The %B<%Mpackage|module|distribution%B>%X argument may be omitted for some global 
  actions listed below, but is required for most actions.

%C%UActions which require a package, module or distribution name:%X

  %Ywhich-cpan%X     Show the path of the .tar.gz file of the specified distribution
  %Ywhich-local%X    Show the path of the .pm file of the specified module or package
  %Ywhich%X          Invokes both which-cpan and which-local

  %Ycpan-version%X   Show the latest CPAN version of the specified target
  %Ylocal-version%X  Show the installed version of the specified module or package
  %Yversion | ver%X  Show both cpan-version and local-version

  %Yunpack%X         Extract the target distribution .tar.gz archive into 
                 build/<distribution>

  %Yconfig%X         Determine how to configure the target (e.g. by running either
                 Makefile.PL or Build.PL), and run this configuration script

  %Ybuild%X          Run make on the target distribution (in build/<distribution>)
                 to compile any necessary files (including .xs sources, etc)

  %Ypreinstall%X     Copy the .pm, .so, .al, etc. files to be installed into their
                 proper directories relative to installed/<distribution>/

  %Yinstall%X        Copy the pre-installed files from installed/<distribution>/
                 into the /usr/lib/perl5/site_perl/<perl.version>/ directory.
                 (NOTE: This must be run as root, e.g. "sudo make install ...")

  %Ysource%X         Extract the target distribution .tar.gz archive into
                 source/<distribution> (similar to "make unpack")

  %Yreadme%X         Show the README file for the target (piped through "less")

  %Yman%X            Show the manual page for the target

  %Ylistdeps%X       Show all other prerequisite distributions on which the 
                 specified target depends; these other prerequisites will
                 be built before the target itself is built.

  %Ycleanbuild%X     Remove the build/<distribution>/ directory
  %Ycleaninstall%X   Remove the installed/<distribution>/ directory

%C%UActions which require a search substring, wildcards or regexps:%X

  %Yfind-<type>%X    Find filenames of the specified <type> which contain the target 
                 string, where <type> may be one of: package, pkg, module, mod, 
                 distribution, dist, readme, meta, author

  %Yfind%X           Find any of the file types listed above for find-<type>

%C%UGlobal actions which do not require any module, package or distribution:%X

  %Ysync%X           Synchronize this local mirror with the latest files on CPAN
                 by using rsync to download any updated files and delete any
                 older versions

  %Ysync-test%X      Show what would be downloaded or deleted using "make sync"

  %Yclean%X          Remove all files which are generated by this Makefile and not
                 part of the official CPAN mirror

  %Yclean-metadata%X Remove the generated metadata/ directory but not the links

  %Yclean-links%X    Remove packages/, distributions/, meta/, readmes/ directories

  %Ylinks-to-authors%X  Find all known authors and symlink their CPAN / PAUSE user
                    names into all-authors/<username>

  %Yall-sources%X    Run "make source" on all distributions which are newer than
                 their unpacked sources in source/<distribution>

%C%UPerl version:%X  ${perl_version}

endef # help_text

help: metadata all-deps
	{ $(call text_in_a_box_prep,${MAKEFILE_BANNER}) -style heavy -color R; \
		$(call text_in_a_box_prep,${help_text}) -print; } | less

none: ;


