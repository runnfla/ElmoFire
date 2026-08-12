# GaleFuncs Add-In

The GaleFuncs Add-In is an extension for LibreOffice Calc and Microsoft Excel powered by the [RunFormula](https://github.com/runnfla/RunFormula) scripting engine. It allows you to evaluate mathematical expressions and formulas with physical unit awareness, without creating macros. Expressions and short scripts are written directly inside spreadsheet cells. The [RunFormula](https://github.com/runnfla/RunFormula) syntax is fully supported.

With GaleFuncs, you can:
* Perform evaluations with complex numbers and intervals
* Use conditional statements, loops, and user-defined functions
* Check physical dimensions at every operation
* Automatically determine the unit of measurement for the final result
* Convert values between different unit systems

**Compatibility**\
\- LibreOffice Calc x86‑64 on Windows and Linux\
\- Microsoft Excel 64-bit on Windows

**Installation in LibreOffice Calc**\
1\. Download the `GaleFuncs-*.oxt` file from the [Add-In](https://github.com/runnfla/GaleFuncs/tree/main/Add-In) directory (or from the official [LibreOffice Extensions & Templates Repository](https://extensions.libreoffice.org/en/extensions/show/99599))\
2\. In LibreOffice Calc, go to **Tools \-\-> Extensions**\
3\. In the **Extensions** manager window, click the **Add** button\
4\. Select the downloaded `.oxt` file and click **Open**\
5\. Restart LibreOffice Calc for the changes to take effect

**Installation in Microsoft Excel**\
1\. Download the `GaleFuncs-*-Excel.zip` archive from the [Add-In](https://github.com/runnfla/GaleFuncs/tree/main/Add-In) directory\
2\. Extract files from the ZIP archive to a convenient and permanent folder on your computer (e.g., `C:\GaleFuncs\`)\
3\. **Important:** Do not delete or move the `.xlam` and `.dll` files after installation - otherwise, the add-in will stop working\
4\. Open MS Excel. Click the **File** tab on the Ribbon and select **Options** (at the bottom of the left panel)\
5\. In the **Excel Options** window, select the **Add-Ins** section\
6\. At the bottom of the window, select **Excel Add-ins** from the **Manage** drop-down list and click **Go**\
7\. In the **Add-Ins** dialog box, click **Browse**, select the extracted `GaleFuncs Excel.xlam` file and click **OK**\
8\. Make sure that the **GaleFuncs Excel** add-in appears in the list and is checked and click **OK**

**How to use**\
After installing the add‑in, two new functions will become available in your spreadsheet: GALESTR() and GALEVAL(). They have the same parameters.\
The GALESTR() function returns a text string containing the calculated result, including units of measurement if applicable.\
The GALEVAL() function returns a raw, dimensionless number (or string) suitable for further calculations.\
Parameters are passed in the following order: first, the variables used in the formula and their values are specified in pairs, followed by the formula (expression or script) itself at the end.

`GALESTR/GALEVAL([variable1, value1,]...[variableN, valueN,] script)`

The number of variables is unlimited. Variables may be omitted (i.e., you can pass just the formula). All parameters are separated by commas/semicolons. If the text of a variable, value, or formula is provided directly in the parameters of the GALESTR/GALEVAL functions, it must be enclosed in double quotation marks.

**Example**
```
       A             B              C                  D                                             E
  +-----------+--------------+--------------+----------------------------------------------------------------------------+
1 |  Voltage  |   U Units    |  Resistance  |        Power                                 |       Script                |
  +-----------+--------------+--------------+----------------------------------------------+-----------------------------+
2 |    U      |     Dim      |              |                                              |  qty(U, Dim)**2/val( R )    |
  +-----------+--------------+--------------+----------------------------------------------+-----------------------------+
3 |   2.2     |     mV       |   0.1 Ohm    | =GALESTR($A$2, A3, $B$2, B3, "R", C3, $E$2)  |                             |
  +-----------+--------------+--------------+----------------------------------------------+-----------------------------+
4 |   0.22    |     kV       |   20 kOhm    | =GALESTR($A$2, A4, $B$2, B4, "R", C4, $E$2)  |                             |
  +-----------+--------------+--------------+----------------------------------------------+-----------------------------+
```
For details on the RunFormula syntax, refer to the help files in the [Help](https://github.com/runnfla/GaleFuncs/blob/main/Help) directory (available in both English and Russian). Feel free to ask questions in [Discussions](https://github.com/runnfla/GaleFuncs/discussions).

--\
**Author:** Alexander Torubarov\
**Contact:** runfla@yandex.com

Copyright (C) 2026 Alexander Torubarov\
Licensed under the MIT License.\
See the `LICENSE` file in the project root or a copy available at [opensource.org](https://opensource.org) for full license information.
