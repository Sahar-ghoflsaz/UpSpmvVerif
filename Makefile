DPU_DIR := dpu
HOST_DIR := host
BUILDDIR ?= bin
TYPE ?= INT8
TYPEEN ?= INT8
NR_TASKLETS ?= 16
NR_DPUS ?= 64
BLNC_TSKLT_ROW ?= 0 # Load-balance rows across tasklets
BLNC_TSKLT_NNZ ?= 1 # Load-balance nnzs across tasklets
CG_TRANS ?= 0 # Coarse-grained data transfers
FG_TRANS ?= 1 # Fine-grained data transfers in the output vector


define conf_filename
	${BUILDDIR}/.NR_DPUS_$(1)_NR_TASKLETS_$(2)_TYPE_$(3).conf
endef
CONF := $(call conf_filename,${NR_DPUS},${NR_TASKLETS},${TYPE})

HOST_TARGET := ${BUILDDIR}/spmv_host
DPU_TARGET := ${BUILDDIR}/spmv_dpu

COMMON_INCLUDES := support
HOST_SOURCES := $(wildcard ${HOST_DIR}/*.c)
DPU_SOURCES := $(wildcard ${DPU_DIR}/*.c)

.PHONY: all clean test

__dirs := $(shell mkdir -p ${BUILDDIR})

##COMMON_FLAGS := -Wall -Wextra -g -I${COMMON_INCLUDES} 
COMMON_FLAGS := -g -I${COMMON_INCLUDES} 
HOST_FLAGS := ${COMMON_FLAGS} -std=c11 -O3 `dpu-pkg-config --cflags --libs dpu` -D${TYPE} -DNR_TASKLETS=${NR_TASKLETS} -DNR_DPUS=${NR_DPUS} -DEN_TYPE=${TYPEEN} -DBLNC_TSKLT_ROW=${BLNC_TSKLT_ROW} -DBLNC_TSKLT_NNZ=${BLNC_TSKLT_NNZ}  -DCG_TRANS=${CG_TRANS} -DFG_TRANS=${FG_TRANS} -fopenmp -lm
DPU_FLAGS := ${COMMON_FLAGS} -O2 -DNR_TASKLETS=${NR_TASKLETS} -D${TYPE} 

all: ${HOST_TARGET} ${DPU_TARGET}

${CONF}:
	$(RM) $(call conf_filename,*,*)
	touch ${CONF}

${HOST_TARGET}: ${HOST_SOURCES} ${COMMON_INCLUDES} ${CONF}
	$(CC) -o $@ ${HOST_SOURCES} ${HOST_FLAGS}

${DPU_TARGET}: ${DPU_SOURCES} ${COMMON_INCLUDES} ${CONF}
	dpu-upmem-dpurte-clang ${DPU_FLAGS} -o $@ ${DPU_SOURCES} 

clean:
	$(RM) -r $(BUILDDIR)

test: all
	./${HOST_TARGET}

