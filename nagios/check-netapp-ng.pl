#!/usr/bin/perl

#####################################
#####################################
### ______               _     =) ###
### | ___ \             | |       ###
### | |_/ / __ _  _ __  | |       ###
### |    / / _` || '_ \ | |       ###
### | |\ \| (_| || | | || |____   ###
### \_| \_|\__,_||_| |_|\_____/   ###
#####################################
#####################################
#####################################
## Original version written by
## ran.leibman@gmail.com
## Additionial checks code written
## by laurent.dufour@havas.com
##
## the following parameters has
## been tested against a 
## FAS2220
## FAS2240
## FAS3220
## FA2050, NetApp Release 7.3.1.1
## IBM System Storage N6240, Data ONTAP Release 8.1.4P4
##
## DISKSUMMARY|HA|CIFSSESSIONS|
## AUTOSUPPORTSTATUS|NFSOPS|
## CIFSOPS|SHELFINFO|...
##
#####################################
#####################################


use strict;
use POSIX;
use lib "/usr/lib/nagios/libexec";
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS);
use Net::SNMP;
use File::Basename;
use Getopt::Long;

Getopt::Long::Configure('bundling');

my $stat = 0;
my $msg;
my $perf;
my $script_name = "check-netapp-ng.pl";
my $script_version = 1.2;

my $counterFilePath="/tmp";
my $counterFile;

my %opt;
my $elapsedtime = 1;

my %ERRORS = (
        'OK'       => '0',
        'WARNING'  => '1',
        'CRITICAL' => '2',
        'UNKNOWN'  => '3',
    );

# default return value is UNKNOWN
my $state = "UNKNOWN";
my $answer = "";

# time this script was run
my $runtime = time();

my $key;
our %snmpIndexes;


# file related variables
my $fileRuntime;
my $fileHostUptime;
my $fileNfsOps;
my $fileCifsOps;
my $fileIscsiOps;
my $fileFcpOps;

my $snmpHostUptime;


### SNMP OIDs
### You can browse at http://www.oidview.com/mibs/789/NETAPP-MIB.html
###############
my $snmpSysUpTime = '.1.3.6.1.2.1.1.3.0';
my $snmpFailedFanCount = '.1.3.6.1.4.1.789.1.2.4.2.0';
my $snmpFailPowerSupplyCount = '.1.3.6.1.4.1.789.1.2.4.4.0';
my $snmpcpuBusyTimePerCent = '.1.3.6.1.4.1.789.1.2.1.3.0';
my $snmpenvOverTemperature = '.1.3.6.1.4.1.789.1.2.4.1.0';
my $snmpnvramBatteryStatus = '.1.3.6.1.4.1.789.1.2.5.1.0';
my $snmpFailedDiskCount = '.1.3.6.1.4.1.789.1.6.4.7.0';
my $snmpUpTime = '.1.3.6.1.2.1.1.3.0';
my $snmpCacheAge = '.1.3.6.1.4.1.789.1.2.2.23.0';
my $snmpGlobalStatus = '.1.3.6.1.4.1.789.1.2.2.4.0';
my $snmpGlobalStatus_text = '.1.3.6.1.4.1.789.1.2.2.25.0';
my $snmpNdmpSessions = '.1.3.6.1.4.1.789.1.10.2.0';
my $snmpCifsSessions = '.1.3.6.1.4.1.789.1.7.2.12.0';
my $snmpAutoSupportStatus = '.1.3.6.1.4.1.789.1.2.7.1.0';
my $snmpAutoSupportStatus_text = '.1.3.6.1.4.1.789.1.2.7.2.0';



my $snmp_netapp_disksummary = '.1.3.6.1.4.1.789.1.6.4';
my $snmp_netapp_disksummary_diskTotalCount = '.1.3.6.1.4.1.789.1.6.4.1.0';
my $snmp_netapp_disksummary_diskActiveCount = '.1.3.6.1.4.1.789.1.6.4.2.0';
my $snmp_netapp_disksummary_diskFailedCount = '.1.3.6.1.4.1.789.1.6.4.7.0';
my $snmp_netapp_disksummary_diskSpareCount = '.1.3.6.1.4.1.789.1.6.4.8.0';
my $snmp_netapp_disksummary_diskReconstructingCount = '.1.3.6.1.4.1.789.1.6.4.3.0';
my $snmp_netapp_disksummary_diskFailedMessage = '.1.3.6.1.4.1.789.1.6.4.10.0';

my $snmp_netapp_cf = '.1.3.6.1.4.1.789.1.2.3';
my $snmp_netapp_cfSettings = '.1.3.6.1.4.1.789.1.2.3.1.0';
my $snmp_netapp_cfState = '.1.3.6.1.4.1.789.1.2.3.2.0';
my $snmp_netapp_cfCannotTakeoverCause = '.1.3.6.1.4.1.789.1.2.3.3.0';
my $snmp_netapp_cfPartnerStatus = '.1.3.6.1.4.1.789.1.2.3.4.0';
my $snmp_netapp_cfPartnerName = '.1.3.6.1.4.1.789.1.2.3.6.0';
my $snmp_netapp_cfInterconnectStatus = '.1.3.6.1.4.1.789.1.2.3.8.0';

