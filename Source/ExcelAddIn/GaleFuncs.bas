Attribute VB_Name = "GaleFuncs"
Option Explicit

' --- Windows API for Memory and Libraries ---
Private Declare PtrSafe Function LoadLibrary Lib "kernel32" Alias "LoadLibraryA" (ByVal lpLibFileName As String) As LongPtr
Private Declare PtrSafe Function GetModuleHandle Lib "kernel32" Alias "GetModuleHandleA" (ByVal lpModuleName As String) As LongPtr
Private Declare PtrSafe Function lstrcpyW Lib "kernel32" (ByVal lpString1 As LongPtr, ByVal lpString2 As LongPtr) As LongPtr
Private Declare PtrSafe Function lstrlenW Lib "kernel32" (ByVal lpString As LongPtr) As Long
Private Declare PtrSafe Function CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByRef Destination As Any, ByRef Source As Any, ByVal length As Long) As Long

' --- GaleFuncs DLL functions ---
' Pass all parameters strictly as numeric memory pointers (ByVal LongPtr)
Private Declare PtrSafe Function gale_str_vba Lib "galefuncs64.dll" (ByVal pStr As LongPtr, ByVal pRec As LongPtr) As Long
Private Declare PtrSafe Function gale_val_vba Lib "galefuncs64.dll" (ByVal pStr As LongPtr, ByVal pRec As LongPtr) As Long
Private Declare PtrSafe Function gale_free_vba Lib "galefuncs64.dll" (ByVal pStr As LongPtr) As Long

Private hLibModule As LongPtr

Private Function DllLoader() As Boolean
    If hLibModule <> 0 Then
        DllLoader = True
        Exit Function
    End If
    hLibModule = GetModuleHandle("galefuncs64.dll")
    If hLibModule = 0 Then
        Dim DllPath As String
        DllPath = ThisWorkbook.Path & "\galefuncs64.dll"
        If Dir(DllPath) <> "" Then hLibModule = LoadLibrary(DllPath)
    End If
    DllLoader = (hLibModule <> 0)
End Function

' Packing arguments using 0x1C delimiter
' Optimized version using a String array and Join for maximum performance
Private Function ArgPack(ByVal args As Variant) As String
    Dim LB, UB, i As Long

    LB = LBound(args)
    UB = UBound(args)

    ReDim Arr(LB To UB) As String

    For i = LB To UB
        Arr(i) = ProcessCell(args(i))
    Next i

    ArgPack = Join(Arr, Chr$(&H1C))
End Function

' Element formatting: numbers are unquoted, everything else is quoted
' Integers are formatted without a decimal point, floats with a dot or in scientific notation
Private Function ProcessCell(ByVal cell As Variant) As String
    Select Case VarType(cell)
        Case vbEmpty, vbNull, vbError
            ProcessCell = "''"

        ' Case vbInteger, vbLong, vbLongLong, vbBoolean
        '   ProcessCell = CStr(cell)

        Case vbSingle, vbDouble, vbCurrency
            ProcessCell = Format$(cell, "0.###############E0")

        Case vbString
            ProcessCell = Chr$(7) & cell & Chr$(7)

        Case Else
            'ProcessCell = Chr$(7) & CStr$(cell) & Chr$(7)
            ProcessCell = Chr$(7) & "[Unknown Type]" & Chr$(7)

    End Select
End Function

Private Function StringFromPtr(ByVal ptr As LongPtr) As String
    Dim length As Long, buffer As String
    length = lstrlenW(ptr)
    If length > 0 Then
        buffer = Space$(length)
        lstrcpyW StrPtr(buffer), ptr
        StringFromPtr = buffer
    Else
        StringFromPtr = ""
    End If
End Function

' Unified call dispatcher
Private Function CallRunfla(ByVal FuncID As Long, ByVal args As Variant) As Variant
    On Error GoTo ErrorHandler

    If Not DllLoader() Then
        CallRunfla = "GaleFuncs ERROR: Library galefuncs64.dll not found"
        Exit Function
    End If

    Dim PackedStr As String
    PackedStr = ArgPack(args)

    ' Creating a packed buffer (Simulating TDataRec = packed record)
    ' DataType(4) + AlignPad(4) + AsSizeInt(8) + AsDouble(8) + AsPChar(8) = 32 bytes
    Dim DataRec(0 To 31) As Byte
    Dim status As Long
    
    ' Calling the DLL function, passing pointers to the start of arrays in memory
    If FuncID = 0 Then
        status = gale_str_vba(StrPtr(PackedStr), VarPtr(DataRec(0)))
    Else
        status = gale_val_vba(StrPtr(PackedStr), VarPtr(DataRec(0)))
    End If
    
    ' Extracting DataType byte-by-byte from the first 4 bytes of the buffer (indices 0–3)
    Dim dtype As Long
    CopyMemory dtype, DataRec(0), 4
    
    ' Decoding the response based on DataType
    Select Case dtype
        Case 1
            ' Extracting 8-byte Int64 integer (indices 8–15)
            Dim AsSizeInt As LongLong
            CopyMemory AsSizeInt, DataRec(8), 8
            CallRunfla = CLngLng(AsSizeInt)
            
        Case 2
            ' Extracting 8-byte Double float (indices 16–23)
            Dim AsDouble As Double
            CopyMemory AsDouble, DataRec(16), 8
            CallRunfla = CDbl(AsDouble)
            
        Case 3
            ' Extracting 8-byte PAnsiChar pointer (indices 24–31)
            Dim AsPChar As LongPtr
            CopyMemory AsPChar, DataRec(24), 8
            CallRunfla = StringFromPtr(AsPChar)
            gale_free_vba AsPChar

    End Select
    Exit Function

ErrorHandler:
    CallRunfla = "GaleFuncs ERROR: " & Err.Description
End Function

' --- Excel User-Defined Functions ---

Public Function GALESTR(ParamArray args() As Variant) As Variant
    GALESTR = CallRunfla(0, args)
End Function

Public Function GALEVAL(ParamArray args() As Variant) As Variant
    GALEVAL = CallRunfla(1, args)
End Function
