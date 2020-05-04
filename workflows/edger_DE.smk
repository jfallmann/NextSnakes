DEBIN, DEENV = env_bin_from_config3(config,'DE')
COUNTBIN, COUNTENV = ['featureCounts','countreads']#env_bin_from_config2(SAMPLES,config,'COUNTING')

outdir="DE/EDGER/"
comparison=comparable_as_string2(config,'DE')

rule themall:
    input:  all = expand("{outdir}All_Conditions_MDS.png", outdir=outdir),
            tbl = expand("{outdir}All_Conditions_normalized_table.tsv", outdir=outdir),
            bcv = expand("{outdir}All_Conditions_BCV.png", outdir=outdir),
            qld = expand("{outdir}All_Conditions_QLDisp.png", outdir=outdir),
            dift = expand("{outdir}{comparison}_genes_{sort}.tsv", outdir=outdir, comparison=[i.split(":")[0] for i in comparison.split(",")], sort=["logFC-sorted","pValue-sorted"]),
            plot = expand("{outdir}{comparison}_MD.png", outdir=outdir, comparison=[i.split(":")[0] for i in comparison.split(",")]),
            session = expand("{outdir}EDGER_DAS_SESSION.gz", outdir=outdir)

rule featurecount_unique:
    input:  reads = "UNIQUE_MAPPED/{file}_mapped_sorted_unique.bam"
    output: cts   = "COUNTS/Featurecounts_DE_edger/{file}_mapped_sorted_unique.counts"
    log:    "LOGS/{file}/featurecounts_DE_edger_unique.log"
    conda:  "snakes/envs/"+COUNTENV+".yaml"
    threads: MAXTHREAD
    params: count = COUNTBIN,
            anno  = lambda wildcards: str.join(os.sep,[config["REFERENCE"],os.path.dirname(genomepath(wildcards.file, config)),tool_params(wildcards.file, None, config, 'DE')['ANNOTATION']]),
            cpara = lambda wildcards: ' '.join("{!s} {!s}".format(key,val) for (key,val) in tool_params(wildcards.file, None ,config, "DE")['OPTIONS'][0].items()),
            paired   = lambda x: '-p' if paired == 'paired' else '',
            stranded = lambda x: '-s 1' if stranded == 'fr' else '-s 2' if stranded == 'rf' else ''
    shell:  "{params.count} -T {threads} {params.cpara} {params.paired} {params.stranded} -a <(zcat {params.anno}) -o {output.cts} {input.reads} 2> {log}"

rule prepare_count_table:
    input:   cnd  = expand(rules.featurecount_unique.output.cts, file=samplecond(SAMPLES,config))
    output:  tbl  = "DE/EDGER/Tables/COUNTS.gz",
             anno = "DE/EDGER/Tables/ANNOTATION.gz"
    log:     expand("LOGS/{outdir}prepare_count_table.log",outdir=outdir)
    conda:   "snakes/envs/"+DEENV+".yaml"
    threads: 1
    params:  dereps = lambda wildcards, input: get_reps(input.cnd,config,'DE'),
             bins = BINS
    shell: "{params.bins}/Analysis/build_count_table_simple.py {params.dereps} --table {output.tbl} --anno {output.anno} --loglevel DEBUG 2> {log}"

rule run_edger:
    input:  tbl = rules.prepare_count_table.output.tbl,
            anno = rules.prepare_count_table.output.anno,
    output: rules.themall.input.all,
            rules.themall.input.tbl,
            rules.themall.input.bcv,
            rules.themall.input.qld,
            rules.themall.input.dift,
            rules.themall.input.plot,
            rules.themall.input.session
    log:    expand("LOGS/{outdir}run_edger.log",outdir=outdir)
    conda:  "snakes/envs/"+DEENV+".yaml"
    threads: int(MAXTHREAD-1) if int(MAXTHREAD-1) >= 1 else 1
    params: bins   = str.join(os.sep,[BINS,DEBIN]),
            outdir = outdir,
            compare = comparison
    shell: "Rscript --no-environ --no-restore --no-save {params.bins} {input.anno} {input.tbl} {params.outdir} {params.compare} {threads} 2> {log} "
