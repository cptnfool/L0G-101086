# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# This module contains several functions which are shared between the scripts
# related to uploading and formatting GW2 ArcDPS log files. It contains some
# general purpose utility functions, as well as functions related to managing
# the configuration file

<#
 .Synopsis
  Tests whether a path exists

 .Description
  Tests wither a given path exists. It is safe to pass a $null value to this
  function, as it will return $false in that case.

 .Parameter Path
  The path to test
#>
Function X-Test-Path {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$path)
    try {
        return Test-Path $path.trim()
    } catch {
        return $false
    }
}

<#
 .Synopsis
  Convert UTC time to the local timezone

 .Description
  Take a UTC date time object containing a UTC time and convert it to the
  local time zone

 .Parameter Time
  The UTC time value to convert
#>
Function ConvertFrom-UTC {
    [CmdletBinding()]
    param([Parameter(Mandatory)][DateTime]$time)
    [TimeZone]::CurrentTimeZone.ToLocalTime($time)
}


<#
 .Synopsis
  Convert a Unix timestamp to a DateTime object

 .Description
  Given a Unix timestamp (integer containing seconds since the Unix Epoch),
  convert it to a DateTime object representing the same time.

 .Parameter UnixDate
  The Unix timestamp to convert
#>
Function ConvertFrom-UnixDate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$UnixDate)
    ConvertFrom-UTC ([DateTime]'1/1/1970').AddSeconds($UnixDate)
}

<#
 .Synopsis
  Convert DateTime object into a Unix timestamp

 .Description
  Given a DateTime object, convert it to an integer representing seconds since
  the Unix Epoch.

 .Parameter Date
  The DateTime object to convert
#>
Function ConvertTo-UnixDate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][DateTime]$Date)
    $UnixEpoch = [DateTime]'1/1/1970'
    (New-TimeSpan -Start $UnixEpoch -End $Date).TotalSeconds
}

<#
 .Synopsis
  Returns the NoteProperties of a PSCustomObject

 .Description
  Given a PSCustomObject, return the names of each NoteProperty in the object

 .Parameter obj
  The PSCustomObject to match
#>
Function Keys {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$obj)

    return @($obj | Get-Member -MemberType NoteProperty | % Name)
}

<#
 .Description
  Configuration fields which are valid for multiple versions of the
  configuration file. Currently this is shared between the v1 and v2
  formats, as they share a common base of configuration fields.

  If path is set, then the configuration will allow exchanging %UserProfile%
  for the current $env:USERPROFILE value

  If validFields is set to an array if fields, then the subfield will be
  recursively validated. If arrayFields is set, then the field will be treated as
  an array of objects and each object in the array will be recursively validated.

  Path, validFields, and arrayFields are mutually exclusive
