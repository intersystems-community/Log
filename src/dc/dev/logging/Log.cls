Class dc.dev.logging.Log Extends %Persistent
{

/// Replacement for missing values
Parameter Null = "Null";

/// Type of event
Property EventType As %String(MAXLEN = 10, VALUELIST = ",NONE,FATAL,ERROR,WARN,INFO,STAT,DEBUG,RAW") [ InitialExpression = "INFO" ];

/// Name of class, where event happened
Property ClassName As %String(MAXLEN = 256);

/// Name of method, where event happened
Property MethodName As %String(MAXLEN = 128);

/// Line of int code
Property Source As %String(MAXLEN = 2000);

/// Line of cls code
Property SourceCLS As %String(MAXLEN = 2000);

/// Cache user
Property UserName As %String(MAXLEN = 128) [ InitialExpression = {$username} ];

/// Arguments' values passed to method
Property Arguments As %String(MAXLEN = 32000, TRUNCATE = 1);

/// Date and time
Property TimeStamp As %TimeStamp [ InitialExpression = {$zdt($h, 3, 1)} ];

/// User message
Property Message As %String(MAXLEN = 32000, TRUNCATE = 1);

/// User IP address
Property ClientIPAddress As %String(MAXLEN = 32) [ InitialExpression = {..GetClientAddress()} ];

Index idxEventType On EventType [ Type = bitmap ];

Index idxUserName On UserName [ Type = bitmap ];

Index idxClassName On ClassName [ Type = bitmap ];

Index idxTimeStamp On TimeStamp [ Type = bitslice ];

Index idxClientIPAddress On ClientIPAddress;

/// Determine user IP address
ClassMethod GetClientAddress()
{
	// %CSP.Session source is preferable
	#dim %request As %CSP.Request
	If ($d(%request)) {
		Return %request.CgiEnvs("REMOTE_ADDR")
	}
	Return $system.Process.ClientIPAddress()
}

/// Add new log event
/// Use via $$$LogEventTYPE().
ClassMethod AddRecord(ClassName As %String = "", MethodName As %String = "", Source As %String = "", EventType As %String = "", Arguments As %String = "", Message As %String = "")
{
	Set record = ..%New()
	Set record.Arguments = Arguments
	Set record.ClassName = ClassName
	Set record.EventType = EventType
	Set record.Message = Message
	Set record.MethodName = MethodName
	Set record.Source = Source
	do ..GetClassSourceLine($Piece(Source, " ", 1, *-1), .SourceCLS)
	Set record.SourceCLS = SourceCLS
	Do record.%Save()
}

/// Entry point to get method arguments string 
ClassMethod GetMethodArguments(ClassName As %String, MethodName As %String) As %String
{
	Set list = ..GetMethodArgumentsList(ClassName, MethodName)
	Set string = ..ArgumentsListToString(list)
	Return string
}

/// Get a list of method arguments
ClassMethod GetMethodArgumentsList(ClassName As %String, MethodName As %String) As %List
{
	Set result = ""
	Set def = ##class(%Dictionary.CompiledMethod).%OpenId(ClassName _ "||" _ MethodName)
	If ($IsObject(def)) {
		Set result = def.FormalSpecParsed
	}
	Return result
}

/// Convert list of method arguments to string
ClassMethod ArgumentsListToString(List As %List) As %String
{
	Set result = ""
	For i=1:1:$ll(List) {
		Set result = result _ $$$quote($s(i>1=0:"",1:"; ") _ $lg($lg(List,i))_"=") 
		_ ..GetArgumentValue($lg($lg(List,i)),$lg($lg(List,i),2))
		_$S(i=$ll(List)=0:"",1:$$$quote(";"))
	}
	Return result
}

ClassMethod GetArgumentValue(Name As %String, ClassName As %Dictionary.CacheClassname) As %String
{
	If $ClassMethod(ClassName, "%Extends", "%RegisteredObject") {
		// it's an object
		Return "_##class(dc.dev.Log).SerializeObject("_Name _ ")_"
	} Else {
		// it's a datatype
		Return "_$g(" _ Name _ ","_$$$quote(..#Null)_")_"
	}
}

ClassMethod SerializeObject(Object) As %String
{
	Return:'$IsObject(Object) Object
	Return ..WriteJSONFromObject(Object)
}

ClassMethod WriteJSONFromObject(Object) As %String [ ProcedureBlock = 0 ]
{
	New OldIORedirected, OldMnemonic, OldIO, Str
	Set OldIORedirected = ##class(%Device).ReDirectIO()
	Set OldMnemonic = ##class(%Device).GetMnemonicRoutine()
	Set OldIO = $io
	Try {
		Set Str=""

		//Redirect IO to the current routine - makes use of the labels defined below
		Use $io::("^"_$ZNAME)

		//Enable redirection
		Do ##class(%Device).ReDirectIO(1)

		Do ##class(%ZEN.Auxiliary.jsonProvider).%ObjectToJSON(Object)
	} Catch Ex {
		Set Str = ""
	}

	//Return to original redirection/mnemonic routine settings
	If (OldMnemonic '= "") {
		Use OldIO::("^"_OldMnemonic)
	} Else {
		Use OldIO
	}
	Do ##class(%Device).ReDirectIO(OldIORedirected)

	Quit Str
 
    // Labels that allow for IO redirection
    // Read Character - we don't care about reading
rchr(c)      Quit
    // Read a string - we don't care about reading
rstr(sz,to)  Quit
    // Write a character - call the output label
wchr(s)      Do output($char(s))  Quit
    // Write a form feed - call the output label
wff()        Do output($char(12))  Quit
    // Write a newline - call the output label
wnl()        Do output($char(13,10))  Quit
    // Write a string - call the output label
wstr(s)      Do output(s)  Quit
    // Write a tab - call the output label
wtab(s)      Do output($char(9))  Quit
    // Output label - this is where you would handle what you actually want to do.
    // in our case, we want to write to Str
output(s)    Set Str = Str_s Quit
}

ClassMethod LoadContext(zzId) As %Status [ ProcedureBlock = 0 ]
{
	New zzObj, zzArguments, zzArgument, zzi, zzList
	Return:'..%ExistsId(zzId) $$$OK
	Set zzObj = ..%OpenId(zzId)
	Set zzArguments = zzObj.Arguments
	Set zzList = ..GetMethodArgumentsList(zzObj.ClassName,zzObj.MethodName)
	For zzi=1:1:$Length(zzArguments, ";")-1 {
		Set zzArgument = $Piece(zzArguments,";",zzi)
		Set @$lg($lg(zzList,zzi)) = ..DeserializeObject($Piece(zzArgument,"=",2), $lg($lg(zzList,zzi),2))
	}
}

ClassMethod DeserializeObject(String, ClassName) As %String
{
	If $ClassMethod(ClassName, "%Extends", "%RegisteredObject") {
		// it's an object
		Set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(String,,.obj)
		Return:$$$ISOK(st) obj
	}
	Return String
}

ClassMethod GetClassSourceLine(IntLocation As %String, Output ClsLocation As %String) As %Status
{
    Set Status = $$$OK
    Set ClsLocation = ""
    Try {
        Set MethodAndLine = $Piece(IntLocation,"^",1)
        Set IntName = $Piece(IntLocation,"^",2)
        Set Tag = $Piece(MethodAndLine,"+")
        Set RelativeOffset = $Piece(MethodAndLine,"+",2)
        
        // Get routine text to find the absolute offset of tTag
        Set TagOffset = 0
        Set EndPos = 0
        Set TextLines = 0
        For {
            Set Line = $Text(@("+"_$Increment(TextLines)_ "^" _ IntName))
            Quit:Line=""
            
            // Example:
            // zRun() public {
            // This relies on an assumption that methods will be sorted alphabetically and won't contain labels.
            If $Extract(Line, 1, $Length(Tag)) = Tag {
                Set TagOffset = TextLines //tTextLines is the counter.
                Set EndPos = $Length(Line)
                Quit
            }
        }
        
        // The absolute offset of the line in the .int file is the tag's offset plus the offset within it.
        Set Offset = TagOffset + RelativeOffset
        Set Status = ##class(%Studio.Debugger).SourceLine(IntName, Offset, 0, Offset, EndPos,, .Map)
        If $$$ISERR(Status) {
            Quit
        }
        If $Data(Map("CLS", 1)) {
            Set $ListBuild(Class, Method, Line, EndPos, Namespace) = Map("CLS", 1)
            Set Class = $$$comMemberKeyGet(Class, $$$cCLASSmethod, Method, $$$cMETHorigin)
            Set ClsLocation = Class _ ":" _ Method _ "+" _ Line
        }
    } Catch Ex {
        Set Status = Ex.AsStatus()
    }
    Quit Status
}

Storage Default
{
<Data name="LogDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>EventType</Value>
</Value>
<Value name="3">
<Value>ClassName</Value>
</Value>
<Value name="4">
<Value>UserName</Value>
</Value>
<Value name="5">
<Value>MethodName</Value>
</Value>
<Value name="6">
<Value>Arguments</Value>
</Value>
<Value name="7">
<Value>TimeStamp</Value>
</Value>
<Value name="8">
<Value>Message</Value>
</Value>
<Value name="9">
<Value>ClientIPAddress</Value>
</Value>
<Value name="10">
<Value>Source</Value>
</Value>
<Value name="11">
<Value>SourceCLS</Value>
</Value>
</Data>
<DataLocation>^dc.dev.LogD</DataLocation>
<DefaultData>LogDefaultData</DefaultData>
<IdLocation>^dc.dev.LogD</IdLocation>
<IndexLocation>^dc.dev.LogI</IndexLocation>
<StreamLocation>^dc.dev.LogS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