my $snmpfilesysvolTable = '.1.3.6.1.4.1.789.1.5.8';
my $snmpfilesysvolTablevolEntryOptions = "$snmpfilesysvolTable.1.7";
my $snmpfilesysvolTablevolEntryvolName = "$snmpfilesysvolTable.1.2";




my $snmp_netapp_volume_id_table_df = ".1.3.6.1.4.1.789.1.5.4.1";
my $snmp_netapp_volume_id_table_df_name = "$snmp_netapp_volume_id_table_df.2";
my $snmp_netapp_volume_id_table_df_total = "$snmp_netapp_volume_id_table_df.3";
my $snmp_netapp_volume_id_table_df_used = "$snmp_netapp_volume_id_table_df.4";
my $snmp_netapp_volume_id_table_df_free = "$snmp_netapp_volume_id_table_df.5";
my $snmp_netapp_volume_id_table_df_used_prec = "$snmp_netapp_volume_id_table_df.6";
# 64bit values for SNMP v2c
my $snmp_netapp_volume_id_table_df64_total = "$snmp_netapp_volume_id_table_df.29";
my $snmp_netapp_volume_id_table_df64_used = "$snmp_netapp_volume_id_table_df.30";
my $snmp_netapp_volume_id_table_df64_free = "$snmp_netapp_volume_id_table_df.31";

my $snmp_netapp_enclNumber = '.1.3.6.1.4.1.789.1.21.1.1';
my $snmpEnclTable = '.1.3.6.1.4.1.789.1.21.1.2.1';
my $snmpEnclTableIndex = "$snmpEnclTable.1";
my $snmpEnclTableState = "$snmpEnclTable.2";
my $snmpEnclTableShelfAddr = "$snmpEnclTable.3";
my $snmpEnclTableProductID = "$snmpEnclTable.5";
my $snmpEnclTableProductVendor = "$snmpEnclTable.6";
my $snmpEnclTableProductModel = "$snmpEnclTable.7";
my $snmpEnclTableProductRevision = "$snmpEnclTable.8";
my $snmpEnclTableProductSerial = "$snmpEnclTable.9";
my $snmpEnclTablePsFailed = "$snmpEnclTable.15";
my $snmpEnclTableFanFailed = "$snmpEnclTable.18";
my $snmpEnclTableTempOverFail = "$snmpEnclTable.21";
my $snmpEnclTableTempOverWarn = "$snmpEnclTable.22";
my $snmpEnclTableTempUnderFail = "$snmpEnclTable.23";
my $snmpEnclTableTempUnderWarn = "$snmpEnclTable.24";
my $snmpEnclTableCurrentTemp = "$snmpEnclTable.25";
my $snmpEnclTableElectronicFailed = "$snmpEnclTable.33";
my $snmpEnclTableVoltOverFail = "$snmpEnclTable.36";
my $snmpEnclTableVoltOverWarn = "$snmpEnclTable.37";
my $snmpEnclTableVoltUnderFail = "$snmpEnclTable.38";
my $snmpEnclTableVoltUnderWarn = "$snmpEnclTable.39";


my $snmp_netapp_miscHighNfsOps = '.1.3.6.1.4.1.789.1.2.2.5.0';
my $snmp_netapp_miscLowNfsOps = '.1.3.6.1.4.1.789.1.2.2.6.0';

my $snmp_netapp_miscHighCifsOps = '.1.3.6.1.4.1.789.1.2.2.7.0';
my $snmp_netapp_miscLowCifsOps = '.1.3.6.1.4.1.789.1.2.2.8.0';

my $snmp_netapp_blocks = '.1.3.6.1.4.1.789.1.17';
my $snmp_netapp_blocks_iscsi64Ops = "$snmp_netapp_blocks.24.0";
my $snmp_netapp_blocks_fcp64Ops = "$snmp_netapp_blocks.25.0";

# SNMP Status Codes
my %nvramBatteryStatus = (
	1 => 'ok',
	2 => 'partially discharged',
	3 => 'fully discharged',
	4 => 'not present',
	5 => 'near end of life',
	6 => 'at end of life',
	7 => 'unknown',
);
my %GlobalStatusIndex = (
	1 => 'other',
	2 => 'unknown',
	3 => 'ok',
	4 => 'nonCritical',
	5 => 'critical',
	6 => 'nonRecoverable',
);

my %AutoSupportStatusIndex = (
	1 => 'ok',
        2 => 'smtpFailure',
        3 => 'postFailure',
        4 => 'smtpPostFailure',
	5 => 'unknown',
);

my %cfSettingsIndex = (
	1 => 'notConfigured',
        2 => 'enabled',
        3 => 'disabled',
        4 => 'takeoverByPartnerDisabled',
        5 => 'thisNodeDead',
);


