import sys
import uno

def createInstance(ctx):

    import galefuncs
    return galefuncs.GaleFuncs(ctx)

# Initialize the helper only AFTER all functions are declared.
# In some LibreOffice builds, importing unohelper is strictly required before execution.

import unohelper

g_ImplementationHelper = unohelper.ImplementationHelper()
g_ImplementationHelper.addImplementation(
    createInstance,
    "addin.runfla.galefuncs",
    ("com.sun.star.sheet.AddIn",),
)
