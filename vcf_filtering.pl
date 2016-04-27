#!/usr/bin/perl -w
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);

my $SNPSIFT_DIR=$ENV{'SNPSIFT_DIR'};
my ($qual,$AtoC,$AtoG,$AtoT,$CtoA,$CtoG,$CtoT,$GtoA,$GtoC,$GtoT,$TtoA,$TtoC,$TtoG,$min_cover,$min_reads_strand,$min_reads_alternate,$isvar); #Only some options to start with
$isvar="";
my $input_file="";
my $output_file="";
my $help;
my $usage="Usage: $0 -i input_file -o output_file [options]\n\n\nOptions:\n--------\n\t-q/--qual : quality filter\n\t--atoc : filter out mutations from A to C\n\t--atog :  filter out mutations from A to G\n\t--atot : filter out mutations from A to T\n\t--ctoa :  filter out mutations from C to A\n\t--ctog : filter out mutations from C to G\n\t--ctot :  filter out mutations from C to T\n\t--gtoa : filter out mutations from G to A\n\t--gtoc :  filter out mutations from G to C\n\t--gtot : filter out mutations from G to T\n\t--ttoa :  filter out mutations from T to A\n\t--ttoc : filter out mutations from T to C\n\t--ttog : filter out mutations from T to G\n\t-m/--min_coverage :minimum coverage per locus\n\t-s/--min_reads_strand : minimum number of reads per strand\n\t-a/--min_reads_alternate : minimum number of reads for the alternative allele\n\t--isvar : filter out variants with genotype ref/ref in the given sample (starting in 1)\n\t\n\n";
my $exe;

########### SNPSIFT Util detection #########################
if (defined $SNPSIFT_DIR)
{
	if (-f $SNPSIFT_DIR."SnpSift.jar")
	{
		$exe=$SNPSIFT_DIR."SnpSift.jar";
	}
	elsif (-f "$SNPSIFT_DIR/SnpSift.jar")
	{
		$exe="$SNPSIFT_DIR/SnpSift.jar";
	}
}
elsif (-f "SnpSift.jar")
{
	$exe="SnpSift.jar";
}
else
{
	die "ERROR: SnpSift.jar not found. Please, specify its location using the environmental variable SNPSIFT_DIR\n";
}
############################################################

##################     ARGV parsing   ######################

((! GetOptions(
	'input|i=s' => \$input_file,
	'output|o=s' => \$output_file,
	'qual|q=i' => \$qual,
	'atoc=i' => \$AtoC,
	'atog=i' => \$AtoG,
	'atot=i' => \$AtoT,
	'ctoa=i' => \$CtoA,
	'ctog=i' => \$CtoG,
	'ctot=i' => \$CtoT,
	'gtoa=i' => \$GtoA,
	'gtoc=i' => \$GtoC,
	'gtot=i' => \$GtoT,
	'ttoa=i' => \$TtoA,
	'ttoc=i' => \$TtoC,
	'ttog=i' => \$TtoG,
	'min_coverage|m=i' => \$min_cover, 
	'min_reads_strand|s=i' => \$min_reads_strand,
	'min_reads_alternate|a=i' => \$min_reads_alternate,
    'isvar=s' => \$isvar,
	'help|h' => \$help,
		)) or ((! -f $input_file) || ($output_file eq "") || $help)) and die $usage;

my ($qual_filter,$ctot_filter,$gtoa_filter,$min_cover_filter);

################### VCF scan ##############################

open(my $INPUTFILE,$input_file);
my $backup=$/;
$/="";
my $content=<$INPUTFILE>;
$/=$backup;
close($INPUTFILE);

my $platypus=0;
my $multisnv=0;

if ($content=~/platypus/i)
{
	$platypus=1;	
}
elsif ($content=~/multisnv/i)
{
	$multisnv=1;
}
else
{
	die "The input VCF file has not been recognized as generated by either platypus or multisnv. This script has been intended only for filtering VCFs generated by those pieces of software.\n";
}

