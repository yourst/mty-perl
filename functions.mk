# -*- makefile-gmake -*-
#
# This is a subset of the numerous functions found in functions.mk,
# which is a part of the Common Makefile Infrastructure project in
# in the "mty-make" repository. 
#
# Please see the full functions.mk for documentation and many more 
# useful functions.
#
# Copyright 2003-2014 Matt T. Yourst <yourst@yourst.com>
# License: GNU General Public License (GPL) version 2 or above
#

ifndef __FUNCTIONS_MK__
__FUNCTIONS_MK__ := 1

MAKEFLAGS := -r -R 
.SHELLFLAGS := -o pipefail -e -c

NULL :=
SPACE := ${NULL} 
TAB := ${NULL}	
EQUALS := ${NULL}=
COMMA := ${NULL},
COLON := ${NULL}:
DOUBLE_COLON := ${COLON}${COLON}
POUND := ${NULL}\#
SYMSYM := ${NULL}$$
LEFT_PAREN := (
RIGHT_PAREN := )
LEFT_BRACKET := {
RIGHT_BRACKET := }

# The script interpreter meta-comment: #!/path/to/interpreter...
SHEBANG := ${POUND}\!

define NL :=
${NULL}

endef # NL

SPACER := ${NULL}${SPACE}${SPACE}

path_exists ?= $(wildcard ${1})
file_exists ?= $(path_exists)
file_missing ?= $(if $(call path_exists,${1}),,${1})
create_dir_list ?= $(if ${1},$(shell mkdir -p ${1} >&/dev/null))
mkdir = $(value create_dir_list)
dir_exists = $(call path_exists,${1}/)

define ensure_dir_exists
$(if $(call dir_exists,${1}),,$(call create_dir_list,${1}))
endef # ensure_dir_exists

existing_dirs ?= $(foreach d,${1},$(if $(call dir_exists,${d}),${d},))
missing_dirs ?= $(foreach d,${1},$(if $(call dir_exists,${d}),,${d}))
ensure_dirs_exist ?= $(call create_dir_list,$(call missing_dirs,${1}))
remove_dir_list ?= $(if ${1},$(shell rmdir -f ${1}))
remove_dir ?= $(call remove_dir_list,${1})

include_file ?= $(eval include ${1})

read_file ?= $(shell cat ${1})

define __find_file_in_directory_list ?=
$(if ${2},$(or $(realpath $(firstword ${2})/${1}),$(call __find_file_in_directory_list,${1},$(wordlist 2,$(words ${2}),${2}))))
endef # __find_file_in_directory_list

define find_file_in_directory_list
$(strip $(or ${pathcache_${3}[${1}]},$(eval pathcache_${3}[${1}] := $$(or $$(call __find_file_in_directory_list,${1},${2}),!))$(filter-out !,${pathcache_${3}[${1}]})))
endef

define find_file_in_directory_list_named
$(call find_file_in_directory_list,${1},${${2}},${2})
endef # find_file_in_directory_list_named

define find_in_path
$(call find_file_in_directory_list,${1},$(subst :,${SPACE},${PATH}),PATH)
endef # find_in_path

is_sym_link ?= $(filter-out $(realpath ${1}),$(abspath $(realpath $(dir ${1}))/$(notdir ${1})))
not_sym_link ?= $(filter $(realpath ${1}),$(abspath $(realpath $(dir ${1}))/$(notdir ${1})))
is_dir_but_not_sym_link_to_dir ?= $(and $(realpath ${1}/),$(filter $(realpath ${1}),$(abspath $(realpath $(dir ${1}))/$(notdir ${1}))))
create_sym_link ?= $(shell ln -s -f -n ${1} ${2})

define __find_files_recursively
$(if $(wildcard ${1}/.),$(foreach f,$(wildcard ${1}/*),$(call __find_files_recursively,${f},${2})),$(filter ${2},${1}) )
endef # __find_files_recursively

define __find_dirs_recursively
$(if $(wildcard ${1}/.),$(filter ${2},${1}) $(foreach f,$(wildcard ${1}/*),$(call __find_dirs_recursively,${f},${2})))
endef # __find_dirs_recursively

define __find_files_and_dirs_recursively
$(filter ${2},${1}) $(if $(wildcard ${1}/.),$(foreach f,$(wildcard ${1}/*),$(call __find_files_and_dirs_recursively,${f},${2})))
endef # __find_files_and_dirs_recursively

# __find_generic = $(sort $(foreach f,${1},$(call ${3},${f},$(subst *,%,$(or ${2},*)))))

find_files_recursively = $(sort $(foreach f,${1},$(call __find_files_recursively,${f},$(subst *,%,$(or ${2},*)))))
find_dirs_recursively = $(sort $(foreach f,${1},$(call __find_dirs_recursively,${f},$(subst *,%,$(or ${2},*)))))
find_files_and_dirs_recursively = $(sort $(foreach f,${1},$(call __find_files_and_dirs_recursively,${f},$(subst *,%,$(or ${2},*)))))

find_files_containing_regexp ?= $(shell /usr/bin/grep -P -l -d skip ${1} ${2})
find_scripts_handled_by_interpreter ?= $(call find_files_containing_regexp,'^${SHEBANG}(?:/[^/]+)*/${1}',${2})

filename_to_symbol = $(subst /,@,$(subst -,_,$(subst .,_,${1})))
define filename_to_make_variable
$(subst ${SPACE},@S,$(subst %,@P,$(subst @,@A,$(subst ${COMMA},@M,$(subst =,@E,$(subst \#,@N,$(subst :,@C,$(subst /,@D,${1}))))))))
endef # filename_to_make_variable

define multi_pat_subst
$(if ${2},$(call multi_pat_subst,$(patsubst $(firstword ${2}),$(wordlist 2,2,${2}),${1}),$(wordlist 3,1000,${2})),${1})
endef # multi_pat_subst

suffixes ?= $(patsubst $(firstword $(subst .,${SPACE},${1}))%,%,${1})
final_suffix ?= $(lastword $(subst .,${SPACE},${1}))
strip_all_suffixes ?= $(firstword $(subst .,${SPACE},${1}))
strip_all_suffixes_and_dirs ?= $(call strip_all_suffixes,$(notdir ${1}))

define summarize_paths
$(foreach d,$(sort $(patsubst %/,%,$(dir ${1}))),${d}/{$(notdir $(filter ${d}/%,${1}))})
endef # summarize_paths

define summarize_paths_across_lines
$(foreach d,$(sort $(patsubst %/,%,$(dir ${1}))),${2}${d}/{ $(notdir $(filter ${d}/%,${1})) }${NL})
endef # summarize_paths_across_lines

shell_output_lines = $(subst ${TAB},${NL},$(shell { ${1} } | tr '\n' '\t'))
eval_shell_output_lines = $(eval $(subst ${TAB},${NL},$(shell { ${1} } | tr '\n' '\t')))

endif # ! __FUNCTIONS_MK__
