#cs ----------------------------------------------------------------------------~JD
 -- JoshuaDoes © 2017 --

 This software is still in a development state. Features may be added or removed
 without notice. Warranty is neither expressed nor implied for the system in which
 you run this software.

 AutoIt Version:	3.3.14.0 (Production)
					3.3.15.0 (Beta)
 Title:				Minecraft Offline
 Start date:		April 16th, 2017
					- Rewriting from scratch
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
	- Download basic version info

 To-Do:
	- Implement logic to successfully launch Minecraft with the correct parameters
	- Download all the other required files, such as assets and libraries and the
	  version files themselves

 Credits:
	- The AutoIt team for creating such an amazing dynamic and diverse scripting language
	  for the Windows operating system
	- Mojang for creating such a wonderful game (and also making their auth system easy)
#ce ----------------------------------------------------------------------------~JD
#include <String.au3>
#include "JSON.au3"

Global Const $URL_REGISTER = "https://account.mojang.com/register"
Global Const $URL_JAR_FALLBACK = "https://s3.amazonaws.com/Minecraft.Download/"
Global Const $URL_RESOURCE_BASE = "http://resources.download.minecraft.net/"
Global Const $URL_LIBRARY_BASE = "https://libraries.minecraft.net/"
Global Const $URL_BLOG = "http://mcupdate.tumblr.com"
Global Const $URL_SUPPORT = "http://help.mojang.com/?ref=launcher"
Global Const $URL_STATUS_CHECKER = "http://status.mojang.com/check"
Global Const $URL_FORGOT_USERNAME = "http://help.mojang.com/customer/portal/articles/1233873?ref=launcher"
Global Const $URL_FORGOT_PASSWORD_MINECRAFT = "http://help.mojang.com/customer/portal/articles/329524-change-or-forgot-password?ref=launcher"
Global Const $URL_FORGOT_MIGRATED_EMAIL = "http://help.mojang.com/customer/portal/articles/1205055-minecraft-launcher-error---migrated-account?ref=launcher"
Global Const $URL_VERSION_MANIFEST = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
Global Const $URL_AUTH_BASE = "https://authserver.mojang.com/"
Global Const $URL_AUTH_AUTHENTICATE = "https://authserver.mojang.com/authenticate"
Global Const $URL_AUTH_REFRESH = "https://authserver.mojang.com/refresh"
Global Const $URL_AUTH_VALIDATE = "https://authserver.mojang.com/validate"
Global Const $URL_AUTH_INVALIDATE = "https://authserver.mojang.com/invalidate"
Global Const $URL_AUTH_SIGNOUT = "https://authserver.mojang.com/signout"

Global Const $CLIENT_IDENTIFIER = "MinecraftOffline"
Global Const $CLIENT_VERSION = "0.1"
Global $CLIENT_DEMO = True

Global $AUTH_SESSION_ID = "--"
Global $AUTH_UUID = ""
Global $AUTH_ACCESS_TOKEN = ""
Global $AUTH_CLIENT_TOKEN = ""
Global $AUTH_IS_ONLINE = False
Global $AUTH_USERNAME_EMAIL = "" ;Fill in your email, legacy account support not yet added
Global $AUTH_PASSWORD = ;Fill in your password
Global $AUTH_PROFILE = ""

Global Const $DIR_BASE = @AppDataDir & "\.minecraftoffline"
Global Const $DIR_ASSETS = $DIR_BASE & "\assets"
Global Const $DIR_INDEXES = $DIR_ASSETS & "\indexes"
Global Const $DIR_OBJECTS = $DIR_ASSETS & "\objects"

Global Const $FILE_AUTH_CREDENTIALS = $DIR_BASE & "\profiles.dat" ;Unused currently, will store auth tokens for previous sessions
Global Const $FILE_VERSION_MANIFEST = $DIR_BASE & "\version_manifest.json"


;;;;

If Not $AUTH_USERNAME_EMAIL Then
	Exit ConsoleWrite("No username specified." & @CRLF)
ElseIf $AUTH_ACCESS_TOKEN And $AUTH_CLIENT_TOKEN Then
	ConsoleWrite("Logging in with access token..." & @CRLF)
	Local $sTemp = Auth_Login_Token($URL_AUTH_VALIDATE, $AUTH_ACCESS_TOKEN, $AUTH_CLIENT_TOKEN)
	If @error Then
		ConsoleWrite("Error logging in with access token." & @CRLF)
		ConsoleWrite($sTemp & @CRLF)
		$AUTH_ACCESS_TOKEN = ""
		If $AUTH_PASSWORD Then
			ConsoleWrite("Logging in with password..." & @CRLF)
			Auth_Login_Password($URL_AUTH_AUTHENTICATE, $AUTH_USERNAME_EMAIL, $AUTH_PASSWORD, $CLIENT_IDENTIFIER, $AUTH_ACCESS_TOKEN, $AUTH_CLIENT_TOKEN, $AUTH_UUID, $AUTH_PROFILE)
			If @error Then
				Exit ConsoleWrite("Error logging in with password." & @CRLF)
			Else
				ConsoleWrite("Successfully logged in with password." & @CRLF)
				$AUTH_IS_ONLINE = True
			EndIf
		ElseIf Not $AUTH_PASSWORD Then
			Exit ConsoleWrite("No password specified." & @CRLF)
		EndIf
	Else
		ConsoleWrite("Successfully logged in with access token." & @CRLF)
		$AUTH_IS_ONLINE = True
	EndIf
ElseIf $AUTH_PASSWORD Then
	ConsoleWrite("Logging in with password..." & @CRLF)
	Auth_Login_Password($URL_AUTH_AUTHENTICATE, $AUTH_USERNAME_EMAIL, $AUTH_PASSWORD, $CLIENT_IDENTIFIER, $AUTH_ACCESS_TOKEN, $AUTH_CLIENT_TOKEN, $AUTH_UUID, $AUTH_PROFILE)
	If @error Then
		Exit ConsoleWrite("Error logging in with password." & @CRLF)
	Else
		ConsoleWrite("Successfully logged in with password." & @CRLF)
		$AUTH_IS_ONLINE = True
	EndIf
ElseIf Not $AUTH_PASSWORD Then
	Exit ConsoleWrite("No password specified." & @CRLF)
EndIf
If $AUTH_PROFILE Then $CLIENT_DEMO = False

DirCreate($DIR_BASE)
DirCreate($DIR_ASSETS)
DirCreate($DIR_INDEXES)
DirCreate($DIR_OBJECTS)

If FileExists($FILE_VERSION_MANIFEST) Then
	ConsoleWrite("Version manifest exists, checking for corruption..." & @CRLF)
	Json_StringDecode(FileRead($FILE_VERSION_MANIFEST))
	If @error Then
		ConsoleWrite("Version manifest corrupted!" & @CRLF)
		ConsoleWrite("Downloading latest version manifest..." & @CRLF)
		InetGet($URL_VERSION_MANIFEST, $FILE_VERSION_MANIFEST)
		If @error Then
			Exit ConsoleWrite("Error downloading version manifest." & @CRLF)
		Else
			ConsoleWrite("Successfully downloaded version manifest." & @CRLF)
			ConsoleWrite("Checking version manifest for corruption..." & @CRLF)
			Json_StringDecode(FileRead($FILE_VERSION_MANIFEST))
			If @error Then
				Exit ConsoleWrite("Version manifest corrupted!" & @CRLF)
			Else
				ConsoleWrite("Version manifest passed corruption check." & @CRLF)
			EndIf
		EndIf
	Else
		ConsoleWrite("Version manifest passed corruption check." & @CRLF)
	EndIf
Else
	ConsoleWrite("Downloading latest version manifest..." & @CRLF)
	InetGet($URL_VERSION_MANIFEST, $FILE_VERSION_MANIFEST)
	If @error Then
		Exit ConsoleWrite("Error downloading version manifest." & @CRLF)
	Else
		ConsoleWrite("Successfully downloaded version manifest." & @CRLF)
		ConsoleWrite("Checking version manifest for corruption..." & @CRLF)
		Json_StringDecode(FileRead($FILE_VERSION_MANIFEST))
		If @error Then
			Exit ConsoleWrite("Version manifest corrupted!" & @CRLF)
		Else
			ConsoleWrite("Version manifest passed corruption check." & @CRLF)
		EndIf
	EndIf
EndIf

