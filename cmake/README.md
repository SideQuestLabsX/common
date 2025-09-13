# CMake Modules

These modules are simple `.cmake` files designed to be included in any CMake project. They avoid global side effects and allow you to enable specific behaviors per target or across a directory.

This guide will show you how to make these modules available in your build and how to activate them. You can either use `FetchContent` to download the modules or add them directly to your source tree.

## Option 1: Using FetchContent

With `FetchContent`, you can download the repository during configuration and add its `cmake/` folder to the module path.

```cmake
include(FetchContent)

FetchContent_Declare(common_resources
  GIT_REPOSITORY https://github.com/SideQuestLabsX/common.git
  GIT_TAG        main) # you can also use tag or commit
FetchContent_MakeAvailable(common_resources)

list(APPEND CMAKE_MODULE_PATH "${common_resources_SOURCE_DIR}/cmake")
include(<ModuleName>)
```

## Option 2: Files already in your source tree

If the `.cmake` files are present in your source tree, you can skip `FetchContent`

```cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake") # Use the actual path to your .cmake files
include(<ModuleName>)
```

## Enabling a module after inclusion

Once you've included a module with `include(<ModuleName>)`, you can choose where and how to apply its behavior. There are two main options:

You have two options.

**1. Per target**  
To apply the module to a specific target, link the module’s `INTERFACE` target to your CMake target. This will restrict the module's effect to that particular target.

```cmake
include(<ModuleName>)
target_link_libraries(MyTarget PRIVATE <ModuleTargetFromModule>)
```

**2. Global in a directory**  
If you want to apply the module's settings to all targets in the current directory (and below), you can use `add_compile_options()` and `add_link_options()`, along with the variables exported by the module. The module's header will specify the variable names.

```cmake
include(<ModuleName>)

add_compile_options(
  $<$<COMPILE_LANGUAGE:C>:${<ModuleExportedCOptionsVar>}>
  $<$<COMPILE_LANGUAGE:CXX>:${<ModuleExportedCxxOptionsVar>}>
)

# If the module also exports link items, apply them here
add_link_options(${<ModuleExportedLinkItemsVar>})
```