my %cfStateIndex = (
	1 => 'dead',
        2 => 'canTakeover',
        3 => 'cannotTakeover',
        4 => 'takeover',
);

my %cfCannotTakeoverCauseIndex = (
	1 => 'ok',
        2 => 'unknownReason',
        3 => 'disabledByOperator',
        4 => 'interconnectOffline',
        5 => 'disabledByPartner',
        6 => 'takeoverFailed',
        7 => 'mailboxDegraded',
        8 => 'partnerMailboxUninitialised',
        9 => 'mailboxVersionMismatch',
        10 => 'nvramSizeMismatch',
        11 => 'kernelVersionMismatch',
        12 => 'partnerBootingUp',
        13 => 'partnerPerformingRevert',
        14 => 'performingRevert',
        15 => 'partnerRequestedTakeover',
        16 => 'alreadyInTakenoverMode',
        17 => 'nvramLogUnsynchronized',
        18 => 'backupMailboxProblems',
);

my %cfPartnerStatusIndex = (
	1 => 'maybeDown',
        2 => 'ok',
        3 => 'dead',
);

my %cfInterconnectStatusIndex = (
	1 => 'notPresent',
        2 => 'down',
        3 => 'partialFailure',
        4 => 'up',
);

my %EcnlStatusIndex = (
	1 => 'initializing',
	2 => 'transitioning',
	3 => 'active',
	4 => 'inactive',
	5 => 'reconfiguring',
	6 => 'nonexistent',
);
### Functions
###############


sub _create_session(@) {
	my ($server, $comm, $version, $timeout) = @_;
	my ($sess, $err) = Net::SNMP->session( -hostname => $server, -version => $version, -community => $comm, -timeout => $timeout);
	if (!defined($sess)) {
		print "Can't create SNMP session to $server\n";
		exit(1);
	}
	return $sess;
}

sub FSyntaxError($) {
	my $err = shift;
	print <<EOU;
This is $script_name in version $script_version.

$err

   Syntax:
       -H <IP or Hostname>    Ip/Dns Name of the Filer
       -C <community name>    SNMP Community Name for read
       -V <1|2c>              SNMP version (default 1)
       -T <check type>        Type of check, see bellow
       -t <seconds>           Timeout to SNMP session in seconds (default 5)

       -w <number>            Warning Value (default 500)
       -c <number>            Critical Value (default 500)
       -v <volume_path>       Volume Name in format /vol/volname/
       -e <vol1[,vol2[,...]]> Exclude volumes from snap check (SNAPSHOT)
       -I                     Inform only, return OK every time (ignore -w and -c values)

   Available check types:
       TEMP                   - Temperature
       FAN                    - Fan Fail
       PS                     - Power Supply Fail
       CPULOAD                - CPU Load (-w -c)
       NVRAM                  - NVram Battery Status
       DISKUSED               - Vol Usage Percentage (-w -c -v), for big volumes (>4GB) use -V 2c
       SNAPSHOT               - Snapshot Config (-e volname,volname2,volname3)
       SHELF                  - Shelf Health
       SHELFINFO              - Shelf Model & Temperature Information
       NFSOPS                 - Nfs Ops per seconds (-w -c)
       CIFSOPS                - Cifs Ops per seconds (-w -c)
       ISCSIOPS               - iSCSI Ops per seconds, using -V 2c automatic (-w -c)
       FCPOPS                 - FibreChannel Ops per seconds, using -V 2c automatic (-w -c)
       NDMPSESSIONS           - Number of ndmp sessions (-w -c)
       CIFSSESSIONS           - Number of cifs sessions (-w -c)
       GLOBALSTATUS           - Global Status of the filer
       AUTOSUPPORTSTATUS      - Auto Support Status of the filer
       HA                     - High Availability
       DISKSUMMARY            - Status of disks
       FAILEDDISK             - Number of failed disks
       UPTIME                 - Only show\'s uptime
       CACHEAGE               - Cache Age (-w -c)

   Examples:
      $script_name -H netapp.mydomain -C public -T UPTIME
        UPTIME: 2 days, 23:03:21.09 | uptime=255801s

      $script_name -H netapp.mydomain -C public -T FCOPS -I
        CRIT: FCPOPS 1130  | fcpops=1130

      $script_name -H netapp.mydomain -C public -T DISKUSED -v /vol/data/ -w 90 -c 95 -V 2c
        OK: DISKUSED 79% | /vol/data/=8104595240k

      $script_name -H netapp.mydomain -C public -T GLOBALSTATUS
        CRIT: GLOBALSTATUS nonCritical 4 Disk on adapter 1a, shelf 1, bay 9, failed.   | globalstatus=4

EOU
	exit($ERRORS{'UNKNOWN'});
}

sub _get_oid_value(@) {
	my $sess = shift;
	my $local_oid = shift;
	my $r_return = $sess->get_request(-varbindlist => [$local_oid]);
	return($r_return->{$local_oid});
}

