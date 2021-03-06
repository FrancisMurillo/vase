Attribute VB_Name = "VaseLib"
'=======================
'--- Constants       ---
'=======================
Public Const METHOD_HEADER_PATTERN As String = _
    "* Sub " & VaseConfig.TEST_METHOD_PATTERN

'=======================
'- Internal Functions  -
'=======================

'# Run the test suites with the correct options
'@ Return: A tuple of reporting the test execution
Public Function RunVaseSuite(VaseBook As Workbook, _
        Optional Verbose As Boolean = True, _
        Optional ShowOnlyFailed As Boolean = False) As Variant
    If Verbose Then Debug.Print "" ' Newline
    If Verbose Then Debug.Print "Finding test modules"
    Dim Book As Workbook
    Dim TestMethodCount As Long, TestMethodSuccessCount As Long
    Dim TestModuleCount As Long, TestModuleSuccessCount As Long
    Dim TestMethodLocalPassCount As Long, TestMethodLocalTotalCount As Long
    Dim TestMethodFailedCol As New Collection, TestMethodFailedArr As Variant
    Dim TModules As Variant, TModule As Variant, TMethods As Variant, TMethod As Variant
    Dim Module As VBComponent
    Dim TestResult As Variant
    Set Book = ActiveWorkbook ' Just in case I want to segregate it again
    TModules = FindTestModules(VaseBook)
    
    TestMethodCount = 0
    TestMethodSuccessCount = 0
    TestModuleCount = 0
    TestModuleSuccessCount = 0
    
    
    ' Profiling mark here
    Dim TestSuiteStartTime As Double, TestModuleStartTime As Double, TestMethodStartTime As Double
    Dim TestTimeStr As String ' Temp variable to help with outputting
    TestSuiteStartTime = Timer
    For Each TModule In TModules
        TestModuleStartTime = Timer ' Profiling module start
        
        If Verbose Then Debug.Print "* " & TModule.Name
        If Verbose Then Debug.Print "=============="
        TestMethodLocalPassCount = 0
        
        Set Module = TModule ' Just type casting it
        TMethods = FindTestMethods(Module)
        
        ' Run setup method
        If RunSetupMethod(VaseBook.Name, TModule.Name) Then
                If Verbose Then Debug.Print "Setup method executed"
        End If
        
        For Each TMethod In TMethods
            VaseAssert.InitAssert
            
            TestMethodStartTime = Timer ' Profiling method start
            TestResult = RunTestMethod(VaseBook.Name, TModule.Name, CStr(TMethod))
            TestTimeStr = "(" & CStr(Timer - TestMethodStartTime) & ")"
            
            If TestResult(0) Then
                If Verbose Then Debug.Print vbTab & "+ " & TMethod & TestTimeStr
                TestMethodLocalPassCount = TestMethodLocalPassCount + 1
            Else
                If Verbose Then Debug.Print vbTab & "- " & TMethod & TestTimeStr & TestResult(1)
                TestMethodFailedCol.Add TModule.Name & "." & TMethod
            End If
        Next
        
        ' Run teardown method
        If RunTeardownMethod(VaseBook.Name, TModule.Name) Then
            If Verbose Then Debug.Print "Teardown method executed"
        End If
        
        ' Profile here
        TestTimeStr = CStr(Timer - TestModuleStartTime)
        
        TestMethodLocalTotalCount = UBound(TMethods) + 1
        TestMethodCount = TestMethodCount + TestMethodLocalTotalCount
        TestMethodSuccessCount = TestMethodSuccessCount + TestMethodLocalPassCount
        
        TestModuleCount = TestModuleCount + 1
        If Verbose And TestMethodLocalTotalCount > 0 Then Debug.Print "-------"  ' Dashes if there was an test method run
        If TestMethodLocalTotalCount = 0 Then
            If Verbose Then Debug.Print "** No test cases to run here"
            TestModuleSuccessCount = TestModuleSuccessCount + 1
        ElseIf TestMethodLocalPassCount = TestMethodLocalTotalCount Then
            If Verbose Then Debug.Print "*+ Total: " & CStr(TestMethodLocalTotalCount)
            If Verbose Then Debug.Print "** Time: " & TestTimeStr
            TestModuleSuccessCount = TestModuleSuccessCount + 1
        Else
            If Verbose Then Debug.Print "*+ Total: " & CStr(TestMethodLocalTotalCount) & _
                                " / Passed: " & TestMethodLocalPassCount & _
                                " / Failed: " & (TestMethodLocalTotalCount - TestMethodLocalPassCount)
            If Verbose Then Debug.Print "** Time: " & TestTimeStr
        End If
        
        If Verbose Then Debug.Print "" ' Emptyline
    Next
    TestMethodFailedArr = ToArray(TestMethodFailedCol)
    If Verbose And TestModuleCount > 0 Then Debug.Print "--------------"  ' Dashes if there was an test method run
    If TestModuleCount = 0 Then
        If Verbose Then Debug.Print _
            "No test modules were found. Vase is full of air."
    ElseIf TestModuleCount = TestModuleSuccessCount Then
        If Verbose Then Debug.Print _
            "+ Modules: " & CStr(TestModuleCount) & " / Methods: " & CStr(TestMethodCount)
        If Verbose Then Debug.Print "Test Execution Time: " & CStr(Timer - TestSuiteStartTime)
    Else
        If Verbose Then Debug.Print _
            "- Modules: " & CStr(TestModuleCount) & " / Passed: " & CStr(TestModuleSuccessCount) & " / Failed: " & CStr(TestModuleCount - TestModuleSuccessCount) & vbCrLf & _
            "- Methods: " & CStr(TestMethodCount) & " / Passed: " & CStr(TestMethodSuccessCount) & " / Failed: " & CStr(TestMethodCount - TestMethodSuccessCount) & vbCrLf & vbCrLf & _
            "Failed Methods:" & vbCrLf & Join_(TestMethodFailedArr, vbCrLf, Prefix:="* ") & vbCrLf
        If Verbose Then Debug.Print "Test Execution Time: " & CStr(Timer - TestSuiteStartTime)
    End If
    
    Dim Tuple As Variant
    Tuple = Array()
    RunVaseSuite = Tuple
