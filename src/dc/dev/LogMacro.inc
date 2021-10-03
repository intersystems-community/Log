ROUTINE dc.dev.LogMacro [Type=INC]
#define StackPlace 		$st($st(-1),"PLACE")
#define CurrentClass 	##Expression($$$quote(%classname))
#define CurrentMethod 	##Expression($$$quote(%methodname))

#define MethodArguments ##Expression(##class(dc.dev.Log).GetMethodArguments(%classname,%methodname))

#define LogEvent(%type, %message) Do ##class(dc.dev.Log).AddRecord($$$CurrentClass,$$$CurrentMethod,$$$StackPlace,%type,$$$MethodArguments,%message)
#define LogNone(%message) 		$$$LogEvent("NONE", %message)
#define LogError(%message) 		$$$LogEvent("ERROR", %message)
#define LogFatal(%message) 		$$$LogEvent("FATAL", %message)
#define LogWarn(%message) 		$$$LogEvent("WARN", %message)
#define LogInfo(%message) 		$$$LogEvent("INFO", %message)
#define LogStat(%message) 		$$$LogEvent("STAT", %message)
#define LogDebug(%message) 		$$$LogEvent("DEBUG", %message)
#define LogRaw(%message) 		$$$LogEvent("RAW", %message)
