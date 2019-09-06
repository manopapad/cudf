# Copyright (c) 2019, NVIDIA CORPORATION.

# cython: profile=False
# distutils: language = c++
# cython: embedsignature = True
# cython: language_level = 3

from cudf._lib.cudf cimport *
from cudf._lib.cudf import *
from cudf._lib.includes.avro cimport reader as avro_reader
from cudf._lib.includes.avro cimport reader_options as avro_reader_options
from cudf._lib.utils cimport *
from cudf._lib.utils import *
from libc.stdlib cimport free
from libcpp.vector cimport vector
from libcpp.memory cimport unique_ptr

from cudf.utils import ioutils
from cudf._lib.nvtx import nvtx_range_push, nvtx_range_pop

from io import BytesIO
import errno
import os


cpdef read_avro(filepath_or_buffer, columns=None, skip_rows=None,
                num_rows=None):
    """
    Cython function to call into libcudf API, see `read_avro`.

    See Also
    --------
    cudf.io.avro.read_avro
    """

    # Setup reader options
    cdef avro_reader_options options = avro_reader_options()
    for col in columns or []:
        options.columns.push_back(str(col).encode())

    # Create reader from source
    cdef unique_ptr[avro_reader] reader
    cdef const unsigned char[:] buffer = None
    if isinstance(filepath_or_buffer, BytesIO):
        buffer = filepath_or_buffer.getbuffer()
    elif isinstance(filepath_or_buffer, bytes):
        buffer = filepath_or_buffer

    if buffer is not None:
        reader = unique_ptr[avro_reader](
            new avro_reader(<char *>&buffer[0], buffer.shape[0], options)
        )
    else:
        if not os.path.isfile(filepath_or_buffer):
            raise FileNotFoundError(
                errno.ENOENT, os.strerror(errno.ENOENT), filepath_or_buffer
            )
        reader = unique_ptr[avro_reader](
            new avro_reader(str(filepath_or_buffer).encode(), options)
        )

    # Read data into columns
    cdef cudf_table c_out_table
    if skip_rows is not None:
        c_out_table = reader.get().read_rows(
            skip_rows,
            num_rows if num_rows is not None else 0
        )
    elif num_rows is not None:
        c_out_table = reader.get().read_rows(
            skip_rows if skip_rows is not None else 0,
            num_rows
        )
    else:
        c_out_table = reader.get().read_all()

    return table_to_dataframe(&c_out_table)