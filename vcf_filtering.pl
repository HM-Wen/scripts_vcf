#!/usr/bin/perl -w
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);
use File::Copy;

my $SNPSIFT_DIR=$ENV{'SNPSIFT_DIR'};
my ($qual,$AtoC,$AtoG,$AtoT,$CtoA,$CtoG,$CtoT,$GtoA,$GtoC,$GtoT,$TtoA,$TtoC,$TtoG,$min_cover,$min_reads_strand,$min_reads_alternate,$max_reads_alternate,$min_freq_alt);
my $input_file="";
my $output_file="";
my $help;
my $usage="Usage: $0 -i input_file -o output_file [options]\n\n\nOptions:\n--------\n\t-q/--qual : min quality filter\n\t--atoc : filter out mutations from A to C\n\t--atog :  filter out mutations from A to G\n\t--atot : filter out mutations from A to T\n\t--ctoa :  filter out mutations from C to A\n\t--ctog : filter out mutations from C to G\n\t--ctot :  filter out mutations from C to T\n\t--gtoa : filter out mutations from G to A\n\t--gtoc :  filter out mutations from G to C\n\t--gtot : filter out mutations from G to T\n\t--ttoa :  filter out mutations from T to A\n\t--ttoc : filter out mutations from T to C\n\t--ttog : filter out mutations from T to G\n\t-m/--min_coverage :minimum coverage per locus\n\t-s/--min_reads_strand : minimum number of reads per strand\n\t-a/--min_reads_alternate : minimum number of reads for the alternative allele\n\t--max_reads_alternate : maximum number of reads for the alternative allele\n\t--min_freq_alt : min frequency of reads supporting the alternative allele\n\t\n\n";
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
	'min_reads_alternate|a=s' => \$min_reads_alternate,
	'max_reads_alternate=s' => \$max_reads_alternate,
	'min_freq_alt=s' => \$min_freq_alt,
    ##'isvar=s' => \$isvar,
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
		my @temp=split("_",$min_cover);
		if(scalar @temp ==1) #No genotype information. By default, total coverage.
		{
			$variable="TC";

		}
		elsif (scalar @temp ==2) #Genotype information. Applyied by genotype
		{
			$variable="GEN[$temp[0]].NR[*]";
			$min_cover=$temp[1];
		}
		else
		{
			die "--min_coverage does not have the proper format. It must by just the value, or a genotype indicator, _ , and the value. Example: 1_10\n";
		}
	}
	elsif ($multisnv)
	{
		$variable="GEN[ALL].DP[*]"
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
		my @temp=split("_",$min_reads_alternate);
		unless ($min_reads_alternate eq "-1")
		{
		
			if(scalar @temp == 1) #There is no genotype information. By default, if any fulfill the filtering, they are kept.
			{
				$out_filter.=" ( GEN[*].NV[*] >= $min_reads_alternate ) &";
			}
			elsif (scalar @temp == 2)
			{
				$out_filter.=" ( GEN[$temp[0]].NV[*] >= $temp[1] ) &";
			}
			else
			{
				die "--min_reads_alternate does not have the proper format. It must by just the value, or a genotype indicator, _ , and the value. Example: 1_10\n";
			}
		}
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
if ($max_reads_alternate)
{
	if ($platypus)
	{
		my @temp=split("_",$max_reads_alternate);
		unless ($max_reads_alternate eq "-1")
		{
			if(scalar @temp == 1) #There is no genotype information. By default, if any fulfill the filtering, they are kept.
			{
				$out_filter.=" ( GEN[*].NV[*] <= $max_reads_alternate ) &";
			}
			elsif (scalar @temp == 2)
			{
				$out_filter.=" ( GEN[$temp[0]].NV[*] <= $temp[1] ) &";
			}
			else
			{
				die "--max_reads_alternate does not have the proper format. It must by just the value, or a genotype indicator, _ , and the value. Example: 1_10\n";
			}
		}
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


$out_filter eq "" and die "ERROR: No filtering options have been specified\n\n$usage"; 

chop($out_filter); ##Removing extra " &"
chop($out_filter);
#print("DEBUG: $out_filter\n");
#########################################################

################      SNPsift execution      ############

substr($out_filter,0,1)=""; ##Removing extra space in the begining
#print("DEBUG: Executing SnipEff with the filter $out_filter\n");
system("cat $input_file | java -Xmx2G -jar $exe filter \"$out_filter\" > $output_file");

#########################################################

##All this looks like a really bad strategy.
#Alternative strategy (some thoughts)
#Design an array of keys from the columns + Genotypes and Format
#Generate a hash of variants, with value an array of values following the order of the keysarray
#This way, I could generate code from the restrictions, and then apply it to the hash+array thing. Using eval to execute strings.
#There will have to be a loop, since some filters generate multiple instructions (Gene[*] and Gene[ALL]).

if ($min_freq_alt) ##So far only this option requires my own filtering step. This strategy will have to be slightly changed if we implement more.
{
	if ($platypus)
	{
		
		my @temp=split("_",$min_freq_alt);
		unless($min_freq_alt==-1)
		{
            $min_freq_alt=$temp[1];
			my $comment;
			if(scalar @temp == 1) #There is no genotype information. By default, if any fulfill the filtering, they are kept.
			{
				die "The general option has not been yet implemented for the variable --min_freq_alt";
			}
			elsif (scalar @temp == 2)
			{
				$comment="##Filtered with vcf_filt. Filter GEN[$temp[0]].NV/GEN[$temp[0]].NR >= $temp[1]";
			}
			else
			{
				die "--min_reads_alternate does not have the proper format. It must by just the value, or a genotype indicator, _ , and the value. Example: 1_10\n";
			}
	
			#### DIY Filtering options
			#########################################################
			
			##Copy the $output_file to $output_file_snipeff
		
			move($output_file,"${output_file}_SnipEff");
			open(my $IFILE, "${output_file}_SnipEff");
			my @content=<$IFILE>;
			close $IFILE;
			open(my $OFILE, ">$output_file");
			my $flag=0;
			my @line;
			my @gen;
			my $format;
			my @genids;
			my $NV;
			my $NR;
			my @NVvalues;
			my @NRvalues;
	
			for (my $i=0; $i<scalar @content; ++$i)
			{
				if ($flag==0 and $content[$i]=~/^##/)
			        {
			            print($OFILE $content[$i]);
			        }
			        elsif($flag==0)
			        {
			            print($OFILE "$comment\n$content[$i]");
			            $flag=1;
			        }
			        else
			        {
					@line=split("\t",$content[$i]);
					@gen=split(":",$line[9+$temp[0]]);
					#print "DEBUG: @gen\n"; 
					$format=$line[8];
					@genids=split(":",$format);
					for (my $j=0; $j<scalar @genids; ++$j)
					{
						if($genids[$j] eq "NV")
						{
							$NV=$j;
						}
						elsif($genids[$j] eq "NR")
						{
							$NR=$j;
						}		
					}
					#print "DEBUG: NV=$NV value=$gen[$NV] NR=$NR value=$gen[$NR]\n";
					@NRvalues=split(",",$gen[$NR]);
					@NVvalues=split(",",$gen[$NV]);
					for (my $j=0; $j<scalar @NRvalues; ++$j)
					{
						if ($NRvalues[$j] != 0)
						{
							if ($NVvalues[$j]/($NRvalues[$j]+0.0) >= $temp[1])
							{
								print($OFILE $content[$i]);
								last;
							}
						}
						elsif ($temp[1] <= 0) ##If the filter is 0, we don't care if we can't calculate it.
						{
							print($OFILE $content[$i]);
							last;
						}
					}
			        }
			}
			close $OFILE;
		}
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
exit;
