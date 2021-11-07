Include dc.dev.logging.LogMacro

Class dc.dev.logging.Use [ CompileAfter = dc.dev.logging.Log ]
{

/// do ##class(dc.dev.logging.Use).Test()
ClassMethod Test(a As %Integer = 1, ByRef b = 2)
{
	$$$LogWarn("User message") // just place this macro in user code you wish to log
}

/// do ##class(dc.dev.Use).TestWithObjects()
ClassMethod TestWithObjects(a As %Integer = 1, b As %ZEN.proxyObject)
{
	$$$LogWarn("User message") // just place this macro in user code you wish to log for Objects
}

}
