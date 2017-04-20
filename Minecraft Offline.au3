#cs ----------------------------------------------------------------------------~JD
	-- JoshuaDoes © 2017 --

	This software is still in a development state. Features may be added or removed
	without notice. Warranty is neither expressed nor implied for the system in which
	you run this software.

	AutoIt Version:	3.3.14.0 (Production)
	3.3.15.0 (Beta)
	Title:				Minecraft Offline
	Start date:		April 16th, 2017
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
	- Download chosen version's info file
	- Download chosen version's jar file
	- Download chosen version's required libraries (following rules as best as possible)
	- Download chosen version's assets
	- Copy chosen version's assets into virtual legacy folder for older game versions
	- Successfully launch various versions of the game
	* Some versions, such as 1.2.5 and 1.7.2, fail to launch for unknown reasons
	* A fix is being worked on at this time, however 1.11.2 and 17w15a are good to go

	To-Do:
	- Properly support the entirety of Mojang's Yggdrasil authentication service, rather
	than just the necessary pieces of it
	- Support HTTP-based mod repos
	- Support automatically joining vanilla servers and servers that support the mod repos
	- Support the Mojang API for various features such as username lookups and changing
	skins from within the launcher itself

	Credits:
	- The AutoIt team for creating such an amazing dynamic and diverse scripting language
	for the Windows operating system
	- Mojang for creating such a wonderful game (and also making their auth system easy)
#ce ----------------------------------------------------------------------------~JD
#AutoIt3Wrapper_UseX64=n

#include <String.au3>
#include "JSON.au3"

Global $mSettings[]
$mSettings["Overwrite Files"] = False
$mSettings["Override Version"] = "1.11.2" ;Change this to any version you want
$mSettings["HTTP User Agent"] = "JoshuaDoes/1.0 (Minecraft Offline 0.1)"

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

Global $AUTH_SESSION_ID = "--" ;Default session ID if for some reason the variable doesn't change
Global $AUTH_UUID = ""
Global $AUTH_ACCESS_TOKEN = ""
Global $AUTH_CLIENT_TOKEN = ""
Global $AUTH_IS_ONLINE = False
Global $AUTH_USERNAME_EMAIL = "" ;Put in your Mojang account email here
Global $AUTH_PASSWORD = "" ;Put in your Mojang account password here
Global $AUTH_PROFILE = ""

Global Const $DIR_JAVA = "C:\Program Files\Java\jre1.8.0_92\bin" ;Change this to your Java Runtime Environment installation
Global Const $DIR_BASE = @AppDataDir & "\.minecraftoffline" ;Change it, you have full control this time c:
Global Const $DIR_ASSETS = $DIR_BASE & "\assets"
Global Const $DIR_INDEXES = $DIR_ASSETS & "\indexes"
Global Const $DIR_OBJECTS = $DIR_ASSETS & "\objects"
Global Const $DIR_VIRTUAL_LEGACY = $DIR_ASSETS & "\virtual\legacy"
Global Const $DIR_SKINS = $DIR_ASSETS & "\skins"
Global Const $DIR_LIBRARIES = $DIR_BASE & "\libraries"
Global Const $DIR_VERSIONS = $DIR_BASE & "\versions"

Global Const $FILE_AUTH_CREDENTIALS = $DIR_BASE & "\profiles.dat" ;Unused currently, will store auth tokens from previous sessions
Global Const $FILE_VERSION_MANIFEST = $DIR_BASE & "\version_manifest.json" ;Location to store version manifest



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
DirCreate($DIR_VIRTUAL_LEGACY)
DirCreate($DIR_SKINS)
DirCreate($DIR_LIBRARIES)
DirCreate($DIR_VERSIONS)

If FileExists($FILE_VERSION_MANIFEST) And $mSettings["Overwrite Files"] = False Then
	ConsoleWrite("Version manifest exists, checking for corruption..." & @CRLF)
	Json_StringDecode(FileRead($FILE_VERSION_MANIFEST))
	If @error Then
		ConsoleWrite("Version manifest corrupted." & @CRLF)
		ConsoleWrite("Downloading latest version manifest..." & @CRLF)
		InetGet($URL_VERSION_MANIFEST, $FILE_VERSION_MANIFEST)
		If @error Then
			Exit ConsoleWrite("Error downloading version manifest." & @CRLF)
		Else
			ConsoleWrite("Successfully downloaded version manifest." & @CRLF)
			ConsoleWrite("Checking version manifest for corruption..." & @CRLF)
			Json_StringDecode(FileRead($FILE_VERSION_MANIFEST))
			If @error Then
				Exit ConsoleWrite("Version manifest corrupted." & @CRLF)
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
			Exit ConsoleWrite("Version manifest corrupted." & @CRLF)
		Else
			ConsoleWrite("Version manifest passed corruption check." & @CRLF)
		EndIf
	EndIf
EndIf

$FILE_VERSION_MANIFEST_DATA = FileRead($FILE_VERSION_MANIFEST)
$FILE_VERSION_MANIFEST_DATA = Json_Decode($FILE_VERSION_MANIFEST_DATA)
$GAME_VERSION_LIST = Json_Get($FILE_VERSION_MANIFEST_DATA, '["versions"]')
$GAME_VERSION_LATEST_RELEASE = Json_Get($FILE_VERSION_MANIFEST_DATA, '["latest"]["release"]')
If $mSettings["Override Version"] Then $GAME_VERSION_LATEST_RELEASE = $mSettings["Override Version"]
$GAME_VERSION_LATEST_RELEASE_JSON_URL = ""
$GAME_VERSION_LATEST_RELEASE_JSON_FILE = $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\" & $GAME_VERSION_LATEST_RELEASE & ".json"
$GAME_VERSION_LATEST_SNAPSHOT = Json_Get($FILE_VERSION_MANIFEST_DATA, '["latest"]["snapshot"]')
$GAME_VERSION_LATEST_SNAPSHOT_JSON_URL = ""
$GAME_VERSION_LATEST_SNAPSHOT_JSON_FILE = $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_SNAPSHOT & "\" & $GAME_VERSION_LATEST_SNAPSHOT & ".json"
For $i = 0 To UBound($GAME_VERSION_LIST) - 1
	;ConsoleWrite(Json_Get($GAME_VERSION_LIST[$i], '["id"]') & @CRLF)
	If Json_Get($GAME_VERSION_LIST[$i], '["id"]') = $GAME_VERSION_LATEST_RELEASE Then
		$GAME_VERSION_LATEST_RELEASE_JSON_URL = Json_Get($GAME_VERSION_LIST[$i], '["url"]')
	EndIf
	If Json_Get($GAME_VERSION_LIST[$i], '["id"]') = $GAME_VERSION_LATEST_SNAPSHOT Then
		$GAME_VERSION_LATEST_SNAPSHOT_JSON_URL = Json_Get($GAME_VERSION_LIST[$i], '["url"]')
	EndIf
Next
If Not $GAME_VERSION_LATEST_RELEASE_JSON_URL Then
	Exit ConsoleWrite("Error finding the URL for the latest release version." & @CRLF)
EndIf
If FileExists($DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE) Then
	ConsoleWrite("Folder for version " & $GAME_VERSION_LATEST_RELEASE & " already exists." & @CRLF)
