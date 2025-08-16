include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(cuda_hip_test_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(cuda_hip_test_setup_options)
  option(cuda_hip_test_ENABLE_HARDENING "Enable hardening" ON)
  option(cuda_hip_test_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cuda_hip_test_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cuda_hip_test_ENABLE_HARDENING
    OFF)

  cuda_hip_test_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cuda_hip_test_PACKAGING_MAINTAINER_MODE)
    option(cuda_hip_test_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cuda_hip_test_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cuda_hip_test_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cuda_hip_test_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cuda_hip_test_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cuda_hip_test_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cuda_hip_test_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cuda_hip_test_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cuda_hip_test_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cuda_hip_test_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cuda_hip_test_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cuda_hip_test_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cuda_hip_test_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cuda_hip_test_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cuda_hip_test_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cuda_hip_test_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cuda_hip_test_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cuda_hip_test_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cuda_hip_test_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cuda_hip_test_ENABLE_IPO
      cuda_hip_test_WARNINGS_AS_ERRORS
      cuda_hip_test_ENABLE_USER_LINKER
      cuda_hip_test_ENABLE_SANITIZER_ADDRESS
      cuda_hip_test_ENABLE_SANITIZER_LEAK
      cuda_hip_test_ENABLE_SANITIZER_UNDEFINED
      cuda_hip_test_ENABLE_SANITIZER_THREAD
      cuda_hip_test_ENABLE_SANITIZER_MEMORY
      cuda_hip_test_ENABLE_UNITY_BUILD
      cuda_hip_test_ENABLE_CLANG_TIDY
      cuda_hip_test_ENABLE_CPPCHECK
      cuda_hip_test_ENABLE_COVERAGE
      cuda_hip_test_ENABLE_PCH
      cuda_hip_test_ENABLE_CACHE)
  endif()

  cuda_hip_test_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cuda_hip_test_ENABLE_SANITIZER_ADDRESS OR cuda_hip_test_ENABLE_SANITIZER_THREAD OR cuda_hip_test_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cuda_hip_test_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cuda_hip_test_global_options)
  if(cuda_hip_test_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cuda_hip_test_enable_ipo()
  endif()

  cuda_hip_test_supports_sanitizers()

  if(cuda_hip_test_ENABLE_HARDENING AND cuda_hip_test_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cuda_hip_test_ENABLE_SANITIZER_UNDEFINED
       OR cuda_hip_test_ENABLE_SANITIZER_ADDRESS
       OR cuda_hip_test_ENABLE_SANITIZER_THREAD
       OR cuda_hip_test_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cuda_hip_test_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cuda_hip_test_ENABLE_SANITIZER_UNDEFINED}")
    cuda_hip_test_enable_hardening(cuda_hip_test_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cuda_hip_test_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cuda_hip_test_warnings INTERFACE)
  add_library(cuda_hip_test_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cuda_hip_test_set_project_warnings(
    cuda_hip_test_warnings
    ${cuda_hip_test_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cuda_hip_test_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    cuda_hip_test_configure_linker(cuda_hip_test_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cuda_hip_test_enable_sanitizers(
    cuda_hip_test_options
    ${cuda_hip_test_ENABLE_SANITIZER_ADDRESS}
    ${cuda_hip_test_ENABLE_SANITIZER_LEAK}
    ${cuda_hip_test_ENABLE_SANITIZER_UNDEFINED}
    ${cuda_hip_test_ENABLE_SANITIZER_THREAD}
    ${cuda_hip_test_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cuda_hip_test_options PROPERTIES UNITY_BUILD ${cuda_hip_test_ENABLE_UNITY_BUILD})

  if(cuda_hip_test_ENABLE_PCH)
    target_precompile_headers(
      cuda_hip_test_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cuda_hip_test_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cuda_hip_test_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cuda_hip_test_ENABLE_CLANG_TIDY)
    cuda_hip_test_enable_clang_tidy(cuda_hip_test_options ${cuda_hip_test_WARNINGS_AS_ERRORS})
  endif()

  if(cuda_hip_test_ENABLE_CPPCHECK)
    cuda_hip_test_enable_cppcheck(${cuda_hip_test_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cuda_hip_test_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cuda_hip_test_enable_coverage(cuda_hip_test_options)
  endif()

  if(cuda_hip_test_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cuda_hip_test_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cuda_hip_test_ENABLE_HARDENING AND NOT cuda_hip_test_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cuda_hip_test_ENABLE_SANITIZER_UNDEFINED
       OR cuda_hip_test_ENABLE_SANITIZER_ADDRESS
       OR cuda_hip_test_ENABLE_SANITIZER_THREAD
       OR cuda_hip_test_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cuda_hip_test_enable_hardening(cuda_hip_test_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