End Function

'# Runs a method using Application.Run, this returns true if the method was executed.
Private Function RunMethod(BookName As String, ModuleName As String, MethodName As String)
On Error GoTo ErrHandler:
    RunMethod = True
    Application.Run "'" & BookName & "'!" & ModuleName & "." & MethodName
ErrHandler:
    If Err.Number = 1004 Then ' Only clear the error when it is Application.Run error
        RunMethod = False
        Err.Clear
    End If
End Function

'# Runs the default Setup method
Private Function RunSetupMethod(BookName As String, ModuleName As String)
    RunSetupMethod = RunMethod(BookName, ModuleName, VaseConfig.TEST_SETUP_METHOD_NAME)
End Function

'# Runs the default Teardown method
Private Function RunTeardownMethod(BookName As String, ModuleName As String)
    RunTeardownMethod = RunMethod(BookName, ModuleName, VaseConfig.TEST_TEARDOWN_METHOD_NAME)
End Function

'# This finds the modules that are deemed as test modules
Public Function FindTestModules(Book As Workbook) As Variant
    Dim Module As VBComponent, Modules As Variant, Index As Integer
    Modules = Array()
    Index = 0
    ReDim Modules(0 To Book.VBProject.VBComponents.Count)
    For Each Module In Book.VBProject.VBComponents
        If Module.Name Like VaseConfig.TEST_MODULE_PATTERN Then
            Set Modules(Index) = Module
            Index = Index + 1
        End If
    Next
    
    ' Fit array
    If Index = 0 Then
        Modules = Array()
    Else
        ReDim Preserve Modules(0 To Index - 1)
    End If
    
    FindTestModules = Modules
End Function

'# Finds the test methods to execute for a module
'@ Return: A zero-based string array of the method names to execute
Public Function FindTestMethods(Module As VBComponent) As Variant
    Dim Methods As Variant, Index As Integer, LineIndex As Integer, CodeLine As String
    Methods = Array()
    ReDim Methods(0 To Module.CodeModule.CountOfLines)
    
    For LineIndex = 1 To Module.CodeModule.CountOfLines
        CodeLine = Module.CodeModule.Lines(LineIndex, 1)
        If CodeLine Like METHOD_HEADER_PATTERN Then
            Dim LeftPos As Integer, RightPos As Integer
            LeftPos = InStr(CodeLine, "Sub") + 4
            RightPos = InStr(LeftPos, CodeLine, "(") - 1
            
            Methods(Index) = Mid(CodeLine, LeftPos, RightPos - LeftPos + 1)
            Index = Index + 1
        End If
    Next
    
    If Index = 0 Then
        Methods = Array()
    Else
        ReDim Preserve Methods(0 To Index - 1)
    End If
    FindTestMethods = Methods
End Function

'# Runs a test method, this assumes just it is a sub with no parameters.
'# This also encloses it in a block for protection
'@ Return: A 2-tuple consisting of a boolean indicating success and a string indicating the assertion where it failed
Public Function RunTestMethod(BookName As String, ModuleName As String, MethodName As String) As Variant
    RunMethod BookName, ModuleName, MethodName
