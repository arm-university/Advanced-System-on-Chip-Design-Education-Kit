# Copyright (c) 2007-2011 ARM, Inc.  All rights reserved.
#

QUIET ?= @
CPU ?= 4T
OPT_FOR ?= space
CODE_TYPE ?= arm
OPT_LEVEL ?= 2
DEBUG_FLAGS ?= -g
APP ?= app.axf

ifeq ($(QUIET),@)
PROGRESS = @echo Compiling $<...
endif

CC = armcc
ASM = armasm
LINK = armlink
SRC_DIR = src
LIB_SRC_DIR = ../ARM
OBJ_DIR = obj

ifeq ($(OS),Windows_NT)
RM_FILE = if exist $(1) del /q $(1)
RM_DIR = if exist $(1) rmdir /s /q $(1)
MK_DIR = mkdir
else
RM_FILE = /bin/rm -f $(1)
RM_DIR = /bin/rm -rf $(1)
MK_DIR = /bin/mkdir
endif

DEPEND_FLAGS = --depend=$@.d --depend_format=unix_escaped
CFLAGS = --$(CODE_TYPE) $(DEBUG_FLAGS) -O$(OPT_FOR) -O$(OPT_LEVEL) --cpu=$(CPU) $(DEFINES) $(INCLUDES) $(DEPEND_FLAGS) --no_depend_system_headers $(SUPPRESS)
AFLAGS = $(DEBUG_FLAGS) --cpu=$(CPU) --apcs=/interwork $(DEPEND_FLAGS) $(SUPPRESS)
LFLAGS = --scatter=scatter.scat --entry=Vectors --diag_suppress=6329

INCLUDES = -I$(SRC_DIR) -I$(LIB_SRC_DIR)

APP_C_SRC := $(wildcard $(SRC_DIR)/*.c)
APP_ASM_SRC := $(wildcard $(SRC_DIR)/*.s)
LIB_C_SRC := $(wildcard $(LIB_SRC_DIR)/*.c)
LIB_ASM_SRC := $(wildcard $(LIB_SRC_DIR)/*.s)
OBJ_FILES := $(APP_C_SRC:$(SRC_DIR)/%.c=$(OBJ_DIR)/%.o) \
             $(APP_ASM_SRC:$(SRC_DIR)/%.s=$(OBJ_DIR)/%.o) \
             $(LIB_C_SRC:$(LIB_SRC_DIR)/%.c=$(OBJ_DIR)/%.o) \
             $(LIB_ASM_SRC:$(LIB_SRC_DIR)/%.s=$(OBJ_DIR)/%.o)
DEP_FILES := $(OBJ_FILES:%=%.d)

VPATH = $(SRC_DIR):$(LIB_SRC_DIR)

.phony: all clean

all: $(APP)

$(APP): $(OBJ_DIR) $(OBJ_FILES) scatter.scat
	@echo Linking $@
	$(QUIET) $(LINK) $(LFLAGS) --output $@ $(OBJ_FILES)
	@echo Done.

clean:
	- $(call RM_DIR,$(OBJ_DIR))
	- $(call RM_FILE,$(APP))

$(OBJ_DIR):
	$(MK_DIR) $@

$(OBJ_DIR)/%.o : %.c makefile
	$(PROGRESS)
	$(QUIET) $(CC) $(CFLAGS) -c -o $@ $<

$(OBJ_DIR)/%.o : %.s makefile
	$(PROGRESS)
	$(QUIET) $(ASM) $(AFLAGS) -o $@ $<

-include $(DEP_FILES)
