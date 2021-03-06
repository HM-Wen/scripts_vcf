#!/bin/bash
#SBATCH -t 4-00:00
#SBATCH --mem 64000

module load perl/5.22.1
module load parallel/20140822

args=($@)
n_cores_arg=$(( $#-1 ))
n_cores=${args[$n_cores_arg]}
dir=$PWD

if [[ $# -ne 1 ]]
then
    echo "Variant analysis"
    perl $@
    dir=${args[2]}
else
    echo "Skipping the analysis of variants, directly executing annovar"
fi

#I have to get the number of cores from the arguments in $@ instead of from SLURM_JOB_CPUS_PER_NODE since if I increase the required memory I get more nodes that the ones I ask for!!!!!

cd $dir

if [[ -x $SCRIPTSVCF_DIR/annovar.sh ]]
then

    files=$(ls *.vcf | egrep '^.*filt.*')
    parallel --delay "0.2" -j $n_cores "echo \"Annotating {1}\"; $SCRIPTSVCF_DIR/annovar.sh {1}" ::: $files

#	for i in filt*.vcf
#	do
#		#sem -j$SLURM_JOB_CPUS_PER_NODE echo "Annotating $i" ";" $ordir/annovar.sh $i
#        echo "Anotating $i\n"
#        $ordir/annovar.sh $i
#	done
#	#sem --wait
else
	echo "Error finding the executable annovar.sh. Please, make sure that the environment variable SCRIPTSVCF_DIR is indicating the folder with this package of scripts"
	exit
fi