#>
$commonConfigurationFields =
@(
    @{
        # Version indicating the format of the configuration file
        name="config_version"
        type=[int]
    }
    @{
        # Setting debug_mode to true will modify some script behaviors
        name="debug_mode"
        type=[bool]
    }
    @{
        # Setting experimental_arcdps will cause update-arcdps.ps1 to
        # download the experimental version of ArcDPS instead of the
        # stable version
        name="experimental_arcdps"
        type=[bool]
    }
    @{
        # Path to the EVTC combat logs generated by ArcDPS
        name="arcdps_logs"
        type=[string]
        path=$true
    }
    @{
        # Path to a folder for storing the JSON we send to a discord webhook
        # Intended for debugging if the logs do not format correctly.
        name="discord_json_data"
        type=[string]
        path=$true
    }
    @{
        # Path to folder to store extra data about local EVTC encounter files
        # Will contain files in the JSON format which have data exracted
        # from the EVTC log file using simpleArcParse.
        name="extra_upload_data"
        type=[string]
        path=$true
    }
    @{
        # Path to a folder which will act as a mini database mapping encounter start times
        # together to the local EVTC file and extra upload data. This is used so that we
        # can correlate gw2raidar logs with the local data and dps.report links
        name="gw2raidar_start_map"
        type=[string]
        path=$true
    }
    @{
        # Path to a file which stores the last time that we formatted logs to discord
        # Used to ensure that we don't re-post old logs. Disabled if debug_mode is true
        name="last_format_file"
        type=[string]
        path=$true
    }
    @{
        # Path to file to store the last time that we uploaded logs to gw2raidar and dps.report
        # This is *not* disabled when debug_mode is true, because we don't want to spam
        # the uploads of old encounters.
        name="last_upload_file"
        type=[string]
        path=$true
    }
    @{
        # Path to the compiled binary for the simpleArcParse program
        name="simple_arc_parse_path"
        type=[string]
        path=$true
    }
    @{
        # Path to a file which logs actions and data generated while uploading logs
        name="upload_log_file"
        type=[string]
        path=$true
    }
    @{
        # Path to a file which logs actions and data generated while formatting to discord
        name="format_encounters_log"
        type=[string]
        path=$true
    }
    @{
        # Path to the GW2 installation directory
        name="guildwars2_path"
        type=[string]
        path=$true
    }
    @{
        # Path to Launch Buddy program (used by launcher.ps1)
        name="launchbuddy_path"
        type=[string]
        path=$true
    }
    @{
        # Path to a folder which holds backups of DLLs for arcdps, and related plugins
        name="dll_backup_path"
        type=[string]
        path=$true
    }
    @{
        # Path to the RestSharp DLL used for contacting gw2raidar and dps.report
        name="restsharp_path"
        type=[string]
        path=$true
    }
    @{
        # The gw2raidar API token used with your account. Used to upload encounters to
        # gw2raidar, as well as look up previously uploaded encounter data.
        name="gw2raidar_token"
        type=[string]
    }
    @{
        # An API token used by dps.report. Not currently required by dps.report but
        # may be used in a future API update to allow searching for previously uploaded
        # logs.
        name="dps_report_token"
        type=[string]
    }
    @{
        # dps.report allows using alternative generators besides raid heros. This parameter
        # is used to configure the generator used by the site, and must match a valid value
        # from their API. Currently "rh" means RaidHeros, "ei" means EliteInsights, and
        # leaving it blank will use the current default generator.
        name="dps_report_generator"
        type=[string]
    }
)

<#
 .Description
  Configuration fields which are valid for a v1 configuration file. Anything
  not listed here will be excluded from the generated $config object. If one
  of the fields has an incorrect type, configuration will fail to be validated.

  Fields which are common to many versions of the configuration file are stored
  in $commonConfigurationFields
#>
$v1ConfigurationFields = $commonConfigurationFields +
@(
    @{
        name="custom_tags_script"
        type=[string]
        path=$true
    }
    @{
        name="discord_webhook"
        type=[string]
    }
    @{
        name="guild_thumbnail"
        type=[string]
    }
    @{
        name="gw2raidar_tag_glob"
        type=[string]
    }
    @{
        name="guild_text"
        type=[string]
    }
    @{
        name="discord_map"
        type=[PSCustomObject]
    }
    @{
        name="emoji_map"
        type=[PSCustomObject]
    }
    @{
        name="publish_fractals"
        type=[bool]
    }
)

<#
 .Description
  Configuration fields which are valid for a v2 configuration file. Anything
  not listed here will be excluded from the generated $config object. If one
  of the fields has an incorrect type, configuration will fail to be validated.

  Fields which are common to many versions of the configuration file are stored
  in $commonConfigurationFields
