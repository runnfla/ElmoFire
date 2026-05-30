import sys
import uno
import unohelper

if sys.platform != "win32" and not sys.platform.startswith("linux"):
    raise RuntimeError(f"ElmoFire Add-In ERROR: Operating system {sys.platform} is not supported")

if sys.maxsize <= 2**32:
    raise RuntimeError("ElmoFire Add-In ERROR: Only 64-bit systems are supported")

def createInstance(ctx):
    import addin.elmofire
    return addin.elmofire.ElmoFire(ctx)

g_ImplementationHelper = unohelper.ImplementationHelper()
g_ImplementationHelper.addImplementation(
    createInstance,
    "addin.ElmoFire",
    ("com.sun.star.sheet.AddIn",),
)
