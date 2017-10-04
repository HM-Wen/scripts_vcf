#!/bin/bash

usage="\n$0 directory torun_file n_cores\n\ntorun_file structure: output N_file A_file B_file\n-------------------------------------------------\n
\n
This script estimates the cnv heterogeneity of pairs of cancer samples (A,B) and normal (N), for each sample in a directory with its name. Then it integrates all the information in a file named results.csv and results_basictstv.csv\n"

if [[ $# -ne 3 ]] || [[ ! -d $1 ]] || [[ ! -f $2 ]]
then
    echo -e $usage
    exit
else
    dir=$(readlink -f $1)
    torun=$(readlink -f $2)
    n_cores=$3
fi

EXE_DIR=$SCRIPTSVCF_DIR

dependency=""
while read -r output normal a b
do
    privdependency=""
    outdir=$dir/$output
    mkdir $outdir

    #how not to do the same task 3 times explained by me...    
    Nid=$(sbatch -p private --job-name=${output}_pileupN $EXE_DIR/generatepileups.sh $outdir/n.pileup.gz $normal | sed "s/Submitted batch job \(.*\)/\1/")
   
    ida=$(sbatch -p private --job-name=${output}_pileupA $EXE_DIR/generatepileups.sh $outdir/a.pileup.gz $a | sed "s/Submitted batch job \(.*\)/\1/")
    ida=$(sbatch -p private --job-name=${output}_prepSequenzaA --dependency=afterok${Nid}:${ida} $EXE_DIR/preprocess_sequenza.sh $outdir/a.pileup.gz $outdir/n.pileup.gz $outdir an | sed "s/Submitted batch job \(.*\)/\1/")
    privdependency="${privdependency}:${ida}"
    
    idb=$(sbatch -p private --job-name=${output}_pileupB $EXE_DIR/generatepileups.sh $outdir/b.pileup.gz $b | sed "s/Submitted batch job \(.*\)/\1/")
    idb=$(sbatch -p private --job-name=${output}_prepSequenzaB --dependency=afterok:${Nid}:${idb} $EXE_DIR/preprocess_sequenza.sh $outdir/b.pileup.gz $outdir/n.pileup.gz $outdir bn | sed "s/Submitted batch job \(.*\)/\1/")
    privdependency="${privdependency}:${idb}"
   
    ida=$(sbatch -p private -c $n_cores --job-name=${output}_SequenzaA --dependency=afterok:${ida} $EXE_DIR/sequenza.sh $outdir/an.seqz.gz $outdir | sed "s/Submitted batch job \(.*\)/\1/")
    dependency="${dependency}:${ida}" 
    idb=$(sbatch -p private -c $n_cores --job-name=${output}_SequenzaB --dependency=afterok:${idb} $EXE_DIR/sequenza.sh $outdir/bn.seqz.gz $outdir | sed "s/Submitted batch job \(.*\)/\1/")
    dependency="${dependency}:${idb}"

    #id=$(sbatch -p private --job-name=${output}_HetAn <( echo -e '#!/bin/bash'"\n $EXE_DIR/HeterAnalyzer_control.pl -e $exe_params -f $filtering_params --NABfilt_cond_inputfile $NAB_params --NABfilt_cond_inputfile2 $NAB2_params --covaltB_cond_inputfile $covB_params -o $dir/${output}.csv --normal_bamfile $normal --sample_A_bamfile $a --sample_B_bamfile $b --output_dir $dir/$output --n_cores $n_cores > $dir/${output}.out") | sed "s/Submitted batch job \(.*\)/\1/")
    #dependency="${dependency}:${id}"
done < $torun

#sbatch -p private --job-name=getdependencies --dependency=afterok$dependency <(echo -e '#!/bin/bash' "\ndependency=\"\";while read -r output normal a b;do id=\$(tail -n 1 $dir/\${output}.out);dependency=\"\$dependency:\$id\";done < $torun;sbatch -p private --dependency=afterok\$dependency $EXE_DIR/postHeterAnalyzer.sh $dir $torun $exe_params $filtering_params $NAB_params $NAB2_params $covB_params $n_cores")