#>
$v2ValidGuildFields =
@(
    @{
        # The name of this guild
        name="name"
        type=[string]
    }
    @{
        # Priority for determining which guild ran an encounter if there are
        # conflicts. Lower numbers win ties.
        name="priority"
        type=[int]
    }
    @{
        # Tag to add when uploading to gw2raidar.
        name="gw2raidar_tag"
        type=[string]
    }
    @{
        # Category to use when uploading to gw2raidar.
        # 1: Guild/ Static
        # 2: Training
        # 3: PUG
        # 4: Low Man / Sells
        name="gw2raidar_category"
        type=[int]
    }
    @{
        # Minimum number of players required for an encounter to be considered
        # a guild run. 0 indicates any encounter can be considered if there is
        # no better guild available
        name="threshold"
        type=[int]
    }
    @{
        # The discord webhook URL for this guild
        name="webhook_url"
        type=[string]
    }
    @{
        # URL to a thumbnail image for this guild
        name="thumbnail"
        type=[string]
    }
    @{
        # Set this to true if this guild should be considered for fractal
        # challenge motes. If set to false, fractals will never be posted
        # to this guild.
        name="fractals"
        type=[bool]
    }
    @{
        # Set of gw2 account names associated with this guild, mapped to
        # their discord account ids. Used as the primary mechanism to determine
        # which guild the encounter was run by, as well as for posting player pings
        # to the discord webhook.
        name="discord_map"
        type=[PSCustomObject]
    }
    @{
        # emoji IDs used to provide pictures for each boss. Due to limitations of
        # the webhook API, we can't use normal image URLs, but only emojis
        # Each boss can have one emoji associated. If the map is empty for that boss
        # then only the boss name will appear, without any emoji icon.
        name="emoji_map"
        type=[PSCustomObject]
    }
    @{
        # If set to true, format-encounters will publish every post to this guilds
        # discord. If unset or if set to false, only the encounters which match
        # this guild will be published to the guild's discord.
        name="everything"
        type=[bool]
        optional=$true
    }
)

$v2ConfigurationFields = $commonConfigurationFields +
@(
    @{
        name="guilds"
        type=[Object[]]
        arrayFields=$v2ValidGuildFields
    }
)

<#
 .Description
 An enumeration defining methods for converting path-like fields

 This enumeration defines the methods of converting path-like strings, which
 support reading %UserProfile% as the $env.UserProfile environment variable.

 FromUserProfile will allow converting the %UserProfile% string to the
 UserProfile environment variable when reading the config in from disk.

 ToUserProfile will allow converting the value of the UserProfile environment
 variable into %UserProfile% when writing back out to disk.
#>
Add-Type -TypeDefinition @"
    public enum PathConversion
    {
        FromUserProfile,
        ToUserProfile,
    }
"@

<#
 .Synopsis
  Validate fields of an object

 .Description
  Given a set of field definitions, validate that the given object has fields
  of the correct type, possibly recursively.

  Return the object on success, with updated path data if necessary. Unknown fields
  will be removed from the returned object.

  Return $null if the object has invalid fields or is missing required fields.

 .Parameter object
  The object to validate

 .Parameter fields
  The field definition

 .Parameter RequiredFields
  Specifies which fiels are required to exist. If a required field is missing, an error is
  generated.

 .Parameter conversion using the PathConversion enum
  Optional parameter specifying how to convert path-like configuration values. The
  default mode is to convert from %UserProfile% to the environment value for UserProfile
#>
Function Validate-Object-Fields {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$Object,
          [Parameter(Mandatory)][array]$Fields,
          [Parameter(Mandatory)][AllowEmptyCollection()][array]$RequiredFields,
          [PathConversion]$conversion = [PathConversion]::FromUserProfile)

    # Make sure all the required parameters are actually valid
    ForEach ($parameter in $RequiredFields) {
        if ($parameter -notin ($Fields | ForEach-Object { $_.name })) {
            Read-Host -Prompt "BUG: $parameter is not a valid parameter. Press enter to exit"
            exit
        }
    }

    # Select only the known properties, ignoring unknown properties
    $Object = $Object | Select-Object -Property ($Fields | ForEach-Object { $_.name } | where { $Object."$_" -ne $null })

    $invalid = $false
    foreach ($field in $Fields) {
        # Make sure required parameters are available
        if (-not (Get-Member -InputObject $Object -Name $field.name)) {
            if ($field.name -in $RequiredFields) {
                Write-Host "$($field.name) is a required parameter for this script."
                $invalid = $true
            }
            continue
        }

        # Make sure that the field has the expected type
        if ($Object."$($field.name)" -isnot $field.type) {
            Write-Host "$($field.name) has an unexpected type [$($Object."$($field.name)".GetType().name)]"
            $invalid = $true
            continue;
        }

        if ($field.path) {
            # Handle %UserProfile% in path fields
            switch ($conversion) {
                "FromUserProfile" {
                    $Object."$($field.name)" = $Object."$($field.name)".replace("%UserProfile%", $env:USERPROFILE)
                }
                "ToUserProfile" {
                    $Object."$($field.name)" = $Object."$($field.name)".replace($env:USERPROFILE, "%UserProfile%")
                }
            }
        } elseif ($field.validFields) {
            # Recursively validate subfields. All fields not explicitly marked "optional" must be present
            $Object."$($field.name)" = Validate-Object-Fields $Object."$($field.name)" $field.validFields ($field.validFields | where { -not ( $_.optional -eq $true ) } | ForEach-Object { $_.name } )
        } elseif ($field.arrayFields) {
            # Recursively validate subfields of an array of objects. All fields not explicitly marked "optional" must be present
            $ValidatedSubObjects = @()

            $arrayObjectInvalid = $false

            ForEach ($SubObject in $Object."$($field.name)") {
                $SubObject = Validate-Object-Fields $SubObject $field.arrayFields ($field.arrayFields | where { -not ( $_.optional -eq $true ) } | ForEach-Object { $_.name } )
                if (-not $SubObject) {
                    $arrayObjectInvalid = $true
                    break;
                }
                $ValidatedSubObjects += $SubObject
            }
            # If any of the sub fields was invalid, the whole array is invalid
            if ($arrayObjectInvalid) {
                $Object."$($field.name)" = $null
            } else {
                $Object."$($field.name)" = $ValidatedSubObjects
            }
        }

        # If the subfield is now null, then the recursive validation failed, and this whole field is invalid
        if ($Object."$($field.name)" -eq $null) {
            $invalid = $true
        }
    }

    if ($invalid) {
        Read-Host -Prompt "Configuration file has invalid parameters. Press enter to exit"
        return
    }

    return $Object
}

