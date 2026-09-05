#*****************************************************
#  GaleFuncs Add-In for LibreOffice Calc
#  Version 0.2.2
#  Rev. 5.09.2026

#  Author: Alexander Torubarov
#  Contact: runfla@yandex.com

#  Filename: galefuncs.py
#  Source Code: Python
#  Compatible: LibreOffice Calc x64 win10 26.2.3.2

#  Copyright (C) 2026 Alexander Torubarov
#  Licensed under the MIT License.
#  See the LICENSE file in the project root
#  or a copy available at https://opensource.org
#  for full license information.
#*****************************************************

import os
import sys
import ctypes
import uno
import unohelper
import locale
from addins import XGaleFuncs                      # addins is my unique identificator
from com.sun.star.sheet import XAddIn
from com.sun.star.lang import XLocalizable, XServiceName, Locale

class DataRec(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("DataType",  ctypes.c_int),        # 4 bytes
        ("AlignPad",  ctypes.c_int),        # 4 bytes
        ("AsSizeInt", ctypes.c_int64),      # 8 bytes
        ("AsDouble",  ctypes.c_double),     # 8 bytes
        ("AsPChar",   ctypes.c_void_p)      # 8 bytes pointer
    ]

lib = None

def arg_pack(args):
    return b'\x1c'.join(
        b'""' if cell is None or cell == "" or cell == () else
        (
            f'{int(cell)}'.encode('utf-8') if isinstance(cell, float) and cell.is_integer() else
            f'{cell}'.encode('utf-8')
        ) if isinstance(cell, (int, float)) else
        f'\x07{cell}\x07'.encode('utf-8')
        for row in args
        for cell in row
    )


#import uno
#from com.sun.star.table.CellContentType import EMPTY, VALUE, TEXT, FORMULA

#def get_clean_cell_value(cell):
#    cell_type = cell.getType()

    # 1. Если ячейка физически пустая — отдаем None (arg_pack сделает кавычки "")
#    if cell_type == EMPTY:
#        return None

    # 2. Если в ячейке текст — берем строку
#    elif cell_type == TEXT:
#        return cell.String

    # 3. Если в ячейке число — берем значение (здесь 0.0 будет настоящим нулем)
#    elif cell_type == VALUE:
#        return cell.Value

    # 4. Если в ячейке формула — проверяем, ЧТО она вернула (число или строку)
#    elif cell_type == FORMULA:
        # Если формула возвращает текст (например, пустую строку "")
#        if cell.String != "" and not cell.String.replace('.','',1).isdigit():
#            return cell.String
        # Иначе берем числовое значение формулы
#        return cell.Value

#    return None



def call_runfla(func_id, flat_args):
    global lib

    try:
        if lib is None:
            cx = uno.getComponentContext()
            pip = cx.getByName("/singletons/com.sun.star.deployment.PackageInformationProvider")
            oxt_url = pip.getPackageLocation("addin.runfla.galefuncs")
            CURRENT_DIR = uno.fileUrlToSystemPath(oxt_url)

            if sys.platform == "win32":
                LIB_NAME = "galefuncs64.dll"
            else:
                LIB_NAME = "galefuncs64.so"

            LIB_PATH = os.path.join(CURRENT_DIR, LIB_NAME)

            if not os.path.exists(LIB_PATH):
                raise RuntimeError(f"Library {LIB_NAME} is not found at {LIB_PATH}")

            lib = ctypes.CDLL(LIB_PATH)

            lib.gale_str_py.argtypes = [ctypes.c_char_p, ctypes.POINTER(DataRec)]
            lib.gale_str_py.restype = ctypes.c_int

            lib.gale_val_py.argtypes = [ctypes.c_char_p, ctypes.POINTER(DataRec)]
            lib.gale_val_py.restype = ctypes.c_int

            lib.gale_free_py.argtypes = [ctypes.c_void_p]
            lib.gale_free_py.restype = ctypes.c_int

        # mapping function ID to the specific library method
        if func_id == 0:
            gale_func = lib.gale_str_py
        else:
            gale_func = lib.gale_val_py

        # create structure locally in thread, not globally
        local_result = DataRec()

        # calling the function and passing a pointer to the structure
        gale_func(arg_pack(flat_args), ctypes.byref(local_result))

        dtype = local_result.DataType

        if dtype == 1:
            return int(local_result.AsSizeInt)

        elif dtype == 2:
            return float(local_result.AsDouble)

        elif dtype == 3:
            result_str = ctypes.c_char_p(local_result.AsPChar).value.decode('utf-8')
            lib.gale_free_py(local_result.AsPChar)
            return result_str

        return ""

    except Exception as err:
        return f"GaleFuncs ERROR: {str(err)}"

class GaleFuncs(unohelper.Base, XGaleFuncs, XAddIn, XServiceName, XLocalizable):
    def __init__(self, ctx):
        self.ctx = ctx
        self.locale = Locale("en", "US", "")

    def getServiceName(self):
        return "com.sun.star.sheet.AddIn"

    def getImplementationName(self):
        return "addin.runfla.galefuncs"

    def setLocale(self, locale):
        self.locale = locale

    def getLocale(self):
        return self.locale

    def getProgrammaticFuntionName(self, aDisplayName):
        return aDisplayName

    def getDisplayFunctionName(self, aProgrammaticName):
        return aProgrammaticName

    def getFunctionDescription(self , aProgrammaticName):
        if aProgrammaticName == "galestr":
            return "Run the script and return a string with units"
        elif aProgrammaticName == "galeval":
            return "Run the script and return a value without units"
        return ""

    def getArgumentDescription(self, aProgrammaticFunctionName, nArgument):
        return "odd: <variable>, even: <value>, <script>"

    def getProgrammaticCategoryName(self, aProgrammaticFunctionName):
        return "Add-In"

    def getDisplayArgumentName(self, aProgrammaticFunctionName, nArgument):
        return "0"

    def galestr(self, *args):
        return call_runfla(0, args)

    def galeval(self, *args):
        return call_runfla(1, args)

