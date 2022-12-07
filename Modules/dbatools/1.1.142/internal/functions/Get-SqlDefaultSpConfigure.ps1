function Get-SqlDefaultSpConfigure {
    <#
        .SYNOPSIS
        Internal function. Returns the default sp_configure options for a given version of SQL Server.

        .NOTES
        Server Configuration Options BOL (links subject to change):
        SQL Server 2019 - https://technet.microsoft.com/en-us/library/ms189631(v=sql.150).aspx
        SQL Server 2017 - https://technet.microsoft.com/en-us/library/ms189631(v=sql.140).aspx
        SQL Server 2016 - https://technet.microsoft.com/en-us/library/ms189631(v=sql.130).aspx
        SQL Server 2014 - http://technet.microsoft.com/en-us/library/ms189631(v=sql.120).aspx
        SQL Server 2012 - http://technet.microsoft.com/en-us/library/ms189631(v=sql.110).aspx
        SQL Server 2008 R2 - http://technet.microsoft.com/en-us/library/ms189631(v=sql.105).aspx
        SQL Server 2008 - http://technet.microsoft.com/en-us/library/ms189631(v=sql.100).aspx
        SQL Server 2005 - http://technet.microsoft.com/en-us/library/ms189631(v=sql.90).aspx
        SQL Server 2000 - http://technet.microsoft.com/en-us/library/aa196706(v=sql.80).aspx (requires PDF download)

        .EXAMPLE
        Get-SqlDefaultSpConfigure -SqlVersion 11
        Returns a list of sp_configure (sys.configurations) items for SQL 2012.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias("Version")]
        [object]$SqlVersion
    )

    switch ($SqlVersion) {

        #region SQL2000
        8 {
            [pscustomobject]@{
                "affinity mask"                  = 0
                "allow updates"                  = 0
                "awe enabled"                    = 0
                "c2 audit mode"                  = 0
                "cost threshold for parallelism" = 5
                "Cross DB Ownership Chaining"    = 0
                "cursor threshold"               = -1
                "default full-text language"     = 1033
                "default language"               = 0
                "fill factor (%)"                = 0
                "index create memory (KB)"       = 0
                "lightweight pooling"            = 0
                "locks"                          = 0
                "max degree of parallelism"      = 0
                "max server memory (MB)"         = 2147483647
                "max text repl size (B)"         = 65536
                "max worker threads"             = 255
                "media retention"                = 0
                "min memory per query (KB)"      = 1024
                "min server memory (MB)"         = 0
                "nested triggers"                = 1
                "network packet size (B)"        = 4096
                "open objects"                   = 0
                "priority boost"                 = 0
                "query governor cost limit"      = 0
                "query wait (s)"                 = -1
                "recovery interval (min)"        = 0
                "remote access"                  = 1
                "remote login timeout (s)"       = 20
                "remote proc trans"              = 0
                "remote query timeout (s)"       = 600
                "scan for startup procs"         = 0
                "set working set size"           = 0
                "show advanced options"          = 0
                "two digit year cutoff"          = 2049
                "user connections"               = 0
                "user options"                   = 0
            }
        }
        #endregion SQL2000

        #region SQL2005
        9 {
            [pscustomobject]@{
                "Ad Hoc Distributed Queries"         = 0
                "affinity I/O mask"                  = 0
                "affinity64 I/O mask"                = 0
                "affinity mask"                      = 0
                "affinity64 mask"                    = 0
                "Agent XPs"                          = 0
                "allow updates"                      = 0
                "awe enabled"                        = 0
                "blocked process threshold"          = 0
                "c2 audit mode"                      = 0
                "clr enabled"                        = 0
                "common criteria compliance enabled" = 0
                "cost threshold for parallelism"     = 5
                "cross db ownership chaining"        = 0
                "cursor threshold"                   = -1
                "Database Mail XPs"                  = 0
                "default full-text language"         = 1033
                "default language"                   = 0
                "default trace enabled"              = 1
                "disallow results from triggers"     = 0
                "fill factor (%)"                    = 0
                "ft crawl bandwidth (max)"           = 100
                "ft crawl bandwidth (min)"           = 0
                "ft notify bandwidth (max)"          = 100
                "ft notify bandwidth (min)"          = 0
                "index create memory (KB)"           = 0
                "in-doubt xact resolution"           = 0
                "lightweight pooling"                = 0
                "locks"                              = 0
                "max degree of parallelism"          = 0
                "max full-text crawl range"          = 4
                "max server memory (MB)"             = 2147483647
                "max text repl size (B)"             = 65536
                "max worker threads"                 = 0
                "media retention"                    = 0
                "min memory per query (KB)"          = 1024
                "min server memory (MB)"             = 8
                "nested triggers"                    = 1
                "network packet size (B)"            = 4096
                "Ole Automation Procedures"          = 0
                "open objects"                       = 0
                "PH timeout (s)"                     = 60
                "precompute rank"                    = 0
                "priority boost"                     = 0
                "query governor cost limit"          = 0
                "query wait (s)"                     = -1
                "recovery interval (min)"            = 0
                "remote access"                      = 1
                "remote admin connections"           = 0
                "remote login timeout (s)"           = 20
                "remote proc trans"                  = 0
                "remote query timeout (s)"           = 600
                "Replication XPs"                    = 0
                "scan for startup procs"             = 0
                "server trigger recursion"           = 1
                "set working set size"               = 0
                "show advanced options"              = 0
                "SMO and DMO XPs"                    = 1
                "SQL Mail XPs"                       = 0
                "transform noise words"              = 0
                "two digit year cutoff"              = 2049
                "user connections"                   = 0
                "User Instance Timeout"              = 60
                "user instances enabled"             = 0
                "user options"                       = 0
                "Web Assistant Procedures"           = 0
                "xp_cmdshell"                        = 0
            }
        }

        #endregion SQL2005

        #region SQL2008&2008R2
        10 {
            [pscustomobject]@{
                "access check cache bucket count"    = 0
                "access check cache quota"           = 0
                "Ad Hoc Distributed Queries"         = 0
                "affinity I/O mask"                  = 0
                "affinity64 I/O mask"                = 0
                "affinity mask"                      = 0
                "affinity64 mask"                    = 0
                "Agent XPs"                          = 0
                "allow updates"                      = 0
                "awe enabled"                        = 0
                "backup compression default"         = 0
                "blocked process threshold (s)"      = 0
                "c2 audit mode"                      = 0
                "clr enabled"                        = 0
                "common criteria compliance enabled" = 0
                "cost threshold for parallelism"     = 5
                "cross db ownership chaining"        = 0
                "cursor threshold"                   = -1
                "Database Mail XPs"                  = 0
                "default full-text language"         = 1033
                "default language"                   = 0
                "default trace enabled"              = 1
                "disallow results from triggers"     = 0
                "EKM provider enabled"               = 0
                "filestream access level"            = 0
                "fill factor (%)"                    = 0
                "ft crawl bandwidth (max)"           = 100
                "ft crawl bandwidth (min)"           = 0
                "ft notify bandwidth (max)"          = 100
                "ft notify bandwidth (min)"          = 0
                "index create memory (KB)"           = 0
                "in-doubt xact resolution"           = 0
                "lightweight pooling"                = 0
                "locks"                              = 0
                "max degree of parallelism"          = 0
                "max full-text crawl range"          = 4
                "max server memory (MB)"             = 2147483647
                "max text repl size (B)"             = 65536
                "max worker threads"                 = 0
                "media retention"                    = 0
                "min memory per query (KB)"          = 1024
                "min server memory (MB)"             = 0
                "nested triggers"                    = 1
                "network packet size (B)"            = 4096
                "Ole Automation Procedures"          = 0
                "open objects"                       = 0
                "optimize for ad hoc workloads"      = 0
                "PH timeout (s)"                     = 60
                "precompute rank"                    = 0
                "priority boost"                     = 0
                "query governor cost limit"          = 0
                "query wait (s)"                     = -1
                "recovery interval (min)"            = 0
                "remote access"                      = 1
                "remote admin connections"           = 0
                "remote login timeout (s)"           = 20
                "remote proc trans"                  = 0
                "remote query timeout (s)"           = 600
                "Replication XPs"                    = 0
                "scan for startup procs"             = 0
                "server trigger recursion"           = 1
                "set working set size"               = 0
                "show advanced options"              = 0
                "SMO and DMO XPs"                    = 1
                "SQL Mail XPs"                       = 0
                "transform noise words"              = 0
                "two digit year cutoff"              = 2049
                "user connections"                   = 0
                "User Instance Timeout"              = 60
                "user instances enabled"             = 0
                "user options"                       = 0
                "xp_cmdshell"                        = 0
            }
        }
        #endregion SQL2008&2008R2

        #region SQL2012
        11 {
            [pscustomobject]@{
                "access check cache bucket count"    = 0
                "access check cache quota"           = 0
                "Ad Hoc Distributed Queries"         = 0
                "affinity I/O mask"                  = 0
                "affinity64 I/O mask"                = 0
                "affinity mask"                      = 0
                "affinity64 mask"                    = 0
                "Agent XPs"                          = 0
                "allow updates"                      = 0
                "backup compression default"         = 0
                "blocked process threshold (s)"      = 0
                "c2 audit mode"                      = 0
                "clr enabled"                        = 0
                "common criteria compliance enabled" = 0
                "contained database authentication"  = 0
                "cost threshold for parallelism"     = 5
                "cross db ownership chaining"        = 0
                "cursor threshold"                   = -1
                "Database Mail XPs"                  = 0
                "default full-text language"         = 1033
                "default language"                   = 0
                "default trace enabled"              = 1
                "disallow results from triggers"     = 0
                "EKM provider enabled"               = 0
                "filestream access level"            = 0
                "fill factor (%)"                    = 0
                "ft crawl bandwidth (max)"           = 100
                "ft crawl bandwidth (min)"           = 0
                "ft notify bandwidth (max)"          = 100
                "ft notify bandwidth (min)"          = 0
                "index create memory (KB)"           = 0
                "in-doubt xact resolution"           = 0
                "lightweight pooling"                = 0
                "locks"                              = 0
                "max degree of parallelism"          = 0
                "max full-text crawl range"          = 4
                "max server memory (MB)"             = 2147483647
                "max text repl size (B)"             = 65536
                "max worker threads"                 = 0
                "media retention"                    = 0
                "min memory per query (KB)"          = 1024
                "min server memory (MB)"             = 0
                "nested triggers"                    = 1
                "network packet size (B)"            = 4096
                "Ole Automation Procedures"          = 0
                "open objects"                       = 0
                "optimize for ad hoc workloads"      = 0
                "PH timeout (s)"                     = 60
                "precompute rank"                    = 0
                "priority boost"                     = 0
                "query governor cost limit"          = 0
                "query wait (s)"                     = -1
                "recovery interval (min)"            = 0
                "remote access"                      = 1
                "remote admin connections"           = 0
                "remote login timeout (s)"           = 10
                "remote proc trans"                  = 0
                "remote query timeout (s)"           = 600
                "Replication XPs"                    = 0
                "scan for startup procs"             = 0
                "server trigger recursion"           = 1
                "set working set size"               = 0
                "show advanced options"              = 0
                "SMO and DMO XPs"                    = 1
                "transform noise words"              = 0
                "two digit year cutoff"              = 2049
                "user connections"                   = 0
                "User Instance Timeout"              = 60
                "user instances enabled"             = 0
                "user options"                       = 0
                "xp_cmdshell"                        = 0
            }
        }
        #endregion SQL2012

        #region SQL2014
        12 {
            [pscustomobject]@{
                "access check cache bucket count"    = 0
                "access check cache quota"           = 0
                "Ad Hoc Distributed Queries"         = 0
                "affinity I/O mask"                  = 0
                "affinity64 I/O mask"                = 0
                "affinity mask"                      = 0
                "affinity64 mask"                    = 0
                "Agent XPs"                          = 0
                "allow updates"                      = 0
                "backup checksum default"            = 0
                "backup compression default"         = 0
                "blocked process threshold (s)"      = 0
                "c2 audit mode"                      = 0
                "clr enabled"                        = 0
                "common criteria compliance enabled" = 0
                "contained database authentication"  = 0
                "cost threshold for parallelism"     = 5
                "cross db ownership chaining"        = 0
                "cursor threshold"                   = -1
                "Database Mail XPs"                  = 0
                "default full-text language"         = 1033
                "default language"                   = 0
                "default trace enabled"              = 1
                "disallow results from triggers"     = 0
                "EKM provider enabled"               = 0
                "filestream access level"            = 0
                "fill factor (%)"                    = 0
                "ft crawl bandwidth (max)"           = 100
                "ft crawl bandwidth (min)"           = 0
                "ft notify bandwidth (max)"          = 100
                "ft notify bandwidth (min)"          = 0
                "index create memory (KB)"           = 0
                "in-doubt xact resolution"           = 0
                "lightweight pooling"                = 0
                "locks"                              = 0
                "max degree of parallelism"          = 0
                "max full-text crawl range"          = 4
                "max server memory (MB)"             = 2147483647
                "max text repl size (B)"             = 65536
                "max worker threads"                 = 0
                "media retention"                    = 0
                "min memory per query (KB)"          = 1024
                "min server memory (MB)"             = 0
                "nested triggers"                    = 1
                "network packet size (B)"            = 4096
                "Ole Automation Procedures"          = 0
                "open objects"                       = 0
                "optimize for ad hoc workloads"      = 0
                "PH timeout (s)"                     = 60
                "precompute rank"                    = 0
                "priority boost"                     = 0
                "query governor cost limit"          = 0
                "query wait (s)"                     = -1
                "recovery interval (min)"            = 0
                "remote access"                      = 1
                "remote admin connections"           = 0
                "remote login timeout (s)"           = 10
                "remote proc trans"                  = 0
                "remote query timeout (s)"           = 600
                "Replication XPs"                    = 0
                "scan for startup procs"             = 0
                "server trigger recursion"           = 1
                "set working set size"               = 0
                "show advanced options"              = 0
                "SMO and DMO XPs"                    = 1
                "transform noise words"              = 0
                "two digit year cutoff"              = 2049
                "user connections"                   = 0
                "User Instance Timeout"              = 60
                "user instances enabled"             = 0
                "user options"                       = 0
                "xp_cmdshell"                        = 0
            }
        }
        #endregion SQL2014

        #region SQL2016
        13 {
            [pscustomobject]@{
                "access check cache bucket count"    = 0
                "access check cache quota"           = 0
                "Ad Hoc Distributed Queries"         = 0
                "affinity I/O mask"                  = 0
                "affinity64 I/O mask"                = 0
                "affinity mask"                      = 0
                "affinity64 mask"                    = 0
                "Agent XPs"                          = 0
                "allow polybase export"              = 0
                "allow updates"                      = 0
                "automatic soft-NUMA disabled"       = 0
                "backup checksum default"            = 0
                "backup compression default"         = 0
                "blocked process threshold (s)"      = 0
                "c2 audit mode"                      = 0
                "clr enabled"                        = 0
                "common criteria compliance enabled" = 0
                "contained database authentication"  = 0
                "cost threshold for parallelism"     = 5
                "cross db ownership chaining"        = 0
                "cursor threshold"                   = -1
                "Database Mail XPs"                  = 0
                "default full-text language"         = 1033
                "default language"                   = 0
                "default trace enabled"              = 1
                "disallow results from triggers"     = 0
                "EKM provider enabled"               = 0
                "external scripts enabled"           = 0
                "filestream access level"            = 0
                "fill factor (%)"                    = 0
                "ft crawl bandwidth (max)"           = 100
                "ft crawl bandwidth (min)"           = 0
                "ft notify bandwidth (max)"          = 100
                "ft notify bandwidth (min)"          = 0
                "hadoop connectivity"                = 0
                "index create memory (KB)"           = 0
                "in-doubt xact resolution"           = 0
                "lightweight pooling"                = 0
                "locks"                              = 0
                "max degree of parallelism"          = 0
                "max full-text crawl range"          = 4
                "max server memory (MB)"             = 2147483647
                "max text repl size (B)"             = 65536
                "max worker threads"                 = 0
                "media retention"                    = 0
                "min memory per query (KB)"          = 1024
                "min server memory (MB)"             = 0
                "nested triggers"                    = 1
                "network packet size (B)"            = 4096
                "Ole Automation Procedures"          = 0
                "open objects"                       = 0
                "optimize for ad hoc workloads"      = 0
                "PH timeout (s)"                     = 60
                "polybase network encryption"        = 1
                "precompute rank"                    = 0
                "priority boost"                     = 0
                "query governor cost limit"          = 0
                "query wait (s)"                     = -1
                "recovery interval (min)"            = 0
                "remote access"                      = 1
                "remote admin connections"           = 0
                "remote data archive"                = 0
                "remote login timeout (s)"           = 10
                "remote proc trans"                  = 0
                "remote query timeout (s)"           = 600
                "Replication XPs"                    = 0
                "scan for startup procs"             = 0
                "server trigger recursion"           = 1
                "set working set size"               = 0
                "show advanced options"              = 0
                "SMO and DMO XPs"                    = 1
                "transform noise words"              = 0
                "two digit year cutoff"              = 2049
                "user connections"                   = 0
                "User Instance Timeout"              = 60
                "user instances enabled"             = 0
                "user options"                       = 0
                "xp_cmdshell"                        = 0
            }
        }
        #endregion SQL2016

        #region SQL2017
        14 {
            [pscustomobject]@{
                "access check cache bucket count"    = 0
                "access check cache quota"           = 0
                "Ad Hoc Distributed Queries"         = 0
                "affinity I/O mask"                  = 0
                "affinity mask"                      = 0
                "affinity64 I/O mask"                = 0
                "affinity64 mask"                    = 0
                "Agent XPs"                          = 0
                "allow polybase export"              = 0
                "allow updates"                      = 0
                "automatic soft-NUMA disabled"       = 0
                "backup checksum default"            = 0
                "backup compression default"         = 0
                "blocked process threshold (s)"      = 0
                "c2 audit mode"                      = 0
                "clr enabled"                        = 0
                "clr strict security"                = 1
                "common criteria compliance enabled" = 0
                "contained database authentication"  = 0
                "cost threshold for parallelism"     = 5
                "cross db ownership chaining"        = 0
                "cursor threshold"                   = -1
                "Database Mail XPs"                  = 0
                "default full-text language"         = 1033
                "default language"                   = 0
                "default trace enabled"              = 1
                "disallow results from triggers"     = 0
                "EKM provider enabled"               = 0
                "external scripts enabled"           = 0
                "filestream access level"            = 0
                "fill factor (%)"                    = 0
                "ft crawl bandwidth (max)"           = 100
                "ft crawl bandwidth (min)"           = 0
                "ft notify bandwidth (max)"          = 100
                "ft notify bandwidth (min)"          = 0
                "hadoop connectivity"                = 0
                "index create memory (KB)"           = 0
                "in-doubt xact resolution"           = 0
                "lightweight pooling"                = 0
                "locks"                              = 0
                "max degree of parallelism"          = 0
                "max full-text crawl range"          = 4
                "max server memory (MB)"             = 2147483647
                "max text repl size (B)"             = 65536
                "max worker threads"                 = 0
                "media retention"                    = 0
                "min memory per query (KB)"          = 1024
                "min server memory (MB)"             = 0
                "nested triggers"                    = 1
                "network packet size (B)"            = 4096
                "Ole Automation Procedures"          = 0
                "open objects"                       = 0
                "optimize for ad hoc workloads"      = 0
                "PH timeout (s)"                     = 60
                "polybase network encryption"        = 1
                "precompute rank"                    = 0
                "priority boost"                     = 0
                "query governor cost limit"          = 0
                "query wait (s)"                     = -1
                "recovery interval (min)"            = 0
                "remote access"                      = 1
                "remote admin connections"           = 0
                "remote data archive"                = 0
                "remote login timeout (s)"           = 10
                "remote proc trans"                  = 0
                "remote query timeout (s)"           = 600
                "Replication XPs"                    = 0
                "scan for startup procs"             = 0
                "server trigger recursion"           = 1
                "set working set size"               = 0
                "show advanced options"              = 0
                "SMO and DMO XPs"                    = 1
                "transform noise words"              = 0
                "two digit year cutoff"              = 2049
                "user connections"                   = 0
                "User Instance Timeout"              = 60
                "user instances enabled"             = 0
                "user options"                       = 0
                "xp_cmdshell"                        = 0

            }
        }
        #endregion SQL2017

        #region SQL2019
        15 {
            [pscustomobject]@{
                "access check cache bucket count"    = 0
                "access check cache quota"           = 0
                "Ad Hoc Distributed Queries"         = 0
                "ADR cleaner retry timeout (min)"    = 0
                "ADR Preallocation Factor"           = 0
                "affinity I/O mask"                  = 0
                "affinity mask"                      = 0
                "affinity64 I/O mask"                = 0
                "affinity64 mask"                    = 0
                "Agent XPs"                          = 0
                "allow filesystem enumeration"       = 1
                "allow polybase export"              = 0
                "allow updates"                      = 0
                "automatic soft-NUMA disabled"       = 0
                "backup checksum default"            = 0
                "backup compression default"         = 0
                "blocked process threshold (s)"      = 0
                "c2 audit mode"                      = 0
                "clr enabled"                        = 0
                "clr strict security"                = 0
                "column encryption enclave type"     = 0
                "common criteria compliance enabled" = 0
                "contained database authentication"  = 0
                "cost threshold for parallelism"     = 5
                "cross db ownership chaining"        = 0
                "cursor threshold"                   = 0
                "Database Mail XPs"                  = 0
                "default full-text language"         = 1033
                "default language"                   = 0
                "default trace enabled"              = 0
                "disallow results from triggers"     = 0
                "EKM provider enabled"               = 0
                "external scripts enabled"           = 0
                "filestream access level"            = 0
                "fill factor (%)"                    = 0
                "ft crawl bandwidth (max)"           = 100
                "ft crawl bandwidth (min)"           = 0
                "ft notify bandwidth (max)"          = 100
                "ft notify bandwidth (min)"          = 0
                "hadoop connectivity"                = 0
                "index create memory (KB)"           = 0
                "in-doubt xact resolution"           = 0
                "lightweight pooling"                = 0
                "locks"                              = 0
                "max degree of parallelism"          = 0
                "max full-text crawl range"          = 4
                "max server memory (MB)"             = 2147483647
                "max text repl size (B)"             = 65536
                "max worker threads"                 = 0
                "media retention"                    = 0
                "min memory per query (KB)"          = 1024
                "min server memory (MB)"             = 0
                "nested triggers"                    = 1
                "network packet size (B)"            = 4096
                "Ole Automation Procedures"          = 0
                "open objects"                       = 0
                "optimize for ad hoc workloads"      = 0
                "PH timeout (s)"                     = 60
                "polybase enabled"                   = 0
                "polybase network encryption"        = 1
                "precompute rank"                    = 0
                "priority boost"                     = 0
                "query governor cost limit"          = 0
                "query wait (s)"                     = -1
                "recovery interval (min)"            = 0
                "remote access"                      = 1
                "remote admin connections"           = 0
                "remote data archive"                = 0
                "remote login timeout (s)"           = 10
                "remote proc trans"                  = 0
                "remote query timeout (s)"           = 600
                "Replication XPs"                    = 0
                "scan for startup procs"             = 0
                "server trigger recursion"           = 1
                "set working set size"               = 0
                "show advanced options"              = 0
                "SMO and DMO XPs"                    = 1
                "tempdb metadata memory-optimized"   = 0
                "transform noise words"              = 0
                "two digit year cutoff"              = 2049
                "user connections"                   = 0
                "user options"                       = 0
                "xp_cmdshell"                        = 0
            }
        }
        #endregion SQL2019
    }
}

# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA6uN7lEu1NLW0S
# EPPQfJDdsoBPUViDS/VshP1WNjtzJ6CCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
# Y1+/3q4SBOdtMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNV
# BAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcN
# MjAwNTEyMDAwMDAwWhcNMjMwNjA4MTIwMDAwWjBXMQswCQYDVQQGEwJVUzERMA8G
# A1UECBMIVmlyZ2luaWExDzANBgNVBAcTBlZpZW5uYTERMA8GA1UEChMIZGJhdG9v
# bHMxETAPBgNVBAMTCGRiYXRvb2xzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAvL9je6vjv74IAbaY5rXqHxaNeNJO9yV0ObDg+kC844Io2vrHKGD8U5hU
# iJp6rY32RVprnAFrA4jFVa6P+sho7F5iSVAO6A+QZTHQCn7oquOefGATo43NAadz
# W2OWRro3QprMPZah0QFYpej9WaQL9w/08lVaugIw7CWPsa0S/YjHPGKQ+bYgI/kr
# EUrk+asD7lvNwckR6pGieWAyf0fNmSoevQBTV6Cd8QiUfj+/qWvLW3UoEX9ucOGX
# 2D8vSJxL7JyEVWTHg447hr6q9PzGq+91CO/c9DWFvNMjf+1c5a71fEZ54h1mNom/
# XoWZYoKeWhKnVdv1xVT1eEimibPEfQIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAU
# WsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYEFPDAoPu2A4BDTvsJ193ferHL
# 454iMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8E
# cDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVk
# LWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTIt
# YXNzdXJlZC1jcy1nMS5jcmwwTAYDVR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggr
# BgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEw
# gYQGCCsGAQUFBwEBBHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNl
# cnQuY29tME4GCCsGAQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRTSEEyQXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/
# BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAj835cJUMH9Y2pBKspjznNJwcYmOxeBcH
# Ji+yK0y4bm+j44OGWH4gu/QJM+WjZajvkydJKoJZH5zrHI3ykM8w8HGbYS1WZfN4
# oMwi51jKPGZPw9neGS2PXrBcKjzb7rlQ6x74Iex+gyf8z1ZuRDitLJY09FEOh0BM
# LaLh+UvJ66ghmfIyjP/g3iZZvqwgBhn+01fObqrAJ+SagxJ/21xNQJchtUOWIlxR
# kuUn9KkuDYrMO70a2ekHODcAbcuHAGI8wzw4saK1iPPhVTlFijHS+7VfIt/d/18p
# MLHHArLQQqe1Z0mTfuL4M4xCUKpebkH8rI3Fva62/6osaXLD0ymERzCCBTAwggQY
# oAMCAQICEAQJGBtf1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4X
# DTEzMTAyMjEyMDAwMFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEx
# MC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBD
# QTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsx
# SRnP0PtFmbE620T1f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawO
# eSg6funRZ9PG+yknx9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJ
# RdQtoaPpiCwgla4cSocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEc
# z+ryCuRXu0q16XTmK/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whk
# PlKWwfIPEvTFjg/BougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8l
# k9ECAwEAAaOCAc0wggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQD
# AgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARI
# MEYwOAYKYIZIAYb9bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdp
# Y2VydC5jb20vQ1BTMAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg
# +S32ZXUOWDAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG
# 9w0BAQsFAAOCAQEAPuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/E
# r4v97yrfIFU3sOH20ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3
# nEZOXP+QsRsHDpEV+7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpo
# aK+bp1wgXNlxsQyPu6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW
# 6Fkd6fp0ZGuy62ZD2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ
# 92JuoVP6EpQYhS6SkepobEQysmah5xikmmRR7zCCBY0wggR1oAMCAQICEA6bGI75
# 0C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAw
# MFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGln
# aUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuE
# DcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNw
# wrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs0
# 6wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e
# 5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtV
# gkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85
# tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+S
# kjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1Yxw
# LEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzl
# DlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFr
# b7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATow
# ggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiu
# HA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQE
# AwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2
# hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290
# Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/
# Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNK
# ei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHr
# lnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4
# oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5A
# Y8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNN
# n3O3AamfV6peKOK5lDCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJ
# KoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVow
# YzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQD
# EzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklR
# VcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54P
# Mx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupR
# PfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvo
# hGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV
# 5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYV
# VSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6i
# c/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/Ci
# PMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5
# K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oi
# qMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuld
# yF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAG
# AQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAW
# gBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvH
# UF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0M
# CIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCK
# rOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rA
# J4JErpknG6skHibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZ
# xhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScs
# PT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1M
# rfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXse
# GYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWY
# MbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYp
# hwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPww
# ggbAMIIEqKADAgECAhAMTWlyS5T6PCpKPSkHgD1aMA0GCSqGSIb3DQEBCwUAMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwHhcNMjIwOTIxMDAwMDAwWhcNMzMxMTIxMjM1OTU5WjBGMQswCQYDVQQGEwJV
# UzERMA8GA1UEChMIRGlnaUNlcnQxJDAiBgNVBAMTG0RpZ2lDZXJ0IFRpbWVzdGFt
# cCAyMDIyIC0gMjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAM/spSY6
# xqnya7uNwQ2a26HoFIV0MxomrNAcVR4eNm28klUMYfSdCXc9FZYIL2tkpP0GgxbX
# kZI4HDEClvtysZc6Va8z7GGK6aYo25BjXL2JU+A6LYyHQq4mpOS7eHi5ehbhVsbA
# umRTuyoW51BIu4hpDIjG8b7gL307scpTjUCDHufLckkoHkyAHoVW54Xt8mG8qjoH
# ffarbuVm3eJc9S/tjdRNlYRo44DLannR0hCRRinrPibytIzNTLlmyLuqUDgN5YyU
# XRlav/V7QG5vFqianJVHhoV5PgxeZowaCiS+nKrSnLb3T254xCg/oxwPUAY3ugjZ
# Naa1Htp4WB056PhMkRCWfk3h3cKtpX74LRsf7CtGGKMZ9jn39cFPcS6JAxGiS7uY
# v/pP5Hs27wZE5FX/NurlfDHn88JSxOYWe1p+pSVz28BqmSEtY+VZ9U0vkB8nt9Kr
# FOU4ZodRCGv7U0M50GT6Vs/g9ArmFG1keLuY/ZTDcyHzL8IuINeBrNPxB9Thvdld
# S24xlCmL5kGkZZTAWOXlLimQprdhZPrZIGwYUWC6poEPCSVT8b876asHDmoHOWIZ
# ydaFfxPZjXnPYsXs4Xu5zGcTB5rBeO3GiMiwbjJ5xwtZg43G7vUsfHuOy2SJ8bHE
# uOdTXl9V0n0ZKVkDTvpd6kVzHIR+187i1Dp3AgMBAAGjggGLMIIBhzAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAg
# BgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZ
# bU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFGKK3tBh/I8xFO2XC809KpQU31Kc
# MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAG
# CCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2Vy
# dC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQw
# DQYJKoZIhvcNAQELBQADggIBAFWqKhrzRvN4Vzcw/HXjT9aFI/H8+ZU5myXm93KK
# mMN31GT8Ffs2wklRLHiIY1UJRjkA/GnUypsp+6M/wMkAmxMdsJiJ3HjyzXyFzVOd
# r2LiYWajFCpFh0qYQitQ/Bu1nggwCfrkLdcJiXn5CeaIzn0buGqim8FTYAnoo7id
# 160fHLjsmEHw9g6A++T/350Qp+sAul9Kjxo6UrTqvwlJFTU2WZoPVNKyG39+Xgmt
# dlSKdG3K0gVnK3br/5iyJpU4GYhEFOUKWaJr5yI+RCHSPxzAm+18SLLYkgyRTzxm
# lK9dAlPrnuKe5NMfhgFknADC6Vp0dQ094XmIvxwBl8kZI4DXNlpflhaxYwzGRkA7
# zl011Fk+Q5oYrsPJy8P7mxNfarXH4PMFw1nfJ2Ir3kHJU7n/NBBn9iYymHv+XEKU
# gZSCnawKi8ZLFUrTmJBFYDOA4CPe+AOk9kVH5c64A0JH6EE2cXet/aLol3ROLtoe
# HYxayB6a1cLwxiKoT5u92ByaUcQvmvZfpyeXupYuhVfAYOd4Vn9q78KVmksRAsiC
# nMkaBXy6cbVOepls9Oie1FqYyJ+/jbsYXEP10Cro4mLueATbvdH7WwqocH7wl4R4
# 4wgDXUcsY6glOJcB0j862uXl9uab3H4szP8XTE0AotjWAQ64i+7m4HJViSwnGWH2
# dwGMMYIFXTCCBVkCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQAwW7hiGwoWNf
# v96uEgTnbTANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAM
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDYCloxqqIOQ8TBAfeyu90DGC80
# s1saQF/i8XGrcmPg8DANBgkqhkiG9w0BAQEFAASCAQAdRli3PKRdBC3YvhD7uE07
# Cd+kcOCTEuKrrvsAKY3Q5c0wnaDle1xYl9lHRkdcMzC7LSIah/eiPPAo11YEruJ/
# uYl4O2Z8GHzlRjugEkj+O2q3G/P/PPS+jRtnjW7fAxuIT8vcvjSz1cg4YRwHUqxa
# aQUDN2Hprk9ymyTuiu9PyrNg7wps/xJYIcawMH1kiNSdrw7zY3OrenaBUU5ahsgT
# 9Ov60bstCMOmeMMIoRO7K1rZcs9VnwEuffEHYG0IP0BXtLSj/F9vPfRasuoaK6T2
# QAAlsu+22d2mDgLL2zZ/Pjv6WbCURG+bVMOPkBEYYmDKhDcRVg7HHSc6MJQV13+e
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIyMTAyMjIwMzgyNlowLwYJKoZIhvcNAQkEMSIE
# IC+/P28AHpl3nKr4EHgZXZ5poth/2ZT1+J0vV1uIZdNEMA0GCSqGSIb3DQEBAQUA
# BIICAHnvc9f6Iih8EUoUwQ0/dSAkXEj8Y9GMIiFF7BrRzlLpV5UqHkBNLgaQ6Eu/
# blIZR8m6M0pQeFZkirdeX/hrgTIV6iczC/kvupTaSDZzYxC7eWty+ah3qK3mWHSx
# LjOoocMM4P2i6y3c0ZHWgCuy9KwIt3rQm1kQ6/SDbOKQ0WjnGdJMJUWNwNVasuLF
# v1czThh1OtE67termypF3kE/DEUC4/gyo7elRfRF9fIkQ5sAdFHDffT6Z/ZX0Eq+
# ulE7ehOtvF24PbxlSo6On7vmwO6pV2l3LhnINTClb+9BVcTaQ9amzr19Vk3hpAVc
# uYdU1TuAStcHKl2F5KFFxyMJ5xaKMZs6I1EU6/ZFkeaJqDBsGQTLL+ubYVN9vpdb
# gcCsEji1ArUbIIsxMnd8nHRk+1q75GE70aIm9xQ0IaMbDj0/Nw4vNrh7jG3i4PRv
# rlTP2hfWA6Qc3OpBktBHRV2j9+GMFm61KU/QWdM92cLz7GcGGve5vB+cykxOxLLO
# wEuwC9WDsn12gGAZuikDDwkOPigWhwOOM9vfl9HUgHG2rzU+tfpZ8IZ8zy5jDl2H
# N5IT1zb2ZLIz88PiRkSMXrRmqANYMCkmkTprdGiSckipaopvsxJ8K8QaPLG0Y7FD
# yctgKEt38Lxi9gtm6REo+LsEgoK22D8MnBdhhSK863RZOYoc
# SIG # End signature block