<#
 .Synopsis
  Validate a configuration object to make sure it has correct fields

 .Description
  Take a $config object, and verify that it has valid parameters with the expected
  information and types. Return the $config object on success (with updated path names)
  Return $null if the $config object is not valid.

 .Parameter config
  The configuration object to validate

 .Parameter version
  The expected configuration version, used to ensure that the config object matches
  the configuration version used by the script requesting it.

 .Parameter RequiredParameters
  The parameters that are required by the invoking script

 .Parameter conversion using the PathConversion enum
  Optional parameter specifying how to convert path-like configuration values. The
  default mode is to convert from %UserProfile% to the environment value for UserProfile
#>
Function Validate-Configuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][int]$version,
          [Parameter(Mandatory)][AllowEmptyCollection()][array]$RequiredParameters,
          [PathConversion]$conversion = [PathConversion]::FromUserProfile)

    if ($version -eq 1) {
        $configurationFields = $v1ConfigurationFields
    } elseif ($version -eq 2) {
        $configurationFields = $v2ConfigurationFields
    } else {
        Read-Host -Prompt "BUG: configuration validation does not support version ${version}. Press enter to exit"
        exit
    }

    # Make sure the config_version is set to 1. This should only be bumped if
    # the expected configuration names change. New fields should not cause a
    # bump in this version, but only removal or change of fields.
    #
    # Scripts should be resilient against new parameters not being configured.
    if ($config.config_version -ne $version) {
        Read-Host -Prompt "This script only knows how to understand config_version=${version}. Press enter to exit"
        return
    }

    $config = Validate-Object-Fields $config $configurationFields $RequiredParameters $conversion

    return $config
}

<#
 .Synopsis
  Load the configuration file and return a configuration object

 .Description
  Load the specified configuration file and return a valid configuration
  object. Will ignore unknown fields in the configuration JSON, and will
  convert magic path strings in path-like fields

 .Parameter ConfigFile
  The configuration file to load

 .Parameter version
  The version of the config file we expect, defaults to 1 currently.

 .Parameter RequiredParameters
  An array of parameters required by the script. Will ensure that the generated
  config object has non-null values for the specified paramters. Defaults to
  an empty array, meaning no parameters are required.
#>
Function Load-Configuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigFile,
          [int]$version = 2,
          [AllowEmptyCollection()][array]$RequiredParameters = @())

    # Check that the configuration file path is valid
    if (-not (X-Test-Path $ConfigFile)) {
        Read-Host -Prompt "Unable to locate the configuration file. Press enter to exit"
        return
    }

    # Parse the configuration file and convert it from JSON
    try {
        $config = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
    } catch {
        Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
        Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
        Write-Host "Unable to read the configuration file"
        Read-Host -Prompt "Press enter to exit"
        return
    }

    $config = (Validate-Configuration $config $version $RequiredParameters FromUserProfile)
    if (-not $config) {
        return
    }

    return $config
}