$FILE_VERSION_MANIFEST_DATA = FileRead($FILE_VERSION_MANIFEST)
$FILE_VERSION_MANIFEST_DATA = Json_Decode($FILE_VERSION_MANIFEST_DATA)
$GAME_VERSION_LIST = Json_Get($FILE_VERSION_MANIFEST_DATA, '["versions"]')
$GAME_VERSION_LATEST_RELEASE = Json_Get($FILE_VERSION_MANIFEST_DATA, '["latest"]["release"]')
$GAME_VERSION_LATEST_RELEASE_JSON_URL = ""
$GAME_VERSION_LATEST_RELEASE_JSON_FILE = $DIR_INDEXES & "\" & $GAME_VERSION_LATEST_RELEASE & ".json"
;$GAME_VERSION_LATEST_SNAPSHOT = Json_Get($FILE_VERSION_MANIFEST_DATA, '["latest"]["snapshot"]')
For $i = 0 To UBound($GAME_VERSION_LIST) - 1
	ConsoleWrite(Json_Get($GAME_VERSION_LIST[$i], '["id"]') & @CRLF)
	If Json_Get($GAME_VERSION_LIST[$i], '["id"]') = $GAME_VERSION_LATEST_RELEASE Then
		$GAME_VERSION_LATEST_RELEASE_JSON_URL = Json_Get($GAME_VERSION_LIST[$i], '["url"]')
	EndIf
	;If Json_Get($GAME_VERSION_LIST[$i], '["id"]') = $GAME_VERSION_LATEST_SNAPSHOT Then
	;	$GAME_VERSION_LATEST_SNAPSHOT_JSON_URL = Json_Get($GAME_VERSION_LIST[$i], '["url"]')
	;EndIf
Next
If Not $GAME_VERSION_LATEST_RELEASE_JSON_URL Then
	Exit ConsoleWrite("Error finding the URL for the latest release version." & @CRLF)
EndIf
ConsoleWrite("Downloading info for version " & $GAME_VERSION_LATEST_RELEASE & "..." & @CRLF)
InetGet($GAME_VERSION_LATEST_RELEASE_JSON_URL, $GAME_VERSION_LATEST_RELEASE_JSON_FILE)
If @error Then
	Exit ConsoleWrite("Error downloading info for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
Else
	ConsoleWrite("Successfully downloaded info for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
EndIf


;;;;

Func Auth_Login_Token($sValidateURL, ByRef $AUTH_ACCESS_TOKEN, ByRef $AUTH_CLIENT_TOKEN)
	Local $sSession_Data = _POST($sValidateURL, '{"accessToken":"' & $AUTH_ACCESS_TOKEN & '","clientToken":"' & $AUTH_CLIENT_TOKEN & '"}')
	If Not $sSession_Data Then
		Return True
	Else
		Return SetError(1, 0, $sSession_Data)
	EndIf
EndFunc
Func Auth_Login_Password($sAuthenticateURL, $sUsername, $sPassword, $sClientIdentifier, ByRef $AUTH_ACCESS_TOKEN, ByRef $AUTH_CLIENT_TOKEN, ByRef $AUTH_UUID, ByRef $AUTH_PROFILE)
	Local $sSession_Data = _POST($sAuthenticateURL, '{"agent":{"name":"Minecraft","version":1},"username":"' & $sUsername & '","password":"' & $sPassword & '","clientToken":"' & $sClientIdentifier & '"}')
	$AUTH_ACCESS_TOKEN = _StringBetween($sSession_Data, '"accessToken":"', '"')
	If @error Then Return SetError(1, 0, @error)
	$AUTH_ACCESS_TOKEN = $AUTH_ACCESS_TOKEN[0]
	$AUTH_CLIENT_TOKEN = _StringBetween($sSession_Data, '"clientToken":"', '"')
	If @error Then Return SetError(1, 0, @error)
	$AUTH_CLIENT_TOKEN = $AUTH_CLIENT_TOKEN[0]
	$AUTH_UUID = _StringBetween($sSession_Data, '"id":"', '",')
	If @error Then Return SetError(1, 0, @error)
	$AUTH_UUID = $AUTH_UUID[0]
	$AUTH_PROFILE = _StringBetween($sSession_Data, '"name":"', '"},')
	If @error Then Return SetError(1, 0, @error)
	$AUTH_PROFILE = $AUTH_PROFILE[0]
EndFunc
Func _POST($sURL, $sData = "")
	$oHTTP = ObjCreate("winhttp.winhttprequest.5.1")
	$oHTTP.Open("POST", $sURL)
	$oHTTP.Send(StringToBinary($sData))
	$HTMLSource = $oHTTP.ResponseText
	Return $HTMLSource
EndFunc