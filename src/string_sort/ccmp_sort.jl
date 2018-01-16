using BenchmarkTools

C_code = raw"""
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int compare(const void* l, const void* r){
    char* cl = *(char**)l+8;
    char* cr = *(char**)r+8;
    return strcmp(cl, cr);
}

void str_qsort(char **strings, size_t len) {  /* you need to pass len here */
    
    /* qsort(strings, len, sizeof(char*), (int (*)(void*, void*))strcmp); */
    qsort(strings, len, sizeof(char*), compare);
    
}   
"""

env_path = ""
str_qsort!(::Any) = warn("""
    Either you LD_LIBRARY_PATH environment variable is not defined or gcc is not installed on your computer.
    * Google "how to set environment variable" and set 'LD_LIBRARY_PATH' to a folder/path you have access to
    * On Windows install MinGW. For example from [this link](http://mingw-w64.org/doku.php/download) and 
    * add the path of the 'bin' folder to the environment variable PATH
    """)

const Clib = "str_qsort"

try
    env_path = ENV["LD_LIBRARY_PATH"]
    Clib = joinpath(env_path,"strqsort") # tempname()   # make a temporary file
    # compile to a shared library by piping C_code to gcc
    # (works only if you have gcc installed):
    try
        open(`gcc -fPIC -O3 -msse3 -xc -shared -o $(Clib * "." * Libdl.dlext) -`, "w") do f
            print(f, C_code) 
        end
        # define a Julia function that calls the C function:
        str_qsort!(X::Array{String}) = ccall(("str_qsort", Clib), Void, (Ptr{UInt64}, Cint), reinterpret(Ptr{UInt64}, pointer(X)), length(X))
    catch e
        warn("""
            Either you LD_LIBRARY_PATH environment variable is not defined or gcc is not installed on your computer.
            * Google "how to set environment variable" and set 'LD_LIBRARY_PATH' to a folder/path you have access to
            * On Windows install MinGW. For example from [this link](http://mingw-w64.org/doku.php/download) and 
            * add the path of the 'bin' folder to the environment variable PATH
            """)
    end
catch e
    try
        open(`gcc -fPIC -O3 -msse3 -xc -shared -o $(Clib * "." * Libdl.dlext) -`, "w") do f
            print(f, C_code) 
        end
        # define a Julia function that calls the C function:
        str_qsort!(X::Array{String}) = ccall(("str_qsort", Clib), Void, (Ptr{UInt64}, Cint), reinterpret(Ptr{UInt64}, pointer(X)), length(X))
    catch e
        warn("""
            gcc is not installed on your computer:
            * On Windows install MinGW. For example from [this link](http://mingw-w64.org/doku.php/download) and 
            * add the path of the 'bin' folder to the environment variable PATH
            """)
    end
    warn("""
    There is no environment variable 'LD_LIBRARY_PATH' defined. We require it to be able to compile the C sort for string sort.
    You have no access to the `str_qsort!` function
    """)
    str_qsort!(::Any) = warn("""
    Either you LD_LIBRARY_PATH environment variable is not defined or gcc is not installed on your computer.
    * Google "how to set environment variable" and set 'LD_LIBRARY_PATH' to a folder/path you have access to
    * On Windows install MinGW. For example from [this link](http://mingw-w64.org/doku.php/download) and 
    * add the path of the 'bin' folder to the environment variable PATH
    """)
end
