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

.: .default

.PHONY: . .default
.PHONY: list sync update clean 
.PHONY: metadata clean-metadata links links-to-authors clean-links

MODULE_NAME_REQUIRED_FOR_TARGETS := \
  which which-cpan which-local find-local \
  cpan-version local-version version ver \
  find-by-regexp find findany findall \
  unpack config build preinstall install clean cleaninstall \
  source readme

.PHONY: which which-cpan which-local 
.PHONY: find-by-regexp find findany findall 
.PHONY: cpan-version find-local local-version ver version
.PHONY: source all-sources readme
.PHONY: sync-dryrun sync-test sync
.PHONY: unpack config build preinstall install clean cleaninstall

.SILENT: ${MODULE_NAME_REQUIRED_FOR_TARGETS}

MAKEFLAGS := -r -R

NULL :=
SPACE := ${NULL} 
TAB := ${NULL}	
COMMA := ${NULL},
COLON := ${NULL}:
POUND := ${NULL}\#
LEFT_PAREN := (
RIGHT_PAREN := )
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
package_to_distribution = $(notdir $(shell readlink packages/${1}))
modules_starting_with = $(notdir $(wildcard packages/${1}*))

BASEDIR=$(realpath $(CURDIR))
DOLLARSIGN := $$$$

#
# Determine the current Perl version and its standard library directories
#

$(eval $(subst ${TAB},${NL},$(shell perl -e 'use Config; foreach $$k (qw(version sitelib sitearch)) { print("perl_$$k := ".$$Config{$$k}."\t"); };')))

ifeq (,$(and ${perl_version},${perl_sitelib},${perl_sitearch}))
$(error Cannot query Perl version, site library dir and site arch specific dir)
endif # (any of perl_version,perl_sitelib,perl_sitearch undefined)

ifneq (,$(filter clean sync update,${MAKECMDGOALS}))
SKIP_INCLUDES := 1
endif # clean || sync || update

ifneq (,$(filter findany findall,${ACTION}))
WILDCARDS := any
endif # SPECIAL_TARGET == findany || findall

ACTION := $(firstword ${MAKECMDGOALS})
MODULE := $(wordlist 2,$(words ${MAKECMDGOALS}),${MAKECMDGOALS})

ifeq (,${MODULE})
ifneq (,$(filter ${MODULE_NAME_REQUIRED_FOR_TARGETS},${ACTION}))
$(if ${MODULE},,$(error Module name required for target action ${ACTION}))
else # ACTION not in MODULE_NAME_REQUIRED_FOR_TARGETS
MODULE := ${ACTION}
ACTION := install
endif # ACTION == install
endif # (packages/${ACTION} exists)

#
# Dummy default target, so make won't try to rebuild the named module 
# when some other action was requested using "make <action> <Module::Name>"
#

MODULE_AS_TARGET := $(subst ::,\:\:,${MODULE})
.PHONY: ${MODULE_AS_TARGET}
${MODULE_AS_TARGET}: ${ACTION}
${MODULE_AS_TARGET}: ;

distribution_of_module_package := $(call package_to_distribution,${MODULE})

ifeq (,${distribution_of_module_package})
$(error Cannot find distribution containing package named '${MODULE}')
endif # distribution_of_module_package

MAKECMDGOALS := ${ACTION}
.DEFAULT_GOAL := ${ACTION}
.default: ${ACTION}

$(info MAKECMDGOALS = ${MAKECMDGOALS}, .DEFAULT_GOAL = ${.DEFAULT_GOAL})

distribution_to_build := ${distribution_of_module_package}
tar_gz_to_build := $(realpath distributions/${distribution_to_build})
cpan_version := $(or $(subst ${distribution_to_build}-,,$(patsubst %.tar.gz,%,$(notdir ${tar_gz_to_build}))),(no versions of ${MODULE} found on CPAN))
build_dir := $(BASEDIR)/build/${distribution_to_build}
install_dir_base := $(BASEDIR)/installed
install_dir := installed/${distribution_to_build}
$(info )
$(info Package ${MODULE} is provided by distribution ${distribution_to_build})
$(info Source in $(tar_gz_to_build))
$(info Final installation directory will be ${perl_sitelib}/$(patsubst ::,/,${MODULE}))
$(info Using Perl version ${perl_version})
$(info )
$(info Target action is: ${ACTION})
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

local_module  = $(shell perlwhich -f ${MODULE})
local_version = $(shell perlwhich -v ${MODULE})

find-by-regexp:
	@perl -e 'my $$re = qr/${MODULE}/oa; while (<>) { my ($$module, $$version) = split /\s+/; print("$module  ($version)\n") if ($$module =~ /$$re/oa); }' < ${BASEDIR}/all-modules/latest/.modules

define make_wildcard
$(if $(findstring *,${1}),${1},*${1}*)
endef # make_wildcard

define make_prefix_wildcard
$(if $(findstring *,${1}),${1},${1}*)
endef # make_prefix_wildcard