sub _clac_generic_err_stat(@) {
	my $value = shift;
	my $value_type = shift;
	my $tmp_warn = shift;
	my $tmp_crit = shift;
	my $scale = shift;
	my $r_msg;
	my $r_stat;
	if($opt{'inform'} or ($value <= $tmp_warn)) {
		$r_stat = $ERRORS{'OK'};
		$r_msg = "OK: $value_type $value $scale";
	}  elsif($value > $tmp_warn and $value < $tmp_crit) {
		$r_stat = $ERRORS{'WARNING'};
		$r_msg = "WARN: $value_type $value $scale";
	} elsif($value >= $tmp_crit) {
		$r_stat = $ERRORS{'CRITICAL'};
		$r_msg = "CRIT: $value_type $value $scale";
	}
	return($r_msg,$r_stat);
}


sub _clac_err_stat(@) {
	my $value = shift;
	my $value_type = shift;
	my $tmp_warn = shift;
	my $tmp_crit = shift;
	my $r_msg;
	my $r_stat;
	if($value <= $tmp_warn) {
		$r_stat = $ERRORS{'OK'};
		$r_msg = "OK: $value_type $value%";
	}  elsif($value > $tmp_warn and $value < $tmp_crit) {
		$r_stat = $ERRORS{'WARNING'};
		$r_msg = "WARN: $value_type $value%";
	} elsif($value >= $tmp_crit) {
		$r_stat = $ERRORS{'CRITICAL'};
		$r_msg = "CRIT: $value_type $value%";
	}
	return($r_msg,$r_stat);
}


sub _clac_absolute_err_stat(@) {
	my $value = shift;
	my $value_type = shift;
	my $tmp_warn = shift;
	my $tmp_crit = shift;
	my $r_msg;
	my $r_stat;
	($r_msg,$r_stat) = _clac_generic_err_stat($value,$value_type,$tmp_warn,$tmp_crit,"");
	return($r_msg,$r_stat);
}

sub _clac_minutes_err_stat(@) {
	my $value = shift;
	my $value_type = shift;
	my $tmp_warn = shift;
	my $tmp_crit = shift;
	my $r_msg;
	my $r_stat;
	($r_msg,$r_stat) = _clac_generic_err_stat($value,$value_type,$tmp_warn,$tmp_crit,"minutes");
	return($r_msg,$r_stat);
}



### Gather input from user
#############################
$opt{'crit'} = 500;
$opt{'warn'} = 500;
$opt{'version'} = 1;
$opt{'timeout'} = 5;
my $result = GetOptions(\%opt,
						'filer|H=s',
						'community|C=s',
                                                'version|V=s',
						'check_type|T=s',
						'warn|w=i',
						'crit|c=i',
						'vol|v=s',
						'exclude|e=s',
                                                'inform|I',
                                                'timeout|t=i',
						);

FSyntaxError("Missing -H")  unless defined $opt{'filer'};
FSyntaxError("Missing -C")  unless defined $opt{'community'};
FSyntaxError("Missing -T")  unless defined $opt{'check_type'};
if($opt{'vol'}) {
	if($opt{'vol'} !~ /^\/.*\/$/) {
		FSyntaxError("$opt{'vol'} format is /vol/volname/ !");
	}
}
if($opt{'crit'} and $opt{'warn'}) {
	if($opt{'warn'} > $opt{'crit'}) {
		FSyntaxError("Warning can't be larger then Critical: $opt{'warn'} > $opt{'crit'}");
	}
}

if( ($opt{'check_type'} eq 'ISCSIOPS') or ($opt{'check_type'} eq 'FCPOPS') ) {
        $opt{'version'} = '2c';
}

if (!defined($counterFilePath)) {
    $state = "UNKNOWN";
    $answer = "Filepath must be specified";
    print "$state: $answer\n";
    exit $ERRORS{$state};
} # end check for filepath





# Starting Alaram
alarm($TIMEOUT);

# Establish SNMP Session
our $snmp_session = _create_session($opt{'filer'},$opt{'community'},$opt{'version'},$opt{'timeout'});

# setup counterFile now that we have host IP and check type
$counterFile = $counterFilePath."/".$opt{'filer'}.".check-netapp-ng.$opt{'check_type'}.nagioscache";

$snmpHostUptime =  _get_oid_value($snmp_session,$snmpSysUpTime);


