#!/usr/bin/perl

use warnings;
use strict;

our $sep_char="\t";

if (scalar @ARGV != 2)
{
	die "Usage. script input.vcf output.vcf";
}
my ($infile,$outfile)=@ARGV;

open(my $INFILE,$infile);
my @content=<$INFILE>;
close($INFILE);
##VCF files have 9 prior columns prior the ones we want to modify here
my $prev_com_line="";
my $flag_coment=0;
my $nind=0;
my @columns;
my @splitcol;
my @probcols;
my @tempcols;
my $outline;
my $OUTFILE;
open($OUTFILE,">$outfile") or die "The file $outfile could not be created\n";
my $n_line=0;
my $n_bcount=-1;
for my $line (@content)
{
	chomp($line);
	if($nind==0)
	{
		if ($line=~/^#/)
		{
			if($prev_com_line ne "")
			{
				print $OUTFILE "$prev_com_line\n"; ##Delayed writing
			}
			$prev_com_line=$line;
			$flag_coment=1;
		}
		elsif($flag_coment==1)
		{
			$flag_coment=0;
			@columns=split("\t",$prev_com_line);
			$nind=(scalar @columns) - 9;
			my @info=split("\t",$content[$n_line+1]);
			my @ids=split(":",$info[8]);
			@probcols=splice(@columns,9,$nind);
			for (my $i=0; $i<$nind; ++$i)
			{
				for (my $j=0; $j<scalar @ids;++$j)
				{
					if ($ids[$j] eq "BCOUNT")  ##We want to separate the bcount also in different columns
					{
						$n_bcount=$j;
						push(@columns,"$ids[$j]_A_$probcols[$i]","$ids[$j]_C_$probcols[$i]","$ids[$j]_T_$probcols[$i]","$ids[$j]_G_$probcols[$i]");
					}
					else
					{
						push(@columns,"$ids[$j]_$probcols[$i]");
					}
				}
			}
			$outline=join($sep_char,@columns);
			print $OUTFILE "$outline\n";
			#print $nind;
			#print scalar @columns;
		}
	}
	if($nind!=0)
	{
		@splitcol=split("\t",$line);
		#print "$line\n";
		@probcols=splice(@splitcol,9,$nind);
		if($n_bcount == -1) ##Default
		{
			for (my $i=0; $i<$nind; ++$i)
			{
				push(@splitcol,split(":",$probcols[$i]));
			}

		}
		else ##We need to split also the column $n_bcount 
		{
			for (my $i=0; $i<$nind; ++$i)
                        {
				@tempcols=split(":",$probcols[$i]);
				splice(@tempcols,$n_bcount,1,split(",",$tempcols[$n_bcount]));
                                push(@splitcol,@tempcols);
                        }
		}
		$outline=join($sep_char,@splitcol);
		print $OUTFILE "$outline\n";
	}
	++$n_line;

}
close($OUTFILE);
#my $n_ind=(scalar @content)-9;
#print $n_ind;
#print @content;
exit;