find findany findall:
	$(foreach f,$(sort $(wildcard ${BASEDIR}/all-modules/latest/$(call $(if $(filter any,${WILDCARDS}),make_wildcard,make_prefix_wildcard),${distribution_to_build}).tar.gz)),$(info $(subst -,::,$(patsubst %.tar.gz,%,$(notdir ${f})))))

which-cpan:
	$(info $(or ${tar_gz_to_build},Cannot find CPAN module ${MODULE}))

which-local:
	$(info Local file for module ${MODULE} is ${local_module})

which: 
	ls -latr ${local_module} ${tar_gz_to_build}
	[ ${tar_gz_to_build} -nt ${local_module} ] && echo "(CPAN source is newer than locally installed module)"

readme:
	less all-readmes/latest/${distribution_to_build}.readme

cpan-version:
	@$(info CPAN version of ${MODULE} = $(cpan_version))

find-local:
	@$(info $(or ${local_module},[Cannot find local module ${MODULE}]))

local-version:
	@$(info Local version of ${MODULE} = $(or ${local_version},[${MODULE} is not installed locally]))

ver version: cpan-version local-version

#
# Synchronize any source/<PackageName> directories where
# the tar.gz is newer than the unpacked source tree:
#

source/%: $(BASEDIR)/all-modules/latest/%.tar.gz
	@echo -n Unpacking $< into $@...
	@mkdir -p $(BASEDIR)/$@ && \
	cd $(BASEDIR)/$@ && \
	tar --no-same-owner --no-same-permissions --strip-components=1 -x -f $< && \
	echo 'done'

source: source/${distribution_to_build}

ALL_MODULE_NAMES := $(foreach mav,${ALL_MODULE_NAMES_AND_VERSIONS},$(firstword $(subst @, ,${mav})))

all-sources: all-modules/latest/.makefile $(addprefix source/,${ALL_MODULE_NAMES})
	@echo "Unpacked $(words $+) new or updated modules out of ${NUMBER_OF_MODULES} modules (most recent versions only)"
	@echo -n "Finding required storage space: "
	@echo "`du -scxh $(BASEDIR)/source/` used by all source/* directories"

CPAN_MIRROR_SITE=ftp.osuosl.org/cpan
RSYNC_CMD=/usr/bin/rsync -a -v -x --exclude Makefile --exclude packages --exclude distributions --exclude readmes --exclude meta --exclude metadata --exclude build --exclude installed rsync://${CPAN_MIRROR_SITE}/CPAN/ ./

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
SEPARATOR := $(subst _,${SEPARATOR},_____)

unpack: ${build_dir}/MANIFEST
${build_dir}/MANIFEST: ${tar_gz_to_build}
	$(info ${SEPARATOR})$(info Preparing to build package ${distribution_to_build} from source ${tar_gz_to_build} in directory ${build_dir}...)
	@rm -rf ${build_dir} ${install_dir}; \
	mkdir -p ${build_dir} ${install_dir}; \
	echo 'Extracting ${tar_gz_to_build} into ${build_dir}...'; \
	tar --no-same-owner --no-same-permissions -x -f ${tar_gz_to_build} --strip-components=1 -C ${build_dir};

CONFIG_SCRIPT_FILENAMES := Makefile.PL Build.PL Makefile.pl Build.pl

define find_config_script_filename
$(notdir $(or $(wildcard $(addprefix ${BASEDIR}/build/$1/,${CONFIG_SCRIPT_FILENAMES}))))
endef # config_script_filename

config: ${build_dir}/Makefile
${build_dir}/Makefile: unpack
	$(eval CONFIG_SCRIPT_FILENAME := $(call find_config_script_filename,${distribution_to_build}))
	$(info ${SEPARATOR})$(info Configuring distribution ${distribution_to_build} and generating Makefile by running configuration script ${CONFIG_SCRIPT_FILENAME}...)
	@cd ${build_dir}; pwd; \
	perl ${CONFIG_SCRIPT_FILENAME} |& tee config.log && echo "Done with configuration"; \
	cat ${build_dir}/config.log && echo "(end of config.log)";
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

build: config
	$(info ${SEPARATOR})$(info Building distribution ${distribution_to_build} in ${build_dir}...)
	@$(MAKE) -C ${build_dir};
ifndef NOTEST
	$(info Testing distribution ${distribution_to_build}...)
	@$(MAKE) -C ${build_dir} test
endif # ! NOTEST

preinstall: ${install_dir}
${install_dir}: build
	$(info ${SEPARATOR})$(info Installing distribution ${distribution_to_build} into staging directory ${install_dir})
	@rm -rf ${install_dir}
	@$(MAKE) -C ${build_dir} DESTDIR=${install_dir_base}/${distribution_to_build} install && \
    touch ${install_dir}/ && echo 'Done!';

install: preinstall
	$(info ${SEPARATOR})$(info Installing distribution ${distribution} in /usr/lib/perl5/site_perl/...)
	@sudo /usr/bin/cp -v -d -R --preserve=mode,timestamps,links ${install_dir}/* /

clean: 
	$(info Cleaning build directory ${build_dir}...)
	@rm -rf ${build_dir}

cleaninstall: 
	$(info Cleaning install staging directory ${install_dir}...)
	@rm -rf ${install_dir}

Makefile: ;

none: ;