# READ AND UPDATE CACHE FOR SPECIFIC TESTS FROM FILE
if (("$opt{'check_type'}" eq "CIFSOPS") or ("$opt{'check_type'}" eq "NFSOPS") or ("$opt{'check_type'}" eq "ISCSIOPS") or ("$opt{'check_type'}" eq "FCPOPS")) {

        # READ CACHE DATA FROM FILE IF IT EXISTS
        if (-e $counterFile) {
                open(FILE, "$counterFile");
                chomp($fileRuntime = <FILE>);
                chomp($fileHostUptime = <FILE>);
                chomp($fileNfsOps = <FILE>);
                chomp($fileCifsOps = <FILE>);
                chomp($fileIscsiOps = <FILE>);
                chomp($fileFcpOps = <FILE>);
                close(FILE);
        } # end if file exists

        # POPULATE CACHE DATA TO FILE
        if ((-w $counterFile) || (-w dirname($counterFile))) {
                open(FILE, ">$counterFile");
                print FILE "$runtime\n";
                print FILE "$snmpHostUptime\n";

                my $low_nfs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscLowNfsOps);
                my $high_nfs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscHighNfsOps);

                my $temp_high_ops = $high_nfs_ops << 32;
                my $total_nfs_ops = $temp_high_ops | $low_nfs_ops;

                print FILE "$total_nfs_ops\n";

                my $low_cifs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscLowCifsOps);
                my $high_cifs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscHighCifsOps);

                my $temp_high_ops = $high_cifs_ops << 32;
                my $total_cifs_ops = $temp_high_ops | $low_cifs_ops;

                print FILE "$total_cifs_ops\n";

                my $blocks_iscsi_ops = _get_oid_value($snmp_session,$snmp_netapp_blocks_iscsi64Ops);

                print FILE "$blocks_iscsi_ops\n";

                my $blocks_fcp_ops = _get_oid_value($snmp_session,$snmp_netapp_blocks_fcp64Ops);
                print FILE "$blocks_fcp_ops\n";

                close(FILE);
            } else {
                $state = "WARNING";
                $answer = "file $counterFile is not writable\n";
                print ("$state: $answer\n");
                exit $ERRORS{$state};
        } # end if file is writable

        # check to see if we pulled data from the cache file or not
        if ( (!defined($fileRuntime)) ) {
            $state = "OK";
            $answer = "never cached - caching\n";
            print "$state: $answer\n";
            exit $ERRORS{$state};
        } # end if cache file didn't exist

        # check host's uptime to see if it goes backward
        if ($fileHostUptime > $snmpHostUptime) {
            $state = "WARNING";
            $answer = "uptime goes backward - recaching data\n";
            print "$state: $answer\n";
            exit $ERRORS{$state};
        } # end if host uptime goes backward

        $elapsedtime=$runtime-$fileRuntime;

        if ($elapsedtime<1){ $elapsedtime=1; }

} # end populate cache only for *OPS tests

#print "fileHostUptime : ".$fileHostUptime."\n";
#print "snmpeHostUptime : ".$snmpHostUptime."\n";
#print "elapsedTime : ".$elapsedtime."\n";



### Temperature ###
if("$opt{'check_type'}" eq "TEMP") {
	my $check = _get_oid_value($snmp_session,$snmpenvOverTemperature);
	if($check == 1) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} is ok";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: Over $opt{'check_type'} !";
	}
	$perf = "overtemperature=$check";
### Fan ###
} elsif("$opt{'check_type'}" eq "FAN") {
	my $check = _get_oid_value($snmp_session,$snmpFailedFanCount);
	if($check == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $check";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $check !";
	}
	$perf = "failedfans=$check";
### PS ###
} elsif("$opt{'check_type'}" eq "PS") {
	my $check = _get_oid_value($snmp_session,$snmpFailPowerSupplyCount);
	if($check == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} Fail $check";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} Fail $check !";
	}
	$perf = "failedpowersupplies=$check";
### CPULOAD ###
} elsif("$opt{'check_type'}" eq "CPULOAD") {
	my $check = _get_oid_value($snmp_session,$snmpcpuBusyTimePerCent);
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "cpuload=$check\%";
### NFSOPS ###
} elsif("$opt{'check_type'}" eq "NFSOPS") {
	my $low_nfs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscLowNfsOps);
	my $high_nfs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscHighNfsOps);
	
	my $temp_high_ops = $high_nfs_ops << 32;
	my $total_nfs_ops = $temp_high_ops | $low_nfs_ops;

	my $nfsops_per_seconds=floor ( ($total_nfs_ops-$fileNfsOps)/$elapsedtime );

	my $check=$nfsops_per_seconds;

	($msg,$stat) = _clac_absolute_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "nfsops=$check";
### CIFSOPS ###
} elsif("$opt{'check_type'}" eq "CIFSOPS") {
	my $low_cifs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscLowCifsOps);
	my $high_cifs_ops = _get_oid_value($snmp_session,$snmp_netapp_miscHighCifsOps);
	
	my $temp_high_ops = $high_cifs_ops << 32;
	my $total_cifs_ops = $temp_high_ops | $low_cifs_ops;

	my $cifsops_per_seconds=floor ( ($total_cifs_ops-$fileCifsOps)/$elapsedtime );

	my $check=$cifsops_per_seconds;

	($msg,$stat) = _clac_absolute_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "cifsops=$check";
