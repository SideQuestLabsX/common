# StaticRuntimes.cmake
#
# Purpose
#   Prefer static linkage of language runtimes and low-level support libraries
#   where it is safe. Keep system libraries dynamic unless explicitly overridden.
#
# What this module does (by toolchain)
#   • MSVC or clang-cl (MSVC frontend)
#       Builds with the static MSVC runtime (/MT or /MTd).
#   • clang++ GNU driver with the MSVC toolchain
#       Forces the static MSVC CRT at compile time and forwards MSVC link
#       directives to lld-link so the static CRTs are selected even if the
#       driver strips default libraries. Handles Release and Debug.
#   • MinGW (GCC or clang targeting MinGW)
#       Links libstdc++ and libgcc statically and forces winpthread to be
#       pulled in completely. UCRT remains dynamic here by design.
#   • Linux (glibc)
#       By default, does nothing.
#       You can opt into linking libstdc++ and libgcc statically.
#   • Linux (musl)
#       Uses a fully static link.
#
# Options (set before include)
#   SQ_SRT_LINUX_STATIC  Bool, default OFF
#
# After including this file, you can enable it per-target or globally.
#
#   Per target
#     target_link_libraries(my_target PRIVATE SQ_SRT)
#
#   Global
#     add_compile_options(
#       $<$<COMPILE_LANGUAGE:C>:${SQ_SRT_COMPILE_FLAGS_C}>
#       $<$<COMPILE_LANGUAGE:CXX>:${SQ_SRT_COMPILE_FLAGS_CXX}>
#     )
#     add_link_options(${SQ_SRT_LINK_ITEMS})
#
# Exports
#   SQ_SRT_COMPILE_FLAGS_C    : list of compile flags for C
#   SQ_SRT_COMPILE_FLAGS_CXX  : list of compile flags for C++
#   SQ_SRT_LINK_ITEMS         : list of link flags and libraries
#   SQ_SRT                    : INTERFACE target encapsulating these flags


cmake_policy(PUSH)

set(SQ_SRT_COMPILE_FLAGS_C "")
set(SQ_SRT_COMPILE_FLAGS_CXX "")
set(SQ_SRT_LINK_ITEMS "")

if(NOT DEFINED SQ_SRT_LINUX_STATIC)
  set(SQ_SRT_LINUX_STATIC OFF)
endif()

# Detect platform and frontends
set(_IS_WINDOWS FALSE)
if(WIN32)
  set(_IS_WINDOWS TRUE)
endif()
set(_IS_LINUX FALSE)
if(UNIX AND NOT APPLE)
  set(_IS_LINUX TRUE)
endif()


set(_CXX_ID "${CMAKE_CXX_COMPILER_ID}")
get_property(_HAS_FE_VAR CACHE CMAKE_CXX_COMPILER_FRONTEND_VARIANT PROPERTY TYPE)
if(_HAS_FE_VAR)
  set(_FE "${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}") # "MSVC" or "GNU" for clang
else()
  set(_FE "")
endif()

# MinGW check
set(_IS_MINGW FALSE)
if(MINGW OR CMAKE_CXX_COMPILER_TARGET MATCHES "mingw")
  set(_IS_MINGW TRUE)
endif()

# Populate per-toolchain flags
if(_IS_WINDOWS AND (MSVC OR (_CXX_ID STREQUAL "Clang" AND _FE STREQUAL "MSVC")))
  # MSVC or clang-cl: static runtime via property when available, otherwise flags
  if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.15")
    if(NOT DEFINED CMAKE_MSVC_RUNTIME_LIBRARY)
      set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
  else()
    list(APPEND SQ_SRT_COMPILE_FLAGS_C  "/MT$<$<CONFIG:Debug>:d>")
    list(APPEND SQ_SRT_COMPILE_FLAGS_CXX "/MT$<$<CONFIG:Debug>:d>")
  endif()