Else
	ConsoleWrite("Creating folder for version " & $GAME_VERSION_LATEST_RELEASE & "..." & @CRLF)
	DirCreate($DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE)
	If FileExists($DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE) Then
		ConsoleWrite("Successfully created folder for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
	Else
		Exit ConsoleWrite("Error creating folder for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
	EndIf
EndIf
If FileExists($DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\" & $GAME_VERSION_LATEST_RELEASE & ".jar") And $mSettings["Overwrite Files"] = False Then
	ConsoleWrite("Jar data for version " & $GAME_VERSION_LATEST_RELEASE & " already exists." & @CRLF)
Else
	ConsoleWrite("Downloading jar data for version " & $GAME_VERSION_LATEST_RELEASE & "..." & @CRLF)
	Local $hJarDownload = InetGet($URL_JAR_FALLBACK & "versions/" & $GAME_VERSION_LATEST_RELEASE & "/" & $GAME_VERSION_LATEST_RELEASE & ".jar", $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\" & $GAME_VERSION_LATEST_RELEASE & ".jar", 1, 1)
	If InetGetInfo($hJarDownload, 1) Then
		Do
			Local $aJarDownloadInfo = InetGetInfo($hJarDownload, -1)
			ConsoleWrite("[JarDownload:" & $GAME_VERSION_LATEST_RELEASE & "] " & ($aJarDownloadInfo[0] / $aJarDownloadInfo[1]) & "% downloaded..." & @CRLF)
			Sleep(50)
		Until InetGetInfo($hJarDownload, 2)
	Else
		ConsoleWrite("[JarDownload:" & $GAME_VERSION_LATEST_RELEASE & "] Unknown size of download, waiting for download to complete..." & @CRLF)
		ConsoleWrite("[JarDownload:" & $GAME_VERSION_LATEST_RELEASE & "] ")
		Do
			ConsoleWrite(".")
			Sleep(50)
		Until InetGetInfo($hJarDownload, 2)
		ConsoleWrite(@CRLF)
	EndIf
	If InetGetInfo($hJarDownload, 3) Then
		ConsoleWrite("Successfully downloaded jar data for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
	ElseIf InetGetInfo($hJarDownload, 4) Then
		Exit ConsoleWrite("Error downloading jar data for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
	EndIf
EndIf
If FileExists($GAME_VERSION_LATEST_RELEASE_JSON_FILE) Then
	ConsoleWrite("Info for version " & $GAME_VERSION_LATEST_RELEASE & " already exists, checking for corruption..." & @CRLF)
	Json_StringDecode(FileRead($GAME_VERSION_LATEST_RELEASE_JSON_FILE))
	If @error Then
		Exit ConsoleWrite("Info for version " & $GAME_VERSION_LATEST_RELEASE & " corrupted." & @CRLF)
	Else
		ConsoleWrite("Info for version " & $GAME_VERSION_LATEST_RELEASE & " passed corruption check." & @CRLF)
	EndIf
Else
	ConsoleWrite("Downloading info for version " & $GAME_VERSION_LATEST_RELEASE & "..." & @CRLF)
	InetGet($GAME_VERSION_LATEST_RELEASE_JSON_URL, $GAME_VERSION_LATEST_RELEASE_JSON_FILE)
	If @error Then
		Exit ConsoleWrite("Error downloading info for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
	Else
		ConsoleWrite("Successfully downloaded info for version " & $GAME_VERSION_LATEST_RELEASE & "." & @CRLF)
		ConsoleWrite("Checking info for version " & $GAME_VERSION_LATEST_RELEASE & " for corruption..." & @CRLF)
		Json_StringDecode(FileRead($GAME_VERSION_LATEST_RELEASE_JSON_FILE))
		If @error Then
			Exit ConsoleWrite("Info for version " & $GAME_VERSION_LATEST_RELEASE & " corrupted." & @CRLF)
		Else
			ConsoleWrite("Info for version " & $GAME_VERSION_LATEST_RELEASE & " passed corruption check." & @CRLF)
		EndIf
	EndIf
EndIf
$GAME_VERSION_LATEST_RELEASE_JSON_DATA = FileRead($GAME_VERSION_LATEST_RELEASE_JSON_FILE)
$GAME_VERSION_LATEST_RELEASE_JSON_DATA = Json_Decode($GAME_VERSION_LATEST_RELEASE_JSON_DATA)
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ID = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[id]")
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[assetIndex]")
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX, "[id]")
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_URL = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX, "[url]")
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_PATH = $DIR_INDEXES & "\" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & ".json"
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[assets]")
If $GAME_VERSION_LATEST_RELEASE <> $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ID Then
	Exit ConsoleWrite("Error parsing info for version " & $GAME_VERSION_LATEST_RELEASE & ". Selected version is " & $GAME_VERSION_LATEST_RELEASE & " but info for selected version defines version as " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ID & "." & @CRLF)
EndIf
If $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID <> $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETS Then
	Exit ConsoleWrite("Error parsing asset info for version " & $GAME_VERSION_LATEST_RELEASE & ". Asset index wants assets for " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & " but defined assets is " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETS & "." & @CRLF)
EndIf

$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[libraries]")
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_COUNT = UBound($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES)
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST = ""
For $i = 0 To ($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_COUNT - 1)
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES[$i], "[name]")
	ConsoleWrite("Found library " & ($i + 1) & "/" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_COUNT & ": """ & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & @CRLF)
	ConsoleWrite("Parsing logic..." & @CRLF)
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES[$i], "[rules]")
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ALLOWED = True ;Default to true, unless rule states to disallow
	If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES) Then
		For $j = 0 To UBound($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES) - 1
			Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ACTION = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES, "[action]")
			If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ACTION) Then
				Switch $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ACTION
					Case "allow"
						;Allow always seems to be above disallow, so check it first
						;If the day ever comes where it's not above disallow, I'm gonna have to defy logic to make this work again
						Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_OS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES, "[os]")
						If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_OS) Then
							;If we have data to work with, we should make sure windows is allowed
							;If windows isn't listed, continue on to disallow to make sure it's not disallowed
							If IsInArray($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_OS, "windows") Then
								ConsoleWrite("Library usage permitted..." & @CRLF)
								$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ALLOWED = True ;Tell the rest of the library script that we can use this library
								ExitLoop ;Exit the loop and continue downloading the library
							Else
								ConsoleWrite("Library usage unknown..." & @CRLF)
								ContinueLoop ;Nothing about windows here, let's check disallowed...
							EndIf
						Else
							ConsoleWrite("Library usage unknown..." & @CRLF)
							ContinueLoop ;Absolutely nothing specified for some reason, still assuming we're allowed and continuing on to disallowed...
						EndIf
					Case "disallow"
						;Disallow always seems to be below allow, so we'll check this if allow doesn't exist or if this is after allow
						Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_OS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES, "[os]")
						If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_OS) Then
							;Checking to see if windows can pass
							;If windows isn't here, continue on in case allow comes after disallow for some reason
							If IsInArray($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_OS, "windows") Then
								$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ALLOWED = False ;Tell the rest of the library script that we can't use this library
								ExitLoop ;Exit the loop and skip on to the next library
							Else
								ConsoleWrite("Library usage permitted..." & @CRLF)
								$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ALLOWED = True ;Tell the rest of the library that we can use this library, since it's neither allowed nor disallowed
								ExitLoop ;Exit the loop and continue downloading the library
							EndIf
						Else
							ConsoleWrite("Library usage not declared, leaving unknown..." & @CRLF)
							$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ALLOWED = False ;Nothing stating we're allowed, so if there's no disallow we should move on
							ExitLoop ;Absolutely nothing specified for some reason, not allowed to continue with this library...
						EndIf
					Case Else
						Exit ConsoleWrite("Unknown rule logic, aborting mission" & @CRLF)
				EndSwitch
			Else
				ConsoleWrite("Rule logic doens't follow, ignoring... (Mojang, what are you doing?)" & @CRLF)
			EndIf
		Next
	EndIf
	If Not $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_RULES_ALLOWED Then
		ConsoleWrite("Library " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & " is not permitted to run on Windows, moving on to next library..." & @CRLF)
		ContinueLoop ;We can't use this library, move on
	EndIf
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES[$i], "[downloads]")
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_URL = ""
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH = ""
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL = ""
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NATIVES = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES[$i], "[natives]")
	If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NATIVES) Then
		ConsoleWrite("Library " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & " is identified to be a native, following native logic path..." & @CRLF)
		;Follow native logic

		Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NATIVES, "[windows]")
		If @AutoItX64 Then
			$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS, "${arch}", "64")
		Else
			$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS, "${arch}", "32")
		EndIf
		ConsoleWrite("--- " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS & @CRLF)
		If $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS Then
			ConsoleWrite("Setting up for a windows native..." & @CRLF)
			Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS, "[classifiers]")
			Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS, "[" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_NATIVES_WINDOWS & "]")
			If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS) Then
				Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS_URL = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS, "[url]")
				Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS_PATH = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS, "[path]")
				Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS_PATH_LOCAL = $DIR_LIBRARIES & "\" & StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS_PATH, "/", "\")
			Else
				ConsoleWrite("No native for windows, testing for artifact..." & @CRLF)
				Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS, "[artifact]")
				If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS) Then
					Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_URL = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS, "[url]")
					Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS, "[path]")
					Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL = $DIR_LIBRARIES & "\" & StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH, "/", "\")
				Else
					ConsoleWrite("No artifact available, ignoring this library..." & @CRLF)
					ContinueLoop
				EndIf
			EndIf
			$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_URL = $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS_URL
			$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH = $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS_PATH
			$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL = $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_CLASSIFIERS_NATIVES_WINDOWS_PATH_LOCAL
		Else
			ConsoleWrite("No native for windows, testing for artifact..." & @CRLF)
			Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS, "[artifact]")
			If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS) Then
				Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_URL = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS, "[url]")
				Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS, "[path]")
				Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL = $DIR_LIBRARIES & "\" & StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH, "/", "\")
			Else
				ConsoleWrite("No artifact available, ignoring this library..." & @CRLF)
				ContinueLoop
			EndIf
		EndIf
	Else
		ConsoleWrite("Library " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & " seems to be normal, following regular logic path..." & @CRLF)
		;Follow regular logic

		Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS, "[artifact]")
		If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS) Then
			Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_URL = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS, "[url]")
			Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_ARTIFACTS, "[path]")
			Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL = $DIR_LIBRARIES & "\" & StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH, "/", "\")
		Else
			ConsoleWrite("Derp." & @CRLF)
			Exit
		EndIf
	EndIf

	;Yay, we're semi-normal
	Local $TEMP = StringSplit($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH, "/")
	Local $TEMP2 = $DIR_LIBRARIES
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST &= $DIR_LIBRARIES
	For $j = 1 To $TEMP[0]
		If $j < $TEMP[0] Then
			$TEMP2 &= "\" & $TEMP[$j]
		EndIf
		$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST &= "\" & $TEMP[$j]
	Next
	DirCreate($TEMP2)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST &= ";"
	ConsoleWrite($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST & @CRLF)
	$TEMP = 0
	$TEMP2 = 0

	If FileExists($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL) And $mSettings["Overwrite Files"] = False Then
		ConsoleWrite("Library " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & " already exists." & @CRLF)
	Else
		;Download the library
		ConsoleWrite("Downloading library " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "..." & @CRLF)
		Local $hLibraryDownload = InetGet($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_URL, $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL, 1, 1)
		If InetGetInfo($hLibraryDownload, 1) Then
			Do
				Local $aLibraryDownloadInfo = InetGetInfo($hLibraryDownload, -1)
				ConsoleWrite("[LibraryDownload:" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "] " & ($aLibraryDownloadInfo[0] / $aLibraryDownloadInfo[1]) & "% downloaded..." & @CRLF)
				Sleep(50)
			Until InetGetInfo($hLibraryDownload, 2)
		Else
			ConsoleWrite("[LibraryDownload:" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "] Unknown size of download, waiting for download to complete..." & @CRLF)
			ConsoleWrite("[LibraryDownload:" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "] ")
			Do
				ConsoleWrite(".")
				Sleep(50)
			Until InetGetInfo($hLibraryDownload, 2)
			ConsoleWrite(@CRLF)
		EndIf
		If InetGetInfo($hLibraryDownload, 3) Then
			ConsoleWrite("Successfully downloaded library " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "." & @CRLF)
		ElseIf InetGetInfo($hLibraryDownload, 4) Then
			Exit ConsoleWrite("Error downloading library " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "." & @CRLF)
		EndIf
	EndIf

	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES[$i], "[extract]")
	If Json_IsObject($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT) Then
		ConsoleWrite("Extracting " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "..." & @CRLF)
		Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT, "[exclude]")
		Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_ARRAY = $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE
		Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_LIST = ""
		For $j = 0 To UBound($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_ARRAY) - 1
			ConsoleWrite("Excluding " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_ARRAY[$j] & "..." & @CRLF)
			$GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_LIST &= " -xr!" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_ARRAY[$j]
		Next
		If StringRight($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_LIST, 1) = ";" Then $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_LIST = StringTrimRight($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_LIST, 1)
		DirCreate($DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\natives-win")
		If @AutoItX64 Then
			RunWait("""" & @ScriptDir & "\7-Zip\x64\7za.exe"" x """ & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL & """ -o""" & $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\natives-win""" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_LIST & " -aoa", "", @SW_HIDE, 0x10)
		Else
			RunWait("""" & @ScriptDir & "\7-Zip\x86\7za.exe"" x """ & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_DOWNLOADS_PATH_LOCAL & """ -o""" & $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\natives-win""" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_EXTRACT_EXCLUDE_LIST & " -aoa", "", @SW_HIDE, 0x10)
		EndIf
		ConsoleWrite("Finished extracting " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_NAME & "." & @CRLF)
		ContinueLoop
	EndIf
Next
If StringRight($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST, 1) = ";" Then $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST = StringTrimRight($GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST, 1)

If FileExists($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_PATH) & $mSettings["Overwrite Files"] = False Then
	ConsoleWrite("Asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & " already exists, checking for corruption..." & @CRLF)
	Json_StringDecode(FileRead($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_PATH))
	If @error Then
		ConsoleWrite("Asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & " corrupted." & @CRLF)
		ConsoleWrite("Downloading asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & "..." & @CRLF)
		InetGet($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_URL, $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_PATH)
		If @error Then
			Exit ConsoleWrite("Error downloading asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & "." & @CRLF)
		Else
			ConsoleWrite("Successfully downloaded asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & "." & @CRLF)
			ConsoleWrite("Checking asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & " for corruption..." & @CRLF)
			Json_StringDecode(FileRead($FILE_VERSION_MANIFEST))
			If @error Then
				Exit ConsoleWrite("Asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & " corrupted." & @CRLF)
			Else
				ConsoleWrite("Asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & " passed corruption check." & @CRLF)
			EndIf
		EndIf
	Else
		ConsoleWrite("Asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & " passed corruption check." & @CRLF)
	EndIf
Else
	ConsoleWrite("Downloading asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & "..." & @CRLF)
	InetGet($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_URL, $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_PATH)
	If @error Then
		Exit ConsoleWrite("Error downloading asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & "." & @CRLF)
	Else
		ConsoleWrite("Successfully downloaded asset index " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID & "." & @CRLF)
	EndIf
EndIf
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA = FileRead($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_PATH)
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA = Json_Decode($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA)
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA, "[objects]")
$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_ARRAY = Json_ObjGetKeys($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS)
For $i = 0 To UBound($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_ARRAY) - 1
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME = $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_ARRAY[$i]
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS, "[" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME & "][hash]")
	ConsoleWrite("Found asset #" & ($i + 1) & ": " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME & "|" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH & @CRLF)
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_URL = $URL_RESOURCE_BASE & StringLeft($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH, 2) & "/" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_SIZE = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS, "[" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_ARRAY[$i] & "][size]")
	Local $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_PATH = $DIR_OBJECTS & "\" & StringLeft($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH, 2) & "/" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH
	DirCreate($DIR_OBJECTS & "\" & StringLeft($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH, 2))
	If FileExists($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_PATH) And $mSettings["Overwrite Files"] = False Then
		ConsoleWrite("Hash #" & ($i + 1) & " already exists." & @CRLF)
	Else
		ConsoleWrite("Downloading hash #" & ($i + 1) & "..." & @CRLF)
		Local $hHashDownload = InetGet($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_URL, $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_PATH, 1, 1)
		If InetGetInfo($hHashDownload, 1) Then
			Do
				Local $aHashDownloadInfo = InetGetInfo($hHashDownload, -1)
				ConsoleWrite("[HashDownload:" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME & "] " & ($aHashDownloadInfo[0] / $aHashDownloadInfo[1]) & "% downloaded..." & @CRLF)
				Sleep(50)
			Until InetGetInfo($hHashDownload, 2)
		Else
			ConsoleWrite("[HashDownload:" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME & "] Expected size of download is " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_SIZE & ", waiting for download to complete..." & @CRLF)
			ConsoleWrite("[HashDownload:" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME & "] ")
			Do
				ConsoleWrite(".")
				Sleep(50)
			Until InetGetInfo($hHashDownload, 2)
			ConsoleWrite(@CRLF)
		EndIf
		If InetGetInfo($hHashDownload, 3) Then
			ConsoleWrite("Successfully downloaded hash #" & ($i + 1) & "." & @CRLF)
		ElseIf InetGetInfo($hHashDownload, 4) Then
			Exit ConsoleWrite("Error downloading hash #" & ($i + 1) & "." & @CRLF)
		EndIf
		ConsoleWrite("Copying asset into virtual legacy folder..." & @CRLF)
	EndIf
	If FileExists($DIR_VIRTUAL_LEGACY & "\" & StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME, "/", "\")) & $mSettings["Overwrite Files"] = False Then
		ConsoleWrite("Asset already exists in virtual legacy folder." & @CRLF)
	Else
		ConsoleWrite("Copying asset into virtual legacy folder..." & @CRLF)

		Local $TEMP = StringSplit(StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME, "/", "\"), "\")
		Local $TEMP2 = $DIR_VIRTUAL_LEGACY
		For $j = 1 To $TEMP[0]
			If $j < $TEMP[0] Then
				$TEMP2 &= "\" & $TEMP[$j]
			EndIf
		Next
		DirCreate($TEMP2)
		$TEMP = 0
		$TEMP2 = 0

		FileCopy($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_HASH_PATH, $DIR_VIRTUAL_LEGACY & "\" & StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_DATA_OBJECTS_NAME, "/", "\"))
	EndIf
Next

If $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID = "legacy" Then
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_MAINCLASS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[mainClass]")
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[minecraftArguments]")
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${auth_player_name}", $AUTH_PROFILE)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${auth_session}", $AUTH_SESSION_ID)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${version_name}", $GAME_VERSION_LATEST_RELEASE)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${game_directory}", $DIR_BASE)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${game_assets}", $DIR_VIRTUAL_LEGACY)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = "-Xms512m -Xmx1024m -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -XX:-UseAdaptiveSizePolicy ""-Dos.name=Windows 10"" -Dos.version=10.0 -Djava.library.path=""" & $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\natives-win"" -cp " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST & ";" & $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\" & $GAME_VERSION_LATEST_RELEASE & ".jar " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_MAINCLASS & " " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS
Else
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_MAINCLASS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[mainClass]")
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = Json_Get($GAME_VERSION_LATEST_RELEASE_JSON_DATA, "[minecraftArguments]")
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${auth_player_name}", $AUTH_PROFILE)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${version_name}", $GAME_VERSION_LATEST_RELEASE)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${game_directory}", $DIR_BASE)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${assets_root}", $DIR_ASSETS)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${assets_index_name}", $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ASSETINDEX_ID)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${auth_uuid}", $AUTH_UUID)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${auth_access_token}", $AUTH_ACCESS_TOKEN)
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${user_type}", "mojang")
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = StringReplace($GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, "${version_type}", "release")
	$GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS = "-Xms512m -Xmx1024m -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -XX:-UseAdaptiveSizePolicy ""-Dos.name=Windows 10"" -Dos.version=10.0 -Djava.library.path=""" & $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\natives-win"" -cp " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_LIBRARIES_PATH_LIST & ";" & $DIR_VERSIONS & "\" & $GAME_VERSION_LATEST_RELEASE & "\" & $GAME_VERSION_LATEST_RELEASE & ".jar " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_MAINCLASS & " " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS
EndIf


ConsoleWrite("Launching version " & $GAME_VERSION_LATEST_RELEASE & "'s main class [" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_MAINCLASS & "] using arguments [" & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS & "]..." & @CRLF)
$GAME_PROCESS = Run("" & $DIR_JAVA & "\javaw.exe " & "" & " " & $GAME_VERSION_LATEST_RELEASE_JSON_DATA_ARGUMENTS, $DIR_BASE, @SW_SHOW, 0x10)
ProcessWait($GAME_PROCESS)

While 1
	If Not ProcessExists($GAME_PROCESS) Then Exit
WEnd


;;;;

Func Auth_Login_Token($sValidateURL, ByRef $AUTH_ACCESS_TOKEN, ByRef $AUTH_CLIENT_TOKEN)
	Local $sSession_Data = _POST($sValidateURL, '{"accessToken":"' & $AUTH_ACCESS_TOKEN & '","clientToken":"' & $AUTH_CLIENT_TOKEN & '"}', "Content-type:application/json")
	If Not $sSession_Data Then
		Return True
	Else
		Return SetError(1, 0, $sSession_Data)
	EndIf
EndFunc   ;==>Auth_Login_Token
Func Auth_Login_Password($sAuthenticateURL, $sUsername, $sPassword, $sClientIdentifier, ByRef $AUTH_ACCESS_TOKEN, ByRef $AUTH_CLIENT_TOKEN, ByRef $AUTH_UUID, ByRef $AUTH_PROFILE)
	Local $sSession_Data = _POST($sAuthenticateURL, '{"agent":{"name":"Minecraft","version":1},"username":"' & $sUsername & '","password":"' & $sPassword & '","clientToken":"' & $sClientIdentifier & '"}', "Content-type:application/json")
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
EndFunc   ;==>Auth_Login_Password
Func _POST($sURL, $sData = "", $sDelimitedRequestHeaders = "")
	$oHTTP = ObjCreate("winhttp.winhttprequest.5.1")
	$oHTTP.Open("POST", $sURL)
	If $sDelimitedRequestHeaders Then
		Local $aRequestHeaders = StringSplit($sDelimitedRequestHeaders, ";")
		If @error Then
			Local $aRequestHeader = StringSplit($sDelimitedRequestHeaders, ":")
			If @error Then
				ConsoleWrite("Error trying to parse request headers: " & $sDelimitedRequestHeaders & @CRLF)
			Else
				$oHTTP.SetRequestHeader($aRequestHeader[1], $aRequestHeader[2])
			EndIf
		Else
			For $i = 1 To $aRequestHeaders[0]
				Local $aRequestHeader = StringSplit($aRequestHeaders[$i], ":")
				If @error Then
					ConsoleWrite("Error trying to parse request headers: " & $sDelimitedRequestHeaders & @CRLF)
				Else
					$oHTTP.SetRequestHeader($aRequestHeader[1], $aRequestHeader[2])
				EndIf
			Next
		EndIf
	EndIf
	$oHTTP.Send(StringToBinary($sData))
	$HTMLSource = $oHTTP.ResponseText
	Return $HTMLSource
EndFunc   ;==>_POST
Func IsInArray($aArray, $sString)
	If Not IsArray($aArray) Then Return SetError(1, 0, False)
	For $i = 0 To UBound($aArray) - 1
		If $aArray[$i] = $sString Then Return SetError(0, 0, True)
	Next
	Return SetError(0, 0, False)
EndFunc   ;==>IsInArray
