import os
import sys
import ctypes
import uno
import unohelper
from stormray import XElmoFire
from com.sun.star.sheet import XAddIn
from com.sun.star.lang import XLocalizable, XServiceName, Locale

class DataRec(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("DataType",  ctypes.c_int),        # 4 bytes
        ("AsSizeInt", ctypes.c_int64),      # 8 bytes
        ("AsDouble",  ctypes.c_double),     # 8 bytes
        ("AsPChar",   ctypes.c_void_p)      # 8 bytes pointer
    ]

lib = None

def fast_pack(args):
    """Высокоскоростная упаковка аргументов в байтовую строку с разделителем ASCII 31"""
    return b'\x1f'.join(
        b'""' if a is None or a == "" else
        f'{a}'.encode('utf-8') if type(a) in (int, float) else
        f'"{a}"'.encode('utf-8')
        for a in args
    )

def call_runfla(func_id, flat_args):
    global lib

    try:
        if lib is None:
            context = uno.getComponentContext()
            pip = context.getByName("/singletons/com.sun.star.deployment.PackageInformationProvider")
            oxt_url = pip.getPackageLocation("addin.elmofire")
            CURRENT_DIR = uno.fileUrlToSystemPath(oxt_url)

            LIB_NAME = "elmofire64.so"
            if sys.platform == "win32":
                LIB_NAME = "elmofire64.dll"
            LIB_PATH = os.path.join(CURRENT_DIR, LIB_NAME)

            if not os.path.exists(LIB_PATH):
                raise RuntimeError(f"Library not found at {LIB_PATH}")

            lib = ctypes.CDLL(LIB_PATH)

            lib.elmo_str_py.argtypes = [ctypes.c_char_p, ctypes.POINTER(DataRec)]
            lib.elmo_str_py.restype = ctypes.c_int

            lib.elmo_val_py.argtypes = [ctypes.c_char_p, ctypes.POINTER(DataRec)]
            lib.elmo_val_py.restype = ctypes.c_int

            lib.elmo_free_str.argtypes = [ctypes.c_void_p]
            lib.elmo_free_str.restype = None

        # Сопоставляем числовой ID с конкретным методом загруженной библиотеки
        target_func = lib.elmo_str_py
        if func_id == 1:
            target_func = lib.elmo_val_py

        # Быстрая генерация байтового буфера
        packed_bytes = fast_pack(flat_args)
        packed_data = ctypes.create_string_buffer(packed_bytes)

        # Создаем структуру локально в потоке, а не глобально
        local_result = DataRec()

        # Вызов функции с передачей указателя на структуру
        target_func(packed_data, ctypes.byref(local_result))

        dtype = local_result.DataType

        if dtype == 1:
            return int(local_result.AsSizeInt)

        elif dtype == 2:
            return float(local_result.AsDouble)

        elif dtype == 3:
            ptr = local_result.AsPChar
            try:
                # Прямое чтение из участка памяти
                result_str = ctypes.string_at(ptr).decode('utf-8', errors='replace')
            finally:
                # Защита: гарантируем, что сбой в Lazarus не закроет LibreOffice
                try:
                    lib.elmo_free_str(ptr)
                except Exception:
                    pass

            return result_str

        return ""

    except Exception as err:
        return f"ELMOFIRE ERROR: {str(err)}"

class ElmoFire(unohelper.Base, XElmoFire, XAddIn, XServiceName, XLocalizable):
    def __init__(self, ctx):
        self.ctx = ctx
        self.locale = Locale("en","US", "")

    def getServiceName(self):
        return "ElmoFire unit-aware scripting engine"

    def setLocale(self, locale):
        self.locale = locale

    def getLocale(self):
        return self.locale

    def getProgrammaticFuntionName(self, aDisplayName):
        return aDisplayName

    def getDisplayFunctionName(self, aProgrammaticName):
        return aProgrammaticName

    def getFunctionDescription(self , aProgrammaticName):
        if aProgrammaticName == "elmostr":
            return "Run Formula and returns a string with units"
        elif aProgrammaticName == "elmoval":
            return "Run Formula and returns a value without units"
        return ""

    def getArgumentDescription(self, aProgrammaticFunctionName, nArgument):
        return ""

    def getProgrammaticCategoryName(self, aProgrammaticFunctionName):
        return "Add-In"

    def getDisplayArgumentName(self, aProgrammaticFunctionName, nArgument):
        if nArgument = 1
            return "[variable; value;]..[variable; value;] Formula"
        return ""

    def elmostr(self, *args) -> str:
        return call_runfla(0, args)

    def elmoval(self, *args):
        return call_runfla(1, args)