elseif(_IS_WINDOWS AND _CXX_ID STREQUAL "Clang" AND (NOT _IS_MINGW))
  # clang++ GNU driver + MSVC toolchain
  # Compile: select static CRT and sanitize macros so headers pick static paths
  list(APPEND SQ_SRT_COMPILE_FLAGS_CXX "-fms-runtime-lib=static" "-U_DLL" "-U_MT" "-D_MT")
  list(APPEND SQ_SRT_COMPILE_FLAGS_C   "-fms-runtime-lib=static" "-U_DLL" "-U_MT" "-D_MT")
  # Link: pass MSVC link directives to lld-link through -Wl,. Handle Debug vs Release.
  # Block DLL CRTs (both release and debug import libs) then add static CRTs per config.
  list(APPEND SQ_SRT_LINK_ITEMS
    "-Wl,/NODEFAULTLIB:msvcrt"
    "-Wl,/NODEFAULTLIB:msvcrtd"
    "-Wl,/NODEFAULTLIB:ucrt"
    "-Wl,/NODEFAULTLIB:ucrtd"
    "-Wl,/NODEFAULTLIB:vcruntime"
    "-Wl,/NODEFAULTLIB:vcruntimed"
    "-Wl,/NODEFAULTLIB:msvcprt"
    "-Wl,/NODEFAULTLIB:msvcprtd"
    # Release static CRT set
    "$<$<NOT:$<CONFIG:Debug>>:-Wl,/DEFAULTLIB:libucrt>"
    "$<$<NOT:$<CONFIG:Debug>>:-Wl,/DEFAULTLIB:libvcruntime>"
    "$<$<NOT:$<CONFIG:Debug>>:-Wl,/DEFAULTLIB:libcmt>"
    "$<$<NOT:$<CONFIG:Debug>>:-Wl,/DEFAULTLIB:libcpmt>"
    # Debug static CRT set
    "$<$<CONFIG:Debug>:-Wl,/DEFAULTLIB:libucrtd>"
    "$<$<CONFIG:Debug>:-Wl,/DEFAULTLIB:libvcruntimed>"
    "$<$<CONFIG:Debug>:-Wl,/DEFAULTLIB:libcmtd>"
    "$<$<CONFIG:Debug>:-Wl,/DEFAULTLIB:libcpmtd>"
    # Common
    "-Wl,/DEFAULTLIB:oldnames"
  )

elseif(_IS_WINDOWS AND (_IS_MINGW OR _CXX_ID STREQUAL "GNU"))
  # MinGW: static libstdc++/libgcc and fully pulled-in winpthread
  list(APPEND SQ_SRT_LINK_ITEMS
    "-static-libstdc++" "-static-libgcc"
    "-Wl,-Bstatic,--whole-archive" "-lwinpthread" "-Wl,-Bdynamic,--no-whole-archive"
  )

elseif(_IS_LINUX)
  # Detect musl using a C++ compile test on <features.h>.
  include(CheckCXXSourceCompiles)
  set(CMAKE_REQUIRED_QUIET TRUE)
  unset(_SRT_MUSL CACHE)
  check_cxx_source_compiles("
    #include <features.h>
      #if defined(__MUSL__)
      int main(){return 0;}
      #else
      #error not musl
      #endif
    " _SRT_MUSL)

  if(_SRT_MUSL)
    list(APPEND SQ_SRT_LINK_ITEMS "-static")
  else()
    # Assume glibc or other libcs that behave like glibc
    if(SQ_SRT_LINUX_STATIC)
      list(APPEND SQ_SRT_LINK_ITEMS "-static-libstdc++" "-static-libgcc")
    endif()
  endif()
endif()

# INTERFACE target
if(NOT TARGET SQ_SRT)
  add_library(SQ_SRT INTERFACE)
  target_compile_options(SQ_SRT INTERFACE
    $<$<COMPILE_LANGUAGE:C>:${SQ_SRT_COMPILE_FLAGS_C}>
    $<$<COMPILE_LANGUAGE:CXX>:${SQ_SRT_COMPILE_FLAGS_CXX}>
  )
  if(POLICY CMP0065)
    cmake_policy(SET CMP0065 NEW)
  endif()
  if(COMMAND target_link_options)
    target_link_options(SQ_SRT INTERFACE ${SQ_SRT_LINK_ITEMS})
  else()
    set_property(TARGET SQ_SRT PROPERTY INTERFACE_LINK_LIBRARIES "${SQ_SRT_LINK_ITEMS}")
  endif()
endif()

cmake_policy(POP)