### ISCSIOPS ###
} elsif("$opt{'check_type'}" eq "ISCSIOPS") {
	my $total_iscsi_ops = _get_oid_value($snmp_session,$snmp_netapp_blocks_iscsi64Ops);

	my $iscsiops_per_seconds=floor ( ($total_iscsi_ops-$fileIscsiOps)/$elapsedtime );

	my $check=$iscsiops_per_seconds;

	($msg,$stat) = _clac_absolute_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "iscsiops=$check";
### FCPOPS ###
} elsif("$opt{'check_type'}" eq "FCPOPS") {
	my $total_fcp_ops = _get_oid_value($snmp_session,$snmp_netapp_blocks_fcp64Ops);

	my $fcpops_per_seconds=floor ( ($total_fcp_ops-$fileFcpOps)/$elapsedtime );

	my $check=$fcpops_per_seconds;

	($msg,$stat) = _clac_absolute_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "fcpops=$check";
### NVRAM ###
} elsif("$opt{'check_type'}" eq "NVRAM") {
	my $check = _get_oid_value($snmp_session,$snmpnvramBatteryStatus);
	if($check == 1) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $nvramBatteryStatus{$check}";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $nvramBatteryStatus{$check}";
	}
	$perf = "nvrambatterystatus=$check";
### DISKUSED ###
} elsif("$opt{'check_type'}" eq "DISKUSED") {

	FSyntaxError("Missing -v")  unless defined $opt{'vol'};

	my $r_vol_tbl = $snmp_session->get_table($snmp_netapp_volume_id_table_df_name);
	foreach my $key ( keys %$r_vol_tbl) {
		if("$$r_vol_tbl{$key}" eq "$opt{'vol'}") {
			my @tmp_arr = split(/\./, $key);
			my $oid = pop(@tmp_arr);
                        my $used = "";
			if ($opt{'version'} eq '2c') {
                                $used = _get_oid_value($snmp_session,"$snmp_netapp_volume_id_table_df64_used.$oid");
                        }
                        else {
                                $used = _get_oid_value($snmp_session,"$snmp_netapp_volume_id_table_df_used.$oid");
                        }
			my $used_prec = _get_oid_value($snmp_session,"$snmp_netapp_volume_id_table_df_used_prec.$oid");

			($msg,$stat) = _clac_err_stat($used_prec,$opt{'check_type'},$opt{'warn'},$opt{'crit'});

			$perf = "$$r_vol_tbl{$key}=$used\k";
		}
	}
        if ($msg =~ /^$/) {
                $stat = $ERRORS{'WARNING'};
                $msg = "WARN: Missing volume $opt{'vol'} !";
        }                
### SNAPSHOT ###
} elsif("$opt{'check_type'}" eq "SNAPSHOT") {
	my @exc_list = split(',',$opt{'exclude'});
	my @vol_err;
	my $r_vol_tbl = $snmp_session->get_table($snmpfilesysvolTablevolEntryvolName);
	foreach my $key ( keys %$r_vol_tbl) {
		my @tmp_arr = split(/\./, $key);
		my $oid = pop(@tmp_arr);
		my $vol_tmp = "$$r_vol_tbl{$key}";

		my $volopt = _get_oid_value($snmp_session,"$snmpfilesysvolTablevolEntryOptions.$oid");

		if($volopt !~ /nosnap=off/) {
			my $volcheck = 0;
			foreach my $exvol (@exc_list) {
				if($exvol eq $vol_tmp) {
					$volcheck++;
					last;
				}
			}
			if($volcheck == 0) {
				push(@vol_err,"$vol_tmp");
			}
		}
	}

	my $err_count = $#vol_err + 1;
	if($err_count == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} all ok";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} @vol_err not configured";
	}
	$perf = "snapoff=$err_count";
### FAILEDDISK ###
} elsif("$opt{'check_type'}" eq "FAILEDDISK") {
	my $check = _get_oid_value($snmp_session,$snmpFailedDiskCount);
	if($check == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $check";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $check";
	}
	$perf = "faileddisks=$check";

### DISKSUMMARY ###
} elsif("$opt{'check_type'}" eq "DISKSUMMARY") {
	my $diskTotal = _get_oid_value($snmp_session,$snmp_netapp_disksummary_diskTotalCount);
	my $diskActive = _get_oid_value($snmp_session,$snmp_netapp_disksummary_diskActiveCount);
	my $diskFailed = _get_oid_value($snmp_session,$snmp_netapp_disksummary_diskFailedCount);
	my $diskReconstructing = _get_oid_value($snmp_session,$snmp_netapp_disksummary_diskReconstructingCount);
	my $diskSpare = _get_oid_value($snmp_session,$snmp_netapp_disksummary_diskSpareCount);
	my $diskMessage = _get_oid_value($snmp_session,$snmp_netapp_disksummary_diskFailedMessage);

	my $check=$diskFailed;

	if($check == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} (".$diskMessage.") Disk Summary : Total->".$diskTotal." Active->".$diskActive." Spare->".$diskSpare." Failed ->".$diskFailed. " Reconstructing ->".$diskReconstructing;
	} elsif ($diskSpare>0) {
		$stat = $ERRORS{'WARNING'};
		$msg = "WARN: $opt{'check_type'} (".$diskMessage.") Disk Summary : Total->".$diskTotal." Active->".$diskActive." Spare->".$diskSpare." Failed ->".$diskFailed. " Reconstructing ->".$diskReconstructing;
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} (".$diskMessage.") Disk Summary : Total->".$diskTotal." Active->".$diskActive." Spare->".$diskSpare." Failed ->".$diskFailed. " Reconstructing ->".$diskReconstructing;
	}
	$perf = "faileddisks=$check total=$diskTotal active=$diskActive spare=$diskSpare reconstructing=$diskReconstructing";