ErrHandler:
    Dim HasError As Boolean, Tuple As Variant
    HasError = (Err.Number <> 0)
    If HasError Then
        Tuple = Array(False, vbCrLf & vbTab & "-> ExceptionRaised(" & Err.Number & "):  " & Err.Description)
    Else
        Dim ErrorMessage As String
        If VaseAssert.FirstFailedTestParentMethod = "" Then
            ErrorMessage = _
                vbCrLf & vbTab & "> " & VaseAssert.FirstFailedTestMethod & _
                vbCrLf & vbTab & "-> " & VaseAssert.FirstFailedTestAssertMessage & _
                IIf(VaseAssert.FirstFailedTestMessage <> "", _
                vbCrLf & vbTab & "->> " & VaseAssert.FirstFailedTestMessage, "")
        Else
            ErrorMessage = _
                vbCrLf & vbTab & "> " & VaseAssert.FirstFailedTestParentMethod & _
                    "(" & VaseAssert.FirstFailedTestMethod & ")" & _
                vbCrLf & vbTab & "-> " & VaseAssert.FirstFailedTestAssertMessage & _
                IIf(VaseAssert.FirstFailedTestMessage <> "", _
                vbCrLf & vbTab & "->> " & VaseAssert.FirstFailedTestMessage, "")
        End If
        
        
    
        Tuple = Array( _
                    VaseAssert.TestResult, _
                    ErrorMessage _
                )
    End If
    Err.Clear
    RunTestMethod = Tuple
End Function

'=======================
'-- Helper Functions  --
'=======================

'# Clears the intermediate screen
Public Sub ClearScreen()
    Application.SendKeys "^g ^a {DEL}"
    DoEvents
End Sub

'# Simple zip of two arrays, returns an array of 2-tuples
'# This assumes that arrays are zero-indexed
Public Function Zip(LeftArr As Variant, RightArr As Variant) As Variant
    If UBound(LeftArr) = -1 Or UBound(RightArr) = -1 Then
        Zip = Array()
        Exit Function
    End If
    
    Dim ZipArr As Variant, Index As Long
    Dim LeftSize As Long, RightSize As Long
    LeftSize = UBound(LeftArr) - LBound(LeftArr)
    RightSize = UBound(RightArr) - LBound(RightArr)
    
    ZipArr = Array()
    ReDim ZipArr(0 To IIf(LeftSize > RightSize, RightSize, LeftSize))
                            

    For Index = 0 To UBound(ZipArr)
        ZipArr(Index) = Array(LeftArr(LBound(LeftArr) + Index), RightArr(LBound(RightArr) + Index))
    Next
    Zip = ZipArr
End Function

'# Finds a value in an array of values, this assumes the elements can be matched using the equality operator
Public Function InArray(Look As Variant, Arr As Variant) As Boolean
    Dim Elem As Variant
    InArray = False
    
    If UBound(Arr) = -1 Then Exit Function ' Nothing to do

    For Each Elem In Arr
        If Elem = Look Then
            InArray = True
            Exit Function
        End If
    Next
End Function

'# Converts a collection to an array
Public Function ToArray(Col As Collection) As Variant
    If Col Is Nothing Then
        ToArray = Array()
        Exit Function
    End If
    
    If Col.Count = 0 Then
        ToArray = Array()
        Exit Function
    End If
    
    Dim Arr As Variant, Item As Variant, Index As Integer
    Arr = Array()
    ReDim Arr(0 To Col.Count - 1)
    Index = 0
    For Each Item In Col
        Arr(Index) = Item
        Index = Index + 1
    Next
    
    ToArray = Arr
End Function

'# Joins an array assuming all entries are string
Public Function Join_(Arr As Variant, Delimiter As String, Optional Prefix As String = "") As String
    Dim StrArr() As String, Index As Integer
    ReDim StrArr(0 To UBound(Arr))
        
    For Index = 0 To UBound(StrArr)
        StrArr(Index) = Prefix & CStr(Arr(Index))
    Next
    Join_ = Join(StrArr, Delimiter)
End Function

'# Determines if a string is in an array using the like operator instead of equality
'@ Param: Patterns > An array of strings, not necessarily zero-based
'@ Return: True if the string matches any one of the patterns
Public Function InLike(Source As String, Patterns As Variant) As Boolean
    Dim Pattern As Variant
    InLike = False
    For Each Pattern In Patterns
        InLike = Source Like Pattern
        If InLike Then Exit For
    Next
End Function