###########################################################

################## Filter generation #####################

my $out_filter="";
my $variable="";

##Default filters
if ($platypus)
{
	$out_filter=" ( ( FILTER = \'PASS\' ) | ( FILTER = \'alleleBias\' ) ) &";
}
elsif ($multisnv)
{
	$out_filter=" ( FILTER = \'PASS\') &";	
}
else
{
	die "This variant caller is not supported by this script\n";
}

if ($qual)
{
	$out_filter.=" ( QUAL >= $qual ) &";
}
if ($AtoC)
{
	$out_filter.=" ( REF!=\'A\' | ( REF=\'A\' & ALT!=\'C\' ) ) &";
}
if ($AtoG)
{
	$out_filter.=" ( REF!=\'A\' | ( REF=\'A\' & ALT!=\'G\' ) ) &";
}
if ($AtoT)
{
	$out_filter.=" ( REF!=\'A\' | ( REF=\'A\' & ALT!=\'T\' ) ) &";
}
if ($CtoA)
{
	$out_filter.=" ( REF!=\'C\' | ( REF=\'C\' & ALT!=\'A\' ) ) &";
}
if ($CtoG)
{
	$out_filter.=" ( REF!=\'C\' | ( REF=\'C\' & ALT!=\'G\' ) ) &";
}
if ($CtoT)
{
	$out_filter.=" ( REF!=\'C\' | ( REF=\'C\' & ALT!=\'T\' ) ) &";
}
if ($GtoA)
{
	$out_filter.=" ( REF!=\'G\' | ( REF=\'G\' & ALT!=\'A\' ) ) &";
}
if ($GtoC)
{
	$out_filter.=" ( REF!=\'G\' | ( REF=\'G\' & ALT!=\'C\' ) ) &";
}
if ($GtoT)
{
	$out_filter.=" ( REF!=\'G\' | ( REF=\'G\' & ALT!=\'T\' ) ) &";
}
if ($TtoA)
{
	$out_filter.=" ( REF!=\'T\' | ( REF=\'T\' & ALT!=\'A\' ) ) &";
}
if ($TtoC)
{
	$out_filter.=" ( REF!=\'T\' | ( REF=\'T\' & ALT!=\'C\' ) ) &";
}
if ($TtoG)
{
	$out_filter.=" ( REF!=\'T\' | ( REF=\'T\' & ALT!=\'G\' ) ) &";
}
if ($min_cover)
{
	if ($platypus)
	{
		$variable="TC";
	}
	elsif ($multisnv)
	{
		$variable="GEN[ALL].DP"
	}
	else 
	{
		die "This variant caller is not supported by this script\n";
	}

	$out_filter.=" ( $variable >= $min_cover ) &";
}
if ($min_reads_strand)
{	
	if ($platypus)
	{
		$out_filter.=" ( ( NR >= $min_reads_strand ) & ( NF >= $min_reads_strand ) ) &";
	}
	elsif ($multisnv)
	{
		die "This option is not compatible with multisnv\n";
	}
	else 
	{
		die "This variant caller is not supported by this script\n";
	}
}
if ($min_reads_alternate)
{
	if ($platypus)
	{
		$out_filter.=" ( GEN[*].NV > $min_reads_alternate ) &";
	}
	elsif($multisnv)
	{
		die "This option is not compatible with multisnv\n";
	}
	else 
	{
		die "This variant caller is not supported by this script\n";
	}
}
if ($isvar ne "")
{
    $out_filter.= " ( isVariant( GEN[$isvar] ) ) &";
}

$out_filter eq "" and die "ERROR: No filtering options have been specified\n\n$usage"; 

chop($out_filter); ##Removing extra " &"
chop($out_filter);
#print("DEBUG: $out_filter\n");
#########################################################

################      SNPsift execution      ############

substr($out_filter,0,1)=""; ##Removing extra space in the begining
system("cat $input_file | java -jar $exe filter \"$out_filter\" > $output_file");
exit;

#########################################################