### HA ###
} elsif("$opt{'check_type'}" eq "HA") {

	my $cfSettings = _get_oid_value($snmp_session,$snmp_netapp_cfSettings);
	my $cfState = _get_oid_value($snmp_session,$snmp_netapp_cfState);
	my $cfCannotTakeoverCause = _get_oid_value($snmp_session,$snmp_netapp_cfCannotTakeoverCause);
	my $cfPartnerStatus = _get_oid_value($snmp_session,$snmp_netapp_cfPartnerStatus);
	my $cfPartnerName = _get_oid_value($snmp_session,$snmp_netapp_cfPartnerName);
	my $cfInterconnectStatus = _get_oid_value($snmp_session,$snmp_netapp_cfInterconnectStatus);

	my $check=$cfSettings;

	if($cfSettings == 2) {


	    if ( ($cfPartnerStatus != 2) or ($cfState != 2) or ($cfInterconnectStatus != 4) ) {
		    $stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} HA Summary : Settings->".$cfSettingsIndex{$cfSettings}." State->".$cfStateIndex{$cfState}." Cannot Takeover Cause->".$cfCannotTakeoverCauseIndex{$cfCannotTakeoverCause}." Partner->".$cfPartnerName." Partner Status ->".$cfPartnerStatusIndex{$cfPartnerStatus}." Interconnection State->".$cfInterconnectStatusIndex{$cfInterconnectStatus};		
	    } else {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} HA Summary : Settings->".$cfSettingsIndex{$cfSettings}." State->".$cfStateIndex{$cfState}." Partner->".$cfPartnerName." Partner Status ->".$cfPartnerStatusIndex{$cfPartnerStatus}." Interconnection State->".$cfInterconnectStatusIndex{$cfInterconnectStatus};
	    }

	} elsif ( ($cfSettings == 3) or ($cfSettings == 1) ) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} HA Summary : Settings ->".$cfSettingsIndex{$cfSettings};
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} HA Summary : Settings->".$cfSettingsIndex{$cfSettings}." State->".$cfStateIndex{$cfState}." Partner->".$cfPartnerName." Partner Status ->".$cfPartnerStatusIndex{$cfPartnerStatus}." Interconnection State->".$cfInterconnectStatusIndex{$cfInterconnectStatus};
	}
	$perf = "hasettings=$check";


### UPTIME ###
} elsif("$opt{'check_type'}" eq "UPTIME") {
	my $check = _get_oid_value($snmp_session,$snmpUpTime);
	$msg = "$opt{'check_type'}: $check";
	$check =~ m/^\s*(\d+)\s+days,\s+(\d+):(\d+):(\d+).*$/;
	$perf = "uptime=" . ($1*86400 + $2*3600 + $3*60 + $4) . "s";
### CACHEAGE ###
} elsif("$opt{'check_type'}" eq "CACHEAGE") {
	my $check = _get_oid_value($snmp_session,$snmpCacheAge);
	($msg,$stat) = _clac_minutes_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "cache_age=$check";
### GLOBALSTATUS ###
} elsif("$opt{'check_type'}" eq "GLOBALSTATUS") {
	my $check = _get_oid_value($snmp_session,$snmpGlobalStatus);
	my $global_stat_txt = _get_oid_value($snmp_session,$snmpGlobalStatus_text);
	if($check == 3) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $GlobalStatusIndex{$check} $check $global_stat_txt";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $GlobalStatusIndex{$check} $check $global_stat_txt";
	}
	$perf = "globalstatus=$check";
### AUTOSUPPORTSTATUS ###
} elsif("$opt{'check_type'}" eq "AUTOSUPPORTSTATUS") {
	my $check = _get_oid_value($snmp_session,$snmpAutoSupportStatus);
	my $autosupport_stat_txt = _get_oid_value($snmp_session,$snmpAutoSupportStatus_text);
	if($check == 1) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $AutoSupportStatusIndex{$check} $check $autosupport_stat_txt";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $AutoSupportStatusIndex{$check} $check $autosupport_stat_txt";
	}
	$perf = "autosupportstatus=$check";
