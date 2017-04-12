#cs ----------------------------------------------------------------------------~JD
 -- JoshuaDoes © 2016 - 2017 --

 This software is still in a development state. Features may be added or removed
 without notice. Warranty is neither expressed nor implied for the system in which
 you run this software.

 AutoIt Version:	3.3.12.0 (Production)
					3.3.15.0 (Beta)
 Title:				Minecraft Offline
 Start date:		January 30th, 2016
					- I may or may not have abandoned this for over a year
 Build Number:		0 (No builds released)
 Release Format:	None
 Author:			JoshuaDoes (Joshua Wickings)
 Website:			Minecraft Offline [https://joshuadoes.com/MinecraftOffline/]
 License:			GPL v3.0 [https://www.gnu.org/licenses/gpl-3.0.en.html]

 Description:		Currently nothing more than experimental testing, the aim is to
					eventually provide a stable environment to download and launch
					any version of Minecraft that is officially hosted by Mojang and
					also launch modded versions of Minecraft with ease.

 Features:
	- Login to your Mojang account
	- Create the necessary directory structure for the game to operate in
	- Download (most) required files for the game to load, including the chosen
	  version's files

 To-Do:
	- Implement logic to successfully launch Minecraft with the correct parameters
	- Download all the other required files, such as assets

 Credits:
	- The AutoIt team for creating such an amazing dynamic and diverse scripting language
	  for the Windows operating system
	- Mojang for creating such a wonderful game (and also making their auth system easy)
	- Kealper for helping with the basics of RegEx
#ce ----------------------------------------------------------------------------~JD

#include <File.au3>
#include <String.au3>
#include <Array.au3>

If Not @Compiled Then
	_Debug("We are running in a development environment.")
ElseIf @Compiled Then
	_Debug("We are running in a production environment.")
EndIf

Global $sUsername = InputBox("Minecraft Offline", "Please enter your Mojang account email.", "", " M")
If @error Then _Shutdown()
Global $sPassword = InputBox("Minecraft Offline", "Please enter your Mojang account password.", "", "*M")
If @error Then _Shutdown()
Global $sVersion = "1.11.2"
Global $sSessionID = "--"
Global $sUUID = ""
Global $sAccessToken = ""
Global $sClientToken = ""
Global $sClientIdentifier = "MinecraftOffline" ;This is basically the user agent/name of our client

Global $sDataDir = @AppDataDir & "\.minecraftoffline"
Global $sAssetsDir = $sDataDir & "\assets"
Global $sLibrariesDir = $sDataDir & "\libraries"
Global $sNativesDir = $sDataDir & "\natives"
Global $sVersionsDir = $sDataDir & "\versions"
Global $sWorldsDir = $sDataDir & "\worlds"
Global $sServersDir = $sDataDir & "\servers"
Global $sScreenshotsDir = $sDataDir & "\screenshots"
Global $sShaderpacksDir = $sDataDir & "\shaderpacks"
Global $sModsDir = $sDataDir & "\mods"
Global $sModConfigsDir = $sDataDir & "\config"
Global $sResourcepacksDir = $sDataDir & "\resourcepacks"
Global $sMpResourcepacksDir = $sServersDir & "\resourcepacks"
Global $sLogsDir = $sDataDir & "\logs"
Global $sOptions = $sDataDir & "\settings.cfg"
Global $sServers = $sServersDir & "\servers.cfg"
Global $sVersions = $sVersionsDir & "\versions.json"
Global $sVersions_URL = "https://launchermeta.mojang.com/mc/game/version_manifest.json" ;Original was "http://s3.amazonaws.com/Minecraft.Download/versions/versions.json", Dinnerbone left a comment saying to use "https://launchermeta.mojang.com/mc/game/version_manifest.json" instead
Global $sGameVersion = $sVersionsDir & "\" & $sVersion & "\" & $sVersion & ".json"
Global $sGameVersionJar = $sVersionsDir & "\" & $sVersion & "\" & $sVersion & ".jar"
Global $sGameVersion_URL = "http://s3.amazonaws.com/Minecraft.Download/versions/" & $sVersion & "/" & $sVersion & ".json"
Global $sLauncherPackLZMA = $sDataDir & "\launcher.pack.lzma"
Global $sLauncherPackLZMA_URL = "https://s3.amazonaws.com/Minecraft.Download/launcher/launcher.pack.lzma"

_Minecraft()

Func _Minecraft()
	_Minecraft_SetUserAgent()
	_Minecraft_CheckGameData()
	_Minecraft_CheckVersion()
	_Minecraft_Login()
	OnAutoItExitRegister("_Shutdown")
	_Minecraft_StartGame()
	_Minecraft_Logout()
	_Shutdown()
EndFunc


Func _Minecraft_SetUserAgent()
	Global $sUserAgent = "Minecraft_Offline-JoshuaDoes-1.0"
	_Debug("Setting our HTTP user agent to " & $sUserAgent & "...")
	HttpSetUserAgent($sUserAgent)
EndFunc
Func _Minecraft_CheckGameData()
	_Debug("Checking for game data directories...")
	_CheckDir($sDataDir)
	_CheckDir($sAssetsDir)
	_CheckDir($sLibrariesDir)
	_CheckDir($sNativesDir)
	_CheckDir($sVersionsDir)
	_CheckDir($sVersionsDir & "\" & $sVersion)
	_CheckDir($sWorldsDir)
	_CheckDir($sServersDir)
	_CheckDir($sScreenshotsDir)
	_CheckDir($sShaderpacksDir)
	_CheckDir($sModsDir)
	_CheckDir($sModConfigsDir)
	_CheckDir($sResourcepacksDir)
	_CheckDir($sMpResourcepacksDir)
	_CheckDir($sLogsDir)

	_Debug("Checking for game data files...")
	_CheckFile($sOptions)
	_CheckFile($sServers)
	_CheckFile($sVersionsDir & "\" & $sVersion & "\" & $sVersion & ".json")

	If Not FileExists($sLauncherPackLZMA) Then
		_Debug("Downloading " & $sLauncherPackLZMA_URL & " to " & $sLauncherPackLZMA & "...")
		InetGet($sLauncherPackLZMA_URL, $sLauncherPackLZMA, 1)
		If Not FileExists($sLauncherPackLZMA) Then
			_Debug("There was an error downloading launcher.pack.lzma.")
			_Shutdown()
		ElseIf FileExists($sLauncherPackLZMA) Then
			_Debug("Download of launcher.pack.lzma successful.")
		EndIf
	ElseIf FileExists($sLauncherPackLZMA) Then
		_Debug("File " & $sLauncherPackLZMA & " already exists. Cancelling download task...")
	EndIf
	FileDelete($sVersions)
	InetGet($sVersions_URL, $sVersions, 1)
	If Not FileExists($sVersions) Then
		_Debug("There was an error downloading versions.json.")
		_Shutdown()
	ElseIf FileExists($sVersions) Then
		_Debug("Download of versions.json successful.")
	EndIf
	;http://s3.amazonaws.com/Minecraft.Download/versions/b1.7.3/b1.7.3.json
	_Debug("Downloading " & $sGameVersion_URL & " to " & $sGameVersion & "...")
	InetGet($sGameVersion_URL, $sGameVersion, 1)
	If Not FileExists($sGameVersion) Then
		_Debug("There was an error downloading " & $sVersion & ".json.")
		_Shutdown()
	ElseIf FileExists($sGameVersion) Then
		_Debug("Download of " & $sVersion & ".json successful.")
	EndIf
EndFunc
Func _Minecraft_CheckVersion()
	_Debug("Checking for the latest stable release version of Minecraft...")
	$sVersions_Data = FileRead($sVersions)
	$sVersion = StringRegExp($sVersions_Data, "(?i)""release"":(?:\s*)""(.+?)""", 3)
	If UBound($sVersion) > 0 Then
		$sVersion = $sVersion[0]
	Else
		_Debug("File " & $sVersions & " is corrupted. Cancelling launcher startup...")
		_Shutdown()
	EndIf
EndFunc
Func _Minecraft_Login()
	_Debug("Attempting to log into Minecraft...")
	$sSession_Data = _POST("https://authserver.mojang.com/authenticate", '{"agent":{"name":"Minecraft","version":1},"username":"' & $sUsername & '","password":"' & $sPassword & '","clientToken":"' & $sClientIdentifier & '"}')
	_Debug("Session data: " & $sSession_Data)
	_Debug("Reading session parameters...")
	$sAccessToken = _StringBetween($sSession_Data, '"accessToken":"', '"')
	$sAccessToken = $sAccessToken[0]
	_Debug("Access token: " & $sAccessToken)
	$sClientToken = _StringBetween($sSession_Data, '"clientToken":"', '"')
	$sClientToken = $sClientToken[0]
	_Debug("Client token: " & $sClientToken)
	$sSelectedProfile_ID = _StringBetween($sSession_Data, '"id":"', '",') ;The comma is there to ensure that we get it from selectedprofile
	$sSelectedProfile_ID = $sSelectedProfile_ID[0]
	_Debug("Selected profile ID: " & $sSelectedProfile_ID)
	$sSelectedProfile_Name = _StringBetween($sSession_Data, '"name":"', '"},') ;The extra stuff is there to also ensure that we get it from selectedprofile
	$sSelectedProfile_Name = $sSelectedProfile_Name[0]
	_Debug("Selected profile name: " & $sSelectedProfile_Name)
EndFunc
Func _Minecraft_StartGame()
	_Debug("Attempting to start Minecraft...")
	$sGameVersion_Data = FileRead($sGameVersion)

	;Find the game arguments
	$sGame_Arguments = StringRegExp($sGameVersion_Data, "(?i)""minecraftArguments"": (?:\s*)""(.+?)""", 3)
	If UBound($sGame_Arguments) > 0 Then
		$sGame_Arguments = $sGame_Arguments[0]
		_Debug("Launch Arguments: " & $sGame_Arguments)
	Else
		_Debug("Error finding launch arguments. Cancelling game start...")
		_Shutdown()
	EndIf

	;Find the main class
	$sGame_MainClass = StringRegExp($sGameVersion_Data, "(?i)""mainClass"": (?:\s*)""(.+?)""", 3)
	If UBound($sGame_MainClass) > 0 Then
		$sGame_MainClass = $sGame_MainClass[0]
		_Debug("Main Class: " & $sGame_MainClass)
	Else
		_Debug("Error finding main class. Cancelling game start...")
		_Shutdown()
	EndIf

	$sGame_Downloads = StringRegExp($sGameVersion_Data, "(?i)""downloads"": (?:\s*)""(.+?)""", 3)
	If UBound($sGame_Downloads) > 0 Then
		$sGame_VersionURL = StringRegExp($sGame_Downloads[0], "(?i)""url"": (?:\s*)""(.+?)""", 3)
		If UBound($sGame_VersionURL) > 0 Then
			$sGame_VersionURL = $sGame_VersionURL[0]
			InetGet($sGame_VersionURL, $sGameVersionJar, 1)
			_Debug("Downloaded " & $sGame_VersionURL & " to " & $sGameVersionJar)
		Else
			_Debug("Error finding version jar. Cancelling game start...")
		EndIf
	Else
		_Debug("Error finding downloads list. Cancelling game start...")
		_Shutdown()
	EndIf
EndFunc
Func _Minecraft_Logout()
	_Debug("Logging out of Minecraft...")
	$sSession_Data = _POST("https://authserver.mojang.com/invalidate", '{"accessToken":"' & $sAccessToken & '","clientToken":"' & $sClientToken & '"}')
	_Debug($sSession_Data)
EndFunc
Func _Debug($sMsg)
	ConsoleWrite("> " & $sMsg & @CRLF)
EndFunc
Func _POST($sURL, $sData = "")
	$oHTTP = ObjCreate("winhttp.winhttprequest.5.1")
	$oHTTP.Open("POST", $sURL)
	$oHTTP.Send(StringToBinary($sData))
	$HTMLSource = $oHTTP.ResponseText
	Return $HTMLSource
EndFunc
Func _CheckDir($sDir)
	If Not FileExists($sDir) Then
		_Debug("Creating directory " & $sDir & "...")
		DirCreate($sDir) ;Creates the directory to store all game data if it doesn't exist
	ElseIf FileExists($sDir) Then
		_Debug("Directory " & $sDir & " already exists. Cancelling creation task...")
	EndIf
EndFunc
Func _CheckFile($sFile)
	If Not FileExists($sFile) Then
		_Debug("Creating file " & $sFile & "...")
		_FileCreate($sFile)
	ElseIf FileExists($sFile) Then
		_Debug("File " & $sFile & " already exists. Cancelling creation task...")
	EndIf
EndFunc
Func _Shutdown()
	_Minecraft_Logout()
	Exit
EndFunc
