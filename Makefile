.DEFAULT_GOAL := help

PROJECTS := mp0 mp1 mp2 mp3 mp4 mp5 mp6 mp7 mp8
PROJECT_GOALS := $(filter $(PROJECTS),$(MAKECMDGOALS))
ACTION_GOALS := $(filter build run,$(MAKECMDGOALS))

NVCC ?= nvcc
CUDAFLAGS ?= -std=c++11 -O2 -rdc=true
WB_ROOT ?= third_party/libwb
WB_REPO ?= https://github.com/abduld/libwb.git
WB_HEADER := $(WB_ROOT)/wb.h
WB_LIB := $(WB_ROOT)/lib/libwb.so
WB_PATCH_STAMP := $(WB_ROOT)/.pmpp-patched

ifneq ($(ACTION_GOALS),)
  ifeq ($(words $(PROJECT_GOALS)),0)
    $(error Missing project. Try: make run mp0)
  endif
  ifneq ($(words $(PROJECT_GOALS)),1)
    $(error Choose exactly one project: $(PROJECTS))
  endif
endif

PROJECT := $(firstword $(PROJECT_GOALS))
PROJECT_DIR := $(shell echo $(PROJECT) | tr a-z A-Z)
PROGRAM_NAME := $(if $(filter mp0,$(PROJECT)),solution,template)
OBJECT := $(PROJECT_DIR)/template.o
PROGRAM := $(PROJECT_DIR)/$(PROGRAM_NAME)

# The project name is the second command-line goal in, for example,
# "make run mp0". These no-op targets make that interface valid GNU Make.
.PHONY: $(PROJECTS)
$(PROJECTS):
	@:

.PHONY: help list setup build run

help:
	@echo "Usage: make <build|run> <project>"
	@echo ""
	@echo "  make build mp0    Compile MP0 locally"
	@echo "  make run mp0      Compile and run MP0 locally"
	@echo "  make run mp8      Compile and run all MP8 datasets"
	@echo "  make list         Show available projects"
	@echo ""
	@echo "The first build downloads libwb into third_party/libwb."

list:
	@echo "Available projects: $(PROJECTS)"

setup: $(WB_LIB)

$(WB_HEADER):
	@mkdir -p $(dir $(WB_ROOT))
	git clone --depth 1 $(WB_REPO) $(WB_ROOT)

$(WB_PATCH_STAMP): $(WB_HEADER) patches/libwb-gcc.patch
	cd $(WB_ROOT) && git apply ../../patches/libwb-gcc.patch
	@touch $@

$(WB_LIB): $(WB_PATCH_STAMP)
	$(MAKE) -C $(WB_ROOT) libwb.so

$(OBJECT): $(PROJECT_DIR)/template.cu $(WB_HEADER)
	$(NVCC) $(CUDAFLAGS) -I$(WB_ROOT) -c $< -o $@

$(PROGRAM): $(OBJECT) $(WB_LIB)
	$(NVCC) $(CUDAFLAGS) -o $@ $< -L$(dir $(WB_LIB)) -lwb \
		-Xlinker -rpath -Xlinker $(abspath $(dir $(WB_LIB)))

build: $(PROGRAM)

run: $(PROGRAM)
ifeq ($(PROJECT),mp0)
	cd $(PROJECT_DIR) && ./$(PROGRAM_NAME)
else
	cd $(PROJECT_DIR) && bash run_datasets
endif
