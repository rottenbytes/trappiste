#!/usr/bin/perl -w

# Trappiste : backup & version network devices with git & SNMP
# By Nico <nico@rottenbytes.info>
# Idea by pnl
# BSD Licensed

use strict;
use SNMP::Trapinfo;
use Git::Repository;
use File::Path;
use Net::SNMP;
use File::Copy;
use AppConfig qw(:expand :argcount);

sub git_store_config
{
    my $timestamp = time;
    my $host=$_[0];
    my $community=$_[1];
    my $workdir=$_[2]."/".$host;
    my $tftpserver=$_[3];
    my $filename = $workdir."/".$host.".txt";
    my $r;
	
    if (-d $workdir)
    {
        chdir($workdir);
        $r=Git::Repository->new(work_tree => $workdir);
    }
    else
    {
        mkpath($workdir);
        $r=Git::Repository->create(init => $workdir);
        open(F,">",$filename);
        print F "\n";
        close(F);
	chdir($workdir);
	$r->run(add => ".");
        $r->command(commit => "-m", "empty file automated import");
	$r->command(log => '--pretty=oneline', '--all');
    }
    
    my ($session, $error) = Net::SNMP->session(
         -hostname => $host,
         -community => $community,
         -nonblocking => 0,
         -debug => 1,
         -version => "snmpv1"
    );
    
    my $result = $session->set_request( -varbindlist => [ ".1.3.6.1.4.1.9.2.1.55.".$tftpserver, OCTET_STRING, $host.".txt" ] );
    move("/home/tftpboot/".$host.".txt", $workdir);
    
    $r->command(commit => "-am", "automated commit by ".$0);
}

my $trap = SNMP::Trapinfo->new(*STDIN);

my $config = AppConfig->new();
$config->define('backupdir=s');
$config->define('community=s');
$config->define('tftpserver=s');

$config->file("/opt/scripts/etc/trappiste.conf");

# backup lors d'un write
if (($trap->trapname eq 'CISCO-CONFIG-MAN-MIB::ciscoConfigManEvent') and ($trap->data->{"CISCO-CONFIG-MAN-MIB::ccmHistoryEventConfigDestination"} eq 'startup')) {
    git_store_config($trap->hostname,$config->community(),$config->backupdir(),$config->tftpserver());
}

