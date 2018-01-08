#!/bin/bash

# Run this as
# % . ./tau.sh
# the first time to export the papi path.

# Run app as
# % tau numactl -C 0 -- ./tinymembench

rm -rf ./.tau

# Configure your project...
APPNAME=tinymembench

# papi built with git checkout of libpfm4
PAPI_ROOT=${HOME}/devel/packages/spack/opt/spack/linux-rhel7-x86_64/gcc-6.1.0/papi-master-ashjfzmpqkbxa6hudklfxji7oybhufb6
export PATH=${PAPI_ROOT}/bin:${PATH}

# initialize tau commander project
tau init --application-name $APPNAME --target-name centennial --mpi F --papi=${PAPI_ROOT} --tau nightly
#--openmp

tau select profile

# debugging
#tau measurement edit profile --keep-inst-files

tau measurement edit profile --source-inst manual --compiler-inst never \
--metrics \
PAPI_NATIVE:bdx_unc_imc0::UNC_M_CAS_COUNT:RD:cpu=0,\
PAPI_NATIVE:bdx_unc_imc0::UNC_M_CAS_COUNT:WR:cpu=0,\
PAPI_NATIVE:bdx_unc_imc1::UNC_M_CAS_COUNT:RD:cpu=0,\
PAPI_NATIVE:bdx_unc_imc1::UNC_M_CAS_COUNT:WR:cpu=0,\
PAPI_NATIVE:bdx_unc_imc4::UNC_M_CAS_COUNT:RD:cpu=0,\
PAPI_NATIVE:bdx_unc_imc4::UNC_M_CAS_COUNT:WR:cpu=0,\
PAPI_NATIVE:bdx_unc_imc5::UNC_M_CAS_COUNT:RD:cpu=0,\
PAPI_NATIVE:bdx_unc_imc5::UNC_M_CAS_COUNT:WR:cpu=0

# run complains about incompatible papi metrics, but generates results.

# use this in paraprof derived metric for bandwidth
#64*("PAPI_NATIVE:bdx_unc_imc0::UNC_M_CAS_COUNT:RD:cpu=0"+"PAPI_NATIVE:bdx_unc_imc0::UNC_M_CAS_COUNT:WR:cpu=0"+"PAPI_NATIVE:bdx_unc_imc1::UNC_M_CAS_COUNT:RD:cpu=0"+"PAPI_NATIVE:bdx_unc_imc1::UNC_M_CAS_COUNT:WR:cpu=0"+"PAPI_NATIVE:bdx_unc_imc4::UNC_M_CAS_COUNT:RD:cpu=0"+"PAPI_NATIVE:bdx_unc_imc4::UNC_M_CAS_COUNT:WR:cpu=0"+"PAPI_NATIVE:bdx_unc_imc5::UNC_M_CAS_COUNT:RD:cpu=0"+"PAPI_NATIVE:bdx_unc_imc5::UNC_M_CAS_COUNT:WR:cpu=0")/"TIME"

# NB: Using that formula accounts for the magical million that paraprof
# silently puts into the denominator. They are working on a fix for that, and
# when it is fixed one will need to put their own 1e6.


# Set up measurements of stalls to use formulas from Molka, et al.
tau measurement copy profile mem_bnd_stall_cycs
tau select mem_bnd_stall_cycs
tau measurement edit mem_bnd_stall_cycs \
--metrics \
PAPI_NATIVE:CPU_CLK_UNHALTED:cpu=0,\
PAPI_NATIVE:CYCLE_ACTIVITY:CYCLES_NO_EXECUTE:cpu=0,\
PAPI_NATIVE:RESOURCE_STALLS:SB:cpu=0,\
PAPI_NATIVE:CYCLE_ACTIVITY:STALLS_L1D_PENDING:cpu=0

tau measurement copy profile bw_lat_stall_cycs
tau select bw_lat_stall_cycs
tau measurement edit bw_lat_stall_cycs \
--metrics \
PAPI_NATIVE:RESOURCE_STALLS:SB:cpu=0,\
PAPI_NATIVE:CYCLE_ACTIVITY:STALLS_L1D_PENDING:cpu=0,\
PAPI_NATIVE:L1D_PEND_MISS:FB_FULL:cpu=0,\
PAPI_NATIVE:OFFCORE_REQUESTS_BUFFER:SQ_FULL:cpu=0

# From Molka, et al.
# Active cycles: 
#         => CPU_CLK_UNHALTED
#   Productive cycles:
#         => CPU_CLK_UNHALTED - CYCLE_ACTIVITY:CYCLES_NO_EXECUTE
#   Stall cycles:
#         => CYCLE_ACTIVITY:CYCLES_NO_EXECUTE
#     Memory bound stall cycles:
#         => max(RESOURCE_STALLS:SB, CYCLE_ACTIVITY:STALLS_L1D_PENDING)
#       Bandwidth bound stall cycles:
#         => max(RESOURCE_STALLS:SB, L1D_PEND_MISS:FB_FULL
#                + OFFCORE_REQUESTS_BUFFER:SQ_FULL)
#       Latency bound stall cycles:
#         => Memory bound cycles - Bandwidth bound cycles
#     Other stall reason cycles:
#         => Stall cycles - Memory bound stall cycles


# nbits = 21 // L3
# CPU_CLK_UNHALTED :   1.48e10
# CYCLES_NO_EXECUTE:   1.11e10 (75% cycles are stalled)
# RESOURCE_STALLS:SB:  7.74e 3
# STALLS_L1D_PENDING:  7.97e 9 (72% of stalled cycles are memory bound)
# FB_FULL + SQ_FULL:   1.58e 2
# max(SB, FB_FULL + SQ_FULL): 7.7e3 (number of cycles bandwidth bound)
# latency_bound = memory bound - bandwidth bound = 7.97e9 - 7.7e3 ~8e9
