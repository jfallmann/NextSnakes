TRIMENV=params.TRIMMINGENV ?: null
TRIMBIN=params.TRIMMINGBIN ?: null

TRIMPARAMS = params.trimgalore_params_0 ?: ''

//PROCESSES
process trim{
    conda "${workflow.workDir}/../nextsnakes/envs/$TRIMENV"+".yaml"
    cpus THREADS
    validExitStatus 0,1

    publishDir "${workflow.workDir}/../" , mode: 'copy',
    saveAs: {filename ->
        if (filename.indexOf(".fq.gz") > 0)      "TRIMMED_FASTQ/$CONDITION/${file(filename).getSimpleName().replaceAll(/_val_\d{1}|_trimmed/,"")}_trimmed.fastq.gz"
        else if (filename.indexOf("report.txt") >0)     "TRIMMED_FASTQ/$CONDITION/${file(filename).getSimpleName()}_trimming_report.txt"
        else null
    }

    input:
    path reads

    output:
    path "*{val,trimmed}*.fq.gz", emit: trimmed
    path "*trimming_report.txt", emit: report

    script:
    if (PAIRED == 'paired'){
        """
        $TRIMBIN --cores $THREADS --paired --gzip $TRIMPARAMS $reads
        """
    }
    else{
        """
        $TRIMBIN --cores $THREADS --gzip $TRIMPARAMS $reads
        """
    }
}

workflow TRIMMING{
    take: samples_ch

    main:

    //SAMPLE CHANNELS
    if (PAIRED == 'paired'){
        R1SAMPLES = SAMPLES.collect{
            element -> return "${workflow.workDir}/../FASTQ/"+element+"_R1.fastq.gz"
        }
        R1SAMPLES.sort()
        R2SAMPLES = SAMPLES.collect{
            element -> return "${workflow.workDir}/../FASTQ/"+element+"_R2.fastq.gz"
        }
        R2SAMPLES.sort()
        samples_ch = Channel.fromPath(R1SAMPLES).merge(Channel.fromPath(R2SAMPLES))
    }else{
        RSAMPLES=SAMPLES.collect{
            element -> return "${workflow.workDir}/../FASTQ/"+element+".fastq.gz"
        }
        RSAMPLES.sort()
        samples_ch = Channel.fromPath(RSAMPLES)
    }

    trim(samples_ch)

    emit:

    trimmed = trim.out.trimmed
    report  = trim.out.report
}