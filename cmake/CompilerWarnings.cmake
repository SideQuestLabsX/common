# CompilerWarnings.cmake
#
# Purpose
#   Provide a consistent set of warning flags across compilers for safer builds.
#
# After including this file, you can enable it per-target or globally:
#
#   Per target
#     target_link_libraries(my_target PRIVATE SQ_CW)
#
#   Global
#     add_compile_options(
#       $<$<COMPILE_LANGUAGE:C>:${SQ_CW_COMPILE_OPTIONS_C}>
#       $<$<COMPILE_LANGUAGE:CXX>:${SQ_CW_COMPILE_OPTIONS_CXX}>
#     )
#
# Exports
#   SQ_CW_COMPILE_OPTIONS_C    : list of warning flags for C
#   SQ_CW_COMPILE_OPTIONS_CXX  : list of warning flags for C++
#   SQ_CW                      : INTERFACE target encapsulating these flags


cmake_policy(PUSH)

set(SQ_CW_COMPILE_OPTIONS_C "")
set(SQ_CW_COMPILE_OPTIONS_CXX "")

# Detect compiler IDs and frontend
set(_C_ID   "${CMAKE_C_COMPILER_ID}")
set(_CXX_ID "${CMAKE_CXX_COMPILER_ID}")
get_property(_HAS_FE_VAR CACHE CMAKE_CXX_COMPILER_FRONTEND_VARIANT PROPERTY TYPE)
if(_HAS_FE_VAR)
  set(_FE "${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}") # "MSVC" or "GNU" for clang
else()
  set(_FE "")
endif()

# MSVC (cl or clang-cl use MSVC flags)
if(MSVC OR (_CXX_ID STREQUAL "Clang" AND _FE STREQUAL "MSVC"))
  list(APPEND SQ_CW_COMPILE_OPTIONS_CXX
    "/W4" "/permissive-" "/sdl" "/utf-8"
    "/w14242" "/w14254" "/w14263" "/w14265" "/w14287" "/we4289" "/w14296"
    "/w14311" "/w14545" "/w14546" "/w14547" "/w14549" "/w14555" "/w14619"
    "/w14640" "/w14826" "/w14905" "/w14906" "/w14928"
  )
  list(APPEND SQ_CW_COMPILE_OPTIONS_C ${SQ_CW_COMPILE_OPTIONS_CXX})

# GNU-style frontends (GCC or clang++)
else()
  # Common baseline for both GCC and Clang
  set(_BASE
    "-Wall" "-Wextra" "-Wpedantic"
    "-Wshadow" "-Wconversion" "-Wsign-conversion"
    "-Wformat=2" "-Wunused" "-Wundef"
    "-Wnull-dereference" "-Wimplicit-fallthrough"
    "-Wdouble-promotion"
  )
  list(APPEND SQ_CW_COMPILE_OPTIONS_C ${_BASE})
  # C++ extras shared
  set(_CXX_SHARED
    "-Woverloaded-virtual" "-Wold-style-cast"
    "-Wmissing-noreturn" "-Wzero-as-null-pointer-constant"
    "-Wctad-maybe-unsupported"
  )
  list(APPEND SQ_CW_COMPILE_OPTIONS_CXX ${_BASE} ${_CXX_SHARED})

  # Clang-only extras (guard GCC-incompatible flags)
  if(_CXX_ID STREQUAL "Clang")
    list(APPEND SQ_CW_COMPILE_OPTIONS_CXX "-Wshorten-64-to-32")
  endif()

  # GCC extras
  if(_CXX_ID STREQUAL "GNU")
    list(APPEND SQ_CW_COMPILE_OPTIONS_CXX
      "-Wduplicated-cond" "-Wduplicated-branches" "-Wlogical-op" "-Wuseless-cast"
      "-Wmissing-declarations"
    )
    list(APPEND SQ_CW_COMPILE_OPTIONS_C "-Wmissing-declarations")
  endif()
endif()

# INTERFACE target
if(NOT TARGET SQ_CW)
  add_library(SQ_CW INTERFACE)
  target_compile_options(SQ_CW INTERFACE
    $<$<COMPILE_LANGUAGE:C>:${SQ_CW_COMPILE_OPTIONS_C}>
    $<$<COMPILE_LANGUAGE:CXX>:${SQ_CW_COMPILE_OPTIONS_CXX}>
  )
endif()

cmake_policy(POP)