<#
 .Synopsis
  Return true if this is a fractal id, false otherise

 .Parameter id
  The ArcDPS EVTC encounter id
#>
Function Is-Fractal-Encounter {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$id)

    # 99CM and 100CM encounter IDs
    $FractalIds = @(0x427d, 0x4284, 0x4234, 0x44e0, 0x461d, 0x455f)

    return [bool]($id -in $FractalIds)
}

<#
 .Synopsis
  Determine which guild "ran" this encounter.

 .Description
  Given a list of players and an encounter id, determine which guild ran this
  encounter. We determine which guild the encounter belongs to by picking
  the guild who has the most players involved. If there is a tie, we break it
  by the priority.

  If the encounter is a fractal, then only guilds  who have fractals set to
  true will be considered. Thus, even if one guild has more members in the
  encounter, but does not have have fractals set to true, the encounter
  may be associated with the smaller guild in this case.

 .Parameter guilds
  The array of guilds to consider

 .Parameter players
  An array of players who were involved in this encounter

 .Parameter id
  The encounter id, used to determine whether this was a fractal
#>
Function Determine-Guild {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Object[]]$Guilds,
          [Parameter(Mandatory)][array]$Players,
          [Parameter(Mandatory)][int]$id)

    # First remove any non-fractal guilds
    if (Is-Fractal-Encounter $id) {
        $AvailableGuilds = $Guilds | where { $_.fractals }
    } else {
        $AvailableGuilds = $Guilds
    }

    $GuildData = $AvailableGuilds | ForEach-Object {
        $guild = $_
        $activeMembers = @($players | where {(Keys $guild.discord_map) -Contains $_}).Length

        # Only consider this guild if it meets the player threshold
        if ($activeMembers -lt $guild.threshold) {
            return
        }

        # Return a data object indicating the name, priority, and number of
        # active members in this encounter
        return [PSCustomObject]@{
            name = $guild.name
            priority = $guild.priority
            activeMembers = $activeMembers
        }
    }

    # No suitable guild was found
    if ($GuildData.Length -eq 0) {
        return
    }

    # Return the name of the most eligible guild
    return @($GuildData | Sort-Object @{Expression="activeMembers";Descending=$true},priority)[0].name
}

<#
 .Synopsis
  Print out details about an exception that occurred.

 .Description
  Write out details about an exception that was caught.

 .Parameter e
  The exception object to dump.
#>
Function Write-Exception {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Object]$e)

    # Combine the exception and invocation parameters together into a single list
    $info = $e.InvocationInfo | Select *
    $e.Exception | Get-Member -MemberType Property | ForEach-Object {
        $info | Add-Member -MemberType NoteProperty -Name $_.Name -Value ( $e.Exception | Select-Object -ExpandProperty $_.Name )
    }

    Write-Error ( $info | Format-List -Force | Out-String) -ErrorAction Continue
}

<#
 .Synopsis
  Write configuration object back out to a file

 .Description
  Writes the given configuration object back out to a file. It will also convert the profile
  directory back to %UserProfile% so that the config is more easily re-usable.

 .Parameter config
  The config object to print out

 .Parameter file
  The path to the configuration file
#>
Function Write-Configuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$Config,
          [Parameter(Mandatory)][string]$ConfigFile,
          [Parameter(Mandatory)][string]$BackupFile)

    if (X-Test-Path $ConfigFile) {
        if (X-Test-Path $BackupFile) {
            throw "The backup file must be deleted prior to writing out the configuration file"
        }
        Move-Item $ConfigFile $BackupFile
    }

    # Make sure any changes are valid. Convert the UserProfile path back to %UserProfile%.
    $writeConfig = (Validate-Configuration $Config $Config.config_version @() ToUserProfile)
    if (-not $writeConfig) {
        throw "The configuration object is not valid."
    }

    # Write out the configuration to disk
    $writeConfig | ConvertTo-Json -Depth 10 | Out-File -Force $ConfigFile
}