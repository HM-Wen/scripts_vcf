#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);
use Cwd;
use File::Basename;

##Configuration variables
######################################################

our $sep_param="#";
our $sep_value=":";
our $OFS=",";
our $FS=",";
our $variant_caller="platypus";
our $variant_calling_sh;
our $output_vcfs="0";

######################################################

##IO Variables
######################################################
my $execond_inputfile="";
my $filtercond_inputfile="";
my $output_dir="vcf_outputdir";
my $output_file="";
my $cluster=0;
my $normal_bam="";
my $sample1_bam="";
my $sample2_bam="";

#Flags
my $help;
my $usage="Usage: $0 [options] -o output_file --normal_bamfile bamfile_normal_sample --sample_A_bamfile bamfile_A_sample --sample_B_bamfile bamfile_B_sample\n\n\nOptions:\n--------\n\t-e/--exec_cond_inputfile : input file for execution parameters and options\n\t-f/--filt_cond_inputfile : input file for execution parameters and options\n\t--cluster :  the script will be run in a cluster with a qsub-based queuing system\n\t--output_dir : output directory for vcf files\n\t\n\n";
######################################################

######################################################
##MAIN
######################################################

##Getopt
######################################################
(! GetOptions(
        'exec_cond_inputfile|e=s' => \$execond_inputfile,
	    'filt_cond_inputfile|f=s' => \$filtercond_inputfile,
        'output_dir=s' => \$output_dir,
	    'output_file|o=s' => \$output_file,
	    'cluster' => \$cluster,
	    'normal_bamfile=s' => \$normal_bam,
	    'sample_A_bamfile=s' => \$sample1_bam,
	    'sample_B_bamfile=s' => \$sample2_bam,
        'help|h' => \$help,
                )) or (($output_file eq "") || ($normal_bam eq "")  || ($sample1_bam eq "") || ($sample2_bam eq "")  || $help) and die $usage;

##Input file parsing and directory creation
######################################################

my @exe_parameters=("input");
my @filtering_parameters=("");
my @exe_param_values=([("")]);
my @filtering_param_values=([("")]);

##Input files

if ($execond_inputfile ne "")
{
	@exe_parameters=();
	parse_parameters_values($execond_inputfile,\@exe_parameters,\@exe_param_values);
}

if ($filtercond_inputfile ne "")
{
	@filtering_parameters=();
	parse_parameters_values($filtercond_inputfile,\@filtering_parameters,\@filtering_param_values);
}

##BAMs
if ( ! -f $normal_bam)
{
	die "The BAM file $normal_bam is not accesible. Please, check your input options.\n";
}
else
{
	$normal_bam=Cwd::abs_path($normal_bam);
}

if ( ! -f $sample1_bam)
{
	die "The BAM file $sample1_bam is not accesible. Please, check your input options.\n";
}
else
{
	$sample1_bam=Cwd::abs_path($sample1_bam);
}

if ( ! -f $sample2_bam)
{
	die "The BAM file $sample2_bam is not accesible. Please, check your input options.\n";
}
else
{
	$sample2_bam=Cwd::abs_path($sample2_bam);
}

#my $i=0;
#foreach my $exepar (@exe_parameters)
#{
#	print("Parameter: $exepar\n");
#	for (my $j=0;$j<scalar(@{$exe_param_values[$i]});++$j)
#	{
#		print("\tValue $exe_param_values[$i][$j]\n");
#	} 
#	++$i;
#}

mkdir $output_dir;
my $original_dir=dirname(Cwd::abs_path($0));
chdir $output_dir or die "The output directory $output_dir is not accesible";
my $vcf_filt_exe="vcf_filtering.pl";

if(`which vcf_filtering.pl 2>/dev/null` eq "")
{
	if (-f "$original_dir/$vcf_filt_exe")
	{
		$vcf_filt_exe="$original_dir/$vcf_filt_exe";
	}
	else 
	{
		die "The executable vcf_filtering.pl is neither in your PATH nor in the directory $original_dir. This script needs to locate it to continue\n";
	}
}

if ($cluster and -f "$original_dir/$variant_caller.sh")
{
	$variant_calling_sh="$original_dir/$variant_caller.sh";
}
elsif ($cluster)
{
	die "Error, the sh file for the variant caller $variant_caller is not located in $original_dir, named $original_dir/$variant_caller.sh. Please, fix this in order to use this script\n"
}
else
{
	die "This version of the script can't work without a queue manager\n";
}



## Main conditions loop
#######################

my $name_condition;
my @filtering_conditions;
my @exe_conditions;
my %results;
my $condition;
my $filtering_command;
my $bamfiles;

##Generate all combinations of proposed values for execution and filtering parameters
combs(0,"",\@exe_parameters,\@exe_param_values,\@exe_conditions);
combs(0,"",\@filtering_parameters,\@filtering_param_values,\@filtering_conditions);

if ($cluster)
{
	my %job_ids;
    my $exe_condition;

	mkdir("e_logs");
	mkdir("o_logs");

	### Default calling parameters. This may be changed in the future
	#########################################################

	print("Unfiltered variant calling detection/execution:\n");	
	if(! -f "N.vcf")
	{
		$bamfiles=$normal_bam;
		$exe_condition="";
		my $job_id=`qsub -e e_logs/ -o o_logs/ -q shortq $variant_calling_sh -F "$bamfiles $exe_condition N.vcf N_platypus.log" | sed "s/.master.cm.cluster//"`;
        chomp($job_id);
        $job_ids{$job_id}=1;
		print("\tNormal tissue variant calling submited with job_id $job_id\n");
	}
	else
	{
		print("\tNormal tissue variant calling already present, skipping it\n");
	}

	if(! -f "A.vcf")
	{
		$bamfiles=$sample1_bam;
		$exe_condition="";
		my $job_id=`qsub -e e_logs/ -o o_logs/ -q shortq $variant_calling_sh -F "$bamfiles $exe_condition A.vcf A_platypus.log" | sed "s/.master.cm.cluster//"`;
        chomp($job_id);
        $job_ids{$job_id}=1;
		print("\tSample A variant calling submited with job_id $job_id\n");
	
	}
	else
	{
		print("\tSample A variant calling already present, skipping it\n");
	}

	if(! -f "B.vcf")
	{
		$bamfiles=$sample2_bam;
		$exe_condition="";
		my $job_id=`qsub -e e_logs/ -o o_logs/ -q shortq $variant_calling_sh -F "$bamfiles $exe_condition B.vcf B_platypus.log" | sed "s/.master.cm.cluster//"`;
        chomp($job_id);
        $job_ids{$job_id}=1;
		print("\tSample B variant calling submited with job_id $job_id\n");

	}
	else
	{
		print("\tSample B variant calling already present, skipping it\n");
	}
	
	if(! -f "NAB.vcf")
	{
		$bamfiles="$normal_bam,$sample1_bam,$sample2_bam";
		$exe_condition="";
		my $job_id=`qsub -e e_logs/ -o o_logs/ -q shortq $variant_calling_sh -F "$bamfiles $exe_condition NAB.vcf NAB_platypus.log" | sed "s/.master.cm.cluster//"`;
        chomp($job_id);
        $job_ids{$job_id}=1;
		print("\tSample NAB variant calling submited with job_id $job_id\n");

	}
	else
	{
		print("\tNAB variant calling already present, skipping it\n");
	}
	
	### Calling with filters (Only cancer samples so far)
	##############################################################
	my $job_id;
    my $actual_exe_conditions;
	print("Filtered variant calling detection/execution:\n");	
	foreach my $exe_condition (@exe_conditions)
	{
		if (! -f "A$sep_param$exe_condition.vcf")
		{
			$bamfiles=$sample1_bam;
            if ($exe_condition eq "Default${sep_value}1")
            {
                $actual_exe_conditions="";
                #print("DEBUG: A: Default exe conditions\n");
            }
            else
            {
                $actual_exe_conditions=$exe_condition;
                #print("DEBUG: A: Real exe_conditions\n");
            }
            #print("DEBUG: qsub -e e_logs/ -o o_logs/ -q shortq $variant_calling_sh -F \"$bamfiles $actual_exe_conditions A$sep_param$exe_condition.vcf A$sep_param${exe_conditions}_platypus.log\" | sed \"s/.master.cm.cluster//\"");
			$job_id=`qsub -e e_logs/ -o o_logs/ -q shortq $variant_calling_sh -F "$bamfiles $actual_exe_conditions A$sep_param$exe_condition.vcf A$sep_param${exe_condition}_platypus.log" | sed "s/.master.cm.cluster//"`;
			chomp($job_id);
            $job_ids{$job_id}=1;
			print("\tSample A variant calling for conditions $exe_condition submited with job_id $job_id\n");
	
		}
		else
		{
			print("\tSample A variant calling for conditions $exe_condition already present, skipping it\n");
		}

		if (! -f "B$sep_param$exe_condition.vcf")
		{
			$bamfiles=$sample2_bam;
            if ($exe_condition eq "Default${sep_value}1")
            {
                $actual_exe_conditions="";
                #print("DEBUG: B: Default exe conditions\n");
            }
            else
            {
                $actual_exe_conditions=$exe_condition;
                #print("DEBUG: B: Real exe_conditions\n");
            }
			$job_id=`qsub -e e_logs/ -o o_logs/ -q shortq $variant_calling_sh -F "$bamfiles $actual_exe_conditions B$sep_param$exe_condition.vcf B$sep_param${exe_condition}_platypus.log" | sed "s/.master.cm.cluster//"`;
	    	chomp($job_id);	
            $job_ids{$job_id}=1;
			print("\tSample B variant calling for conditions $exe_condition submited with job_id $job_id\n");

		}
		else
		{
			print("\tSample B variant calling for conditions $exe_condition already present, skipping it\n");

		}

	}

	while (scalar keys %job_ids != 0)##Check 
	{
        sleep(60); 
        print("\tPending jobs ",join(",",keys %job_ids),"\n");
		foreach my $id (keys %job_ids)
		{
			my $status=system "qstat $id >/dev/null 2>&1";
            #print("DEBUG: Status job id $id : $status\n");
            if($status!=0)
            {
                delete($job_ids{$id});
            }
		}
		
	}
}
else
{
    die "the current version of this code should never reach this point\n";
}

## Parsing static variants
############################################################################################
my %A=%{parse_vcf("A.vcf")};
my %B=%{parse_vcf("B.vcf")};
my %N=%{parse_vcf("N.vcf")};
my %NAB=%{parse_vcf("NAB.vcf")};


foreach my $exe_condition (@exe_conditions) ##Options that require to call variants again 
{
	#print("DEBUG: Exe condition loop $exe_condition\n");
	
	if ((!-f "A$sep_param$exe_condition.vcf") || (!-f "B$sep_param$exe_condition.vcf")) ##VCF file we will use for filtering, if it does not exist we have to perform the variant calling
	{	
		###PENDING!!!!			
		##Perform the variant calling
		######system("$variant_calling_sh -i ????? -o $exe_condition.vcf");
		die "So far this script does not support to carry out the variant calling in an environment without a queue manager\n";
	}


	foreach my $filtering_condition (@filtering_conditions) ##Filtering options
	{	
		$condition="$exe_condition$sep_param$filtering_condition";
		$filtering_command="$vcf_filt_exe ";
		$filtering_command.=join(" ",split("$sep_value",join(" ",split("$sep_param",$filtering_condition))));

		if (!-f "A$sep_param$condition.vcf")
		{
			print("Filtering A$sep_param$exe_condition.vcf to generate A$sep_param$condition.vcf\n");
			## Filter the right vcf file generated in the outside loop	
			system("$filtering_command -i A$sep_param$exe_condition.vcf -o A$sep_param$condition.vcf"); ## I don't think speed would be an issue, thus I'll call the filtering script every time (instead of writting a package and/or functions here)
			#print("DEBUG: $filtering_command -i A$sep_param$exe_condition.vcf -o A$sep_param$condition.vcf \n");

		}
		else
		{
			print("A$sep_param$condition.vcf has been previously generated and it will be recycled\n");
		}

		if (!-f "B$sep_param$condition.vcf")
		{
			print("Filtering B$sep_param$exe_condition.vcf to generate B$sep_param$condition.vcf\n");
			## Filter the right vcf file generated in the outside loop		
			system("$filtering_command -i B$sep_param$exe_condition.vcf -o B$sep_param$condition.vcf"); ## I don't think speed would be an issue, thus I'll call the filtering script every time (instead of writting a package and/or functions here)
			#print("DEBUG: $filtering_command -i B$sep_param$exe_condition.vcf -o B$sep_param$condition.vcf \n");
		}
		else
		{
			print("B$sep_param$condition.vcf has been previously generated and it will be recycled\n");
		}
	
		my %Afilt=%{parse_vcf("A$sep_param$condition.vcf")};
		my %Bfilt=%{parse_vcf("B$sep_param$condition.vcf")};
	
        # Right know I'm keeping a lot of hashes in memory instead of reusing variables. I do it just in case I need them in posterior statistics/calculations etc.
        # We could be interested on changing this if the performance is really bad.

		#Compare Afilt with B without filter --> Common variants + %
		my @statsAfilt;
		my ($ref_common_variantsAfilt,$ref_different_variantsAfilt)=vcf_compare_parsed(\%B,\%Afilt,\@statsAfilt); ##I have to generate two hashes. One with common variants, the other with non common. Thus, the consecutive filter I can do it towards these new (smallest) hashes.
		
		#Compare Bfiltered with A without filter --> Common variants + %
		my @statsBfilt;
		my ($ref_common_variantsBfilt,$ref_different_variantsBfilt)=vcf_compare_parsed(\%A,\%Bfilt,\@statsBfilt);

		#Stats filter
		my @statsfilt;
        my ($ref_common_variantsfilt,$ref_different_variantsfilt)=vcf_unite_parsed($ref_common_variantsAfilt,$ref_different_variantsAfilt,$ref_common_variantsBfilt,$ref_different_variantsBfilt,\@statsfilt);
        
        #my @statsfilt=(($statsAfilt[0]+$statsBfilt[0])/2.0,($statsAfilt[1]+$statsBfilt[1])/2.0); ###TODO: I'm calculating the of the % and the number of variants. We may want to get the union or intersection of variants!!!!

		
		#Substract N from Afilt. Compare the result to B without filter --> Common variants + %
		my @statsAfiltN;
		my ($ref_common_variantsAfiltN,$ref_different_variantsAfiltN)=vcf_prune($ref_common_variantsAfilt,$ref_different_variantsAfilt,\%N,\@statsAfiltN);
		
		#Substract N from Bfilt. Compare the result to A without filter --> Common variants + %
		my @statsBfiltN;
		my ($ref_common_variantsBfiltN,$ref_different_variantsBfiltN)=vcf_prune($ref_common_variantsBfilt,$ref_different_variantsBfilt,\%N,\@statsBfiltN);
				
		#Mean stats filterN
		my @statsfiltN;
        my ($ref_common_variantsfiltN,$ref_different_variantsfiltN)=vcf_prune($ref_common_variantsfilt,$ref_different_variantsfilt,\%N,\@statsfiltN);

        #my @statsfiltN=(($statsAfiltN[0]+$statsBfiltN[0])/2.0,($statsAfiltN[1]+$statsBfiltN[1])/2.0); ###TODO: I'm calculating the of the % and the number of variants. We may want to get the union or intersection of variants!!!!

		#Substract NAB from Afilt. Compare the results to B wihout filter --> Common variants + % ###We want to apply filter to NAB and remove only variants that are Alternative for N
		my @statsAfiltNAB;
		my ($ref_common_variantsAfiltNAB,$ref_different_variantsAfiltNAB)=vcf_prune($ref_common_variantsAfiltN,$ref_different_variantsAfiltN,\%NAB,\@statsAfiltNAB);

		#Substract NAB from Bfilt. Compare the results to A wihout filter --> Common variants + % ###We want to apply filter to NAB and remove only variants that are Alternative for N
		my @statsBfiltNAB;
		my ($ref_common_variantsBfiltNAB,$ref_different_variantsBfiltNAB)=vcf_prune($ref_common_variantsBfiltN,$ref_different_variantsBfiltN,\%NAB,\@statsBfiltNAB);

		#Mean stats filter NAB		
		my @statsfiltNAB;
        my ($ref_common_variantsfiltNAB,$ref_different_variantsfiltNAB)=vcf_prune($ref_common_variantsfiltN,$ref_different_variantsfiltN,\%NAB,\@statsfiltNAB);
        #my @statsfiltNAB=(($statsAfiltNAB[0]+$statsBfiltNAB[0])/2.0,($statsAfiltNAB[1]+$statsBfiltNAB[1])/2.0); ###TODO: I'm calculating the of the % and the number of variants. We may want to get the union or intersection of variants!!!!
        
        #Output of list of variants and/or intermediate vcf files
        
        if(!$output_vcfs)
        {
            write_variant_list($ref_common_variantsAfilt,"Afilt$sep_param${condition}.list");
            write_variant_list($ref_common_variantsBfilt,"Bfilt$sep_param${condition}.list");
            write_variant_list($ref_common_variantsfilt,"filt$sep_param${condition}.list");
            write_variant_list($ref_common_variantsAfiltN,"AfiltN$sep_param${condition}.list");
            write_variant_list($ref_common_variantsBfiltN,"BfiltN$sep_param${condition}.list");
            write_variant_list($ref_common_variantsfiltN,"filtN$sep_param${condition}.list");
            write_variant_list($ref_common_variantsAfiltNAB,"AfiltNAB$sep_param${condition}.list");
            write_variant_list($ref_common_variantsBfiltNAB,"BfiltNAB$sep_param${condition}.list");
            write_variant_list($ref_common_variantsfiltNAB,"filtNAB$sep_param${condition}.list");
 
        }
        else
        {
            die "This has not been implemented yet!!!\n";
#            write_variant_vcf($ref_common_variantsAfilt,"Afilt$sep_param${condition}.vcf","A.vcf","##Comment for the header");
#            write_variant_vcf($ref_common_variantsBfilt,"Bfilt$sep_param${condition}.vcf","B.vcf","##Comment for the header");
#            write_variant_vcf($ref_common_variantsAfiltN,"AfiltN$sep_param${condition}.vcf","A.vcf","##Comment for the header");
#            write_variant_vcf($ref_common_variantsBfiltN,"BfiltN$sep_param${condition}.vcf","B.vcf","##Comment for the header");
#            write_variant_vcf($ref_common_variantsAfiltNAB,"AfiltNAB$sep_param${condition}.vcf","A.vcf","##Comment for the header");
#            write_variant_vcf($ref_common_variantsBfiltNAB,"BfiltNAB$sep_param${condition}.vcf","B.vcf","##Comment for the header");

        }
         
	    
		#Store and/or print
		my @statistics=(@statsAfilt,@statsBfilt,@statsfilt,@statsAfiltN,@statsBfiltN,@statsfiltN,@statsAfiltNAB,@statsBfiltNAB,@statsfiltNAB);
		$results{$condition}=\@statistics;
		#print("DEBUG:$condition$OFS",array_to_string(@statistics),"\n");
	}

}

## Output
#############################################################
open(my $OFILE,">$output_file");
print($OFILE "Condition,Afilt_prop,Afilt_N,Bfilt_prop,Bfilt_N,filt_prop,filt_N,AfiltN_prop,AfiltN_N,BfiltN_prop,B_filtN_prop,filtN_prop,filtN_N,AfiltNAB_prop,AfiltNAB_N,BfiltNAB_prop,BfiltNAB_N,filtNAB_prop,filtNAB_N\n");
foreach my $condition (keys %results)
{
	print($OFILE "$condition$OFS",array_to_string(@{$results{$condition}}),"\n");
}
close($OFILE);

###################################################################################
###FUNCTIONS
###################################################################################

#Recursive function to generate parameter combinations
#One recursion per parameter
#########################################################
sub combs 
{
	my ($id,$string,$ref_array1,$ref_array2,$ref_array_output)=@_;
	#print("DEBUG: $id,$string,$ref_array1,$ref_array2,$ref_array_output\n");
	if($id<scalar(@{$ref_array1})-1) #If there are more params recurse
	{
		my @values=@{@{$ref_array2}[$id]};
		my $parameter=@{$ref_array1}[$id];
		foreach my $value (@values)
		{
			combs($id+1,"$string$parameter$sep_value${value}$sep_param",$ref_array1,$ref_array2,$ref_array_output);
		}
	}
	else #Store the string in the output array
	{
		my @values=@{@{$ref_array2}[$id]};
                my $parameter=@{$ref_array1}[$id];
                foreach my $value (@values)
                {
                        my $new_string="$string$parameter$sep_value$value";
			push(@{$ref_array_output},$new_string);
		}
	}
}

#Parses parameters file, into an array of parameters
#and a matrix of values per parameter
#####################################################
sub parse_parameters_values
{
	my ($file,$ref_params,$ref_values)=@_;
	open (my $FILE, $file) or die "Error opening the file $file";
	my @content=<$FILE>;
	my $i=0;
	foreach my $line (@content)
	{
		chomp($line);
		my @temp=split($FS,$line);
		push(@{$ref_params},splice(@temp,0,1));
		${$ref_values}[$i]=\@temp;
		++$i;
	}
	close($FILE);
}

#Generates an string concatenating array members with OFS
#####################################################
sub array_to_string
{
	my $outstring="";
	for (my $i=0;$i<scalar(@_);++$i)
	{
		$outstring.="$_[$i]$OFS";
	}
	chop($outstring);
	return $outstring;
}

#Parse vcf
###########################################
sub parse_vcf
{
	my ($vcf1_file)=@_;
	open(my $VCF1,$vcf1_file) or die "The file $vcf1_file is not located in the output folder. Please, check if the variant caller has successfully finished";
	my @vcf1=<$VCF1>;
	close($VCF1);
	my $flag=0;
	my $i;
	my %hash;
	my $key;

	for ($i=0;$i<scalar @vcf1;$i++)
	{
		unless($flag==0 and $vcf1[$i]=~/^#/)
		{
			if ($flag==0)
			{
				$flag=1;
			}
			$key=$vcf1[$i];
			$key=~s/^(.*?)\t(.*?)\t.*/$1$OFS$2/; ####TODO: This may be quicker with a split+join strategy. To check it!
            chomp($key);
			$hash{$key}=1;
			#print("DEBUG: New variant being hashed $key\n");
		}
	}
	return \%hash;

}

#Compare two vcf files and generate statistics
##############################################
sub vcf_compare2
{
	my ($vcf1_file,$vcf2_file,$ref_statistics)=@_;
	
	open(my $VCF1,$vcf1_file) or die "The file $vcf1_file is not located in the output folder. Please, check if the variant caller has successfully finished";
	open(my $VCF2,$vcf2_file) or die "The file $vcf2_file is not located in the output folder. Please, check if the variant caller has successfully finished";
	my @vcf1=<$VCF1>;
	my @vcf2=<$VCF2>;
	close($VCF1);
	close($VCF2);
	clean_vcfcontent(\@vcf1);
	clean_vcfcontent(\@vcf2);
	my %variants1=%{variants_to_hash(\@vcf1)};
	my %variants2=%{variants_to_hash(\@vcf2)};
	my %commonvariants;
	my $n1=scalar(keys %variants1);
	my $n2=scalar(keys %variants2);
	
	if ($n1<$n2) ##This could be improved in terms on speed following the strategy of the next subroutine. I'm not using this one any more, so I won't update it... at least so far.
	{
		foreach my $variant (keys %variants1)
		{
			if (exists $variants2{$variant})
			{
				$commonvariants{$variant}=1;
				#print("DEBUG: New common variant $variant");
			}
		}
	}
	else
	{
		foreach my $variant (keys %variants2)
                {
                        if (exists $variants1{$variant})
                        {
                                $commonvariants{$variant}=1;
				#print("DEBUG: New common variant $variant");
                        }
                }
	}
	@{ $ref_statistics }=($n1,$n2,scalar (keys %commonvariants));
	return \%commonvariants;

}

#Compare two variant hashes, return a hash with commonvariants and another one with variants in the problem
# that aren't present in the reference and generate statistics
##############################################
sub vcf_compare_parsed
{
	my ($vcf_reference,$vcf_problem,$ref_statistics)=@_;
	my %variants2=%{$vcf_problem};
	my %commonvariants;
	my $n1=scalar(keys %{$vcf_reference});
	my $n2=scalar(keys %variants2);
		
    foreach my $variant (keys %{$vcf_reference})
	{
			if (exists $variants2{$variant})
			{
				$commonvariants{$variant}=1;
				delete $variants2{$variant}; ###This is a local copy of the original hash. I cut it down to reduce the number of comparisons.
				#print("DEBUG: New common variant $variant");
			}
			
			if(scalar(keys %variants2)== 0)
			{
				last; ##No more pending comparisons
			}
	}	
    
    if ($n1<$n2)
	{
		print("WARNING: The number of variants in the unfiltered sample is smaller than the one of the filtered\n");		
	}
	
    my $n_common=scalar(keys %commonvariants);
	@{ $ref_statistics }=($n_common/$n2,$n_common); ##Stats= proportion of selected reads in the reference, number of selected variants
	return (\%commonvariants,\%variants2); ##Common, not_in_ref

}

#Filter out variants in one hash from two others and generate statistics
########################################################################
sub vcf_prune
{
	my ($vcf_1,$vcf_2,$vcf_todelete,$ref_statistics)=@_;
	my %variants1=%{$vcf_1};
	my %variants2=%{$vcf_2};
	my $tag1=0;
	my $tag2=0;

	foreach my $variant_to_remove (keys %{$vcf_todelete})
	{
        #print("DEBUG: Variant $variant_to_remove ");
		if ($tag1==0 and exists($variants1{$variant_to_remove}))
		{
			delete($variants1{$variant_to_remove});
            #print("deleted in vcf1");
		}
		if ($tag2==0 and exists($variants2{$variant_to_remove}))
		{
			delete($variants2{$variant_to_remove});
            #print("deleted in vcf2");
		}
		#print("\n");
		if($tag1==0 and scalar(keys %variants1)==0)
		{
			$tag1=1;
            #print("DEBUG: No more variants in vcf1\n");
		}	
		if($tag2==0 and scalar(keys %variants2)==0)
		{
			$tag2=1;
            #print("DEBUG: No more variants in vcf2\n");
		}
		
		if($tag1==1 and $tag2==1)
		{
            #print("DEBUG: No more variants\n");
			last;
		}
		
	}
	my $n_selvariants=scalar keys %variants1;
	my $n_filtvariants=scalar keys %variants2;	
	@{ $ref_statistics }=($n_selvariants/($n_selvariants+$n_filtvariants),$n_selvariants); ##Stats= proportion of selected reads in the reference, number of selected variants
	return (\%variants1,\%variants2);
}

#Combine the variants of two samples. Calculate the union of the two samples
#(union of the commons and union of the differences) and remove spurious
#differences (that can potentially appear in the union).Then calculate the stats.
########################################################################
sub vcf_unite_parsed
{
    my ($ref_common_variantsA,$ref_different_variantsA,$ref_common_variantsB,$ref_different_variantsB,$ref_statistics)=@_;
    my %common_variants=(%{$ref_common_variantsA},%{$ref_common_variantsB}); ##Union
    my %different_variants=(%{$ref_different_variantsA},%{$ref_different_variantsB});#Union

    foreach my $common_variant (keys %common_variants) ##We have to delete possible variants that are not different any more
    {
        delete($different_variants{$common_variant}); 
    }
    
    my $n_selvariants=scalar keys %common_variants;
    my $n_filtvariants=scalar keys %different_variants;
    @{ $ref_statistics }=($n_selvariants/($n_selvariants+$n_filtvariants),$n_selvariants); ##Stats= proportion of selected reads in the reference, number of selected variants
    return (\%common_variants,\%different_variants);
}

#Removes the VCF header
##############################################
sub clean_vcfcontent
{
	my ($array)=@_;
	my @array;
	my $last_comment=0;
	for (my $i=0;$i<scalar @{$array};$i++)
	{
		if(${$array}[$i]=~/^##/)
		{
			++$last_comment;
		}
		else
		{
			last;
		}
	}
	splice(@{ $array },0,$last_comment);
}

# Generates a hash of variants from an array with the content of a VCF without the header
#########################################################################################
sub variants_to_hash
{
	my ($array)=@_;
	my %hash;
	my $key;
	for (my $i=1; $i<scalar @{$array};$i++) ###The first line is the header
	{
		$key=${$array}[$i];
		$key=~s/^(.*?)\t(.*?)\t.*/$1$OFS$2/; ####TODO: This may be quicker with a split+join strategy. To check it!
		$hash{$key}=1;
		#print("DEBUG: New variant being hashed $key\n");
	}
	return \%hash;
}

# Writes a list of variants in csv format contained in a hash
# ############################################################
sub write_variant_list
{
    my ($ref_hash,$filename)=@_;
    open(my $FILE, ">$filename");
    print($FILE "#CHROM,POS\n");
    foreach my $variant (keys %{$ref_hash})
    {
        print($FILE join($OFS,split(",",$variant)),"\n");
    }
    close $FILE;
}

# Writes a vcf with the variables contained in a hash selected from another VCF file
# ##################################################################################
sub write_variant_vcf
{
    my ($ref_hash,$filename,$vcf,$comment)=@_;
    open(my $FILE, ">$filename");


    ##Pseudocode:
    #open the vcf
    #print the same header ???(We could add here a line with the information of the filter done by this script!!!!)
    #print the name of the columns
    #foreach line of the vcf
    #   get the variant id
    #   look for it in the ref_hash
    #   if it is there, print this line and remove this variant from the hash of filtered variants
    #   otherwise, don't do anything 
    #   last if there is no more filtered variants


#    print($FILE "#CHROM,POS\n");
#    foreach my $variant (keys %{$ref_hash})
#    {
#        print($FILE join($OFS,split(",",$variant)),"\n");
#    }
    close $FILE;
}