### NDMPSESSIONS ###
} elsif("$opt{'check_type'}" eq "NDMPSESSIONS") {
	my $check = _get_oid_value($snmp_session,$snmpNdmpSessions);
	($msg,$stat) = _clac_absolute_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "ndmpsess=$check";
### CIFSSESSIONS ###
} elsif("$opt{'check_type'}" eq "CIFSSESSIONS") {
	my $check = _get_oid_value($snmp_session,$snmpCifsSessions);
	($msg,$stat) = _clac_absolute_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "cifssess=$check";
### SHELF ###
} elsif ( ("$opt{'check_type'}" eq "SHELF") or ("$opt{'check_type'}" eq "SHELFINFO") ) {
	my @errs;
	my $r_shelf = $snmp_session->get_table($snmpEnclTableIndex);
	my $perf_temp = "";
	foreach my $key ( sort keys %$r_shelf) {
		my @tmp_arr = split(/\./, $key);
		my $oid = pop(@tmp_arr);

		my %shelf;
		my @shelf_err;
		my $addr = _get_oid_value($snmp_session,"$snmpEnclTableShelfAddr.$oid");

		my $shelf_state = _get_oid_value($snmp_session,"$snmpEnclTableState.$oid");

		if($shelf_state != 3) {
			push(@shelf_err,"$addr state $EcnlStatusIndex{$shelf_state},");
		}

		if ("$opt{'check_type'}" eq "SHELFINFO") {

		my $shelf_temp =  _get_oid_value($snmp_session,"$snmpEnclTableCurrentTemp.$oid");    

 
                my @current_temp = split(/\,/, $shelf_temp );

		$shelf{'ShelfNumber'} = $oid;
                $shelf{'CurrentTemp'} = shift(@current_temp);
		$shelf{'ProductID'} = _get_oid_value($snmp_session,"$snmpEnclTableProductID.$oid");
		$shelf{'ProductVendor'} = _get_oid_value($snmp_session,"$snmpEnclTableProductVendor.$oid");
		$shelf{'ProductModel'} = _get_oid_value($snmp_session,"$snmpEnclTableProductModel.$oid");
		$shelf{'ProductRevision'} = _get_oid_value($snmp_session,"$snmpEnclTableProductRevision.$oid");
		$shelf{'ProductSerial'} = _get_oid_value($snmp_session,"$snmpEnclTableProductSerial.$oid");
		} else {
		$shelf{'PsFail'} = _get_oid_value($snmp_session,"$snmpEnclTablePsFailed.$oid");
		$shelf{'FanFail'} = _get_oid_value($snmp_session,"$snmpEnclTableFanFailed.$oid");
		$shelf{'ElectFail'} = _get_oid_value($snmp_session,"$snmpEnclTableElectronicFailed.$oid");
		$shelf{'TempOverFail'} = _get_oid_value($snmp_session,"$snmpEnclTableTempOverFail.$oid");
		$shelf{'TempOver'} = _get_oid_value($snmp_session,"$snmpEnclTableTempOverWarn.$oid");
		$shelf{'TempUnderFail'} = _get_oid_value($snmp_session,"$snmpEnclTableTempUnderFail.$oid");
		$shelf{'TempUnderWarn'} = _get_oid_value($snmp_session,"$snmpEnclTableTempUnderWarn.$oid");
		$shelf{'VoltOverFail'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltOverFail.$oid");
		$shelf{'VoltOverWarn'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltOverWarn.$oid");
		$shelf{'VoltUnderFail'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltUnderFail.$oid");
		$shelf{'VoltUnderWarn'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltUnderWarn.$oid");
		}


		foreach my $subkey ( keys %shelf) {
		    if ( $shelf{$subkey} ne "" ) {
		    	print "$subkey->$shelf{$subkey} ";
                        if ( "$subkey" eq "CurrentTemp" ) {
                                $shelf{$subkey} =~ m/^([0-9]+)C.*$/;
                                $perf_temp = "$perf_temp, temp_$shelf{'ShelfNumber'}=$1";
                        }
		    }
		    else
		     { print "$subkey->"; print "None "; }
			
			if ("$opt{'check_type'}" eq "SHELF") {
			if($shelf{$subkey}) { push(@shelf_err,"$addr $subkey,") }
			}
		}

		{ print "\n"; }
		##if ("$opt{'check_type'}" eq "SHELFINFO") { print "\n"; }

		if($#shelf_err != -1) {
			push(@errs,@shelf_err)
		}
	}

	if($#errs == -1) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} ok";
		if ("$opt{'check_type'}" eq "SHELFINFO") 
		{ $perf = "shelfinfo=0$perf_temp"; }
		else
		{ $perf = "shelf=0"; }
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} Errors -";
		foreach(@errs) {
			$msg = "$msg $_";
		}
		if ("$opt{'check_type'}" eq "SHELFINFO") 
		{ $perf = "shelfinfo=1$perf_temp"; }
		else
		{ $perf = "shelf=1"; }
	}
### Syntax Error ###
} else {
	FSyntaxError("$opt{'check_type'} invalid parameter !");
}


print "$msg | $perf\n";
exit($stat);
