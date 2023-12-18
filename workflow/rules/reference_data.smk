checkpoint get_stratification_files:
    """
    Get directory of NIST/Zook stratification regions.

    The idea here is: there is a set type of ftp directory that contains a top level set
    of annotations and a bunch of subdirectories with compressed bedfiles containing stratification regions.
    The bedfiles need to be downloaded, and then the top-level file linking between a pretty(ish) name and
    the relative path to the bedfile needs to be placed in a place that Snakemake can see it.

    To reduce the burden of ftp pulls, and to deal with uncertain logic concerning which files
    need to be present when in the DAG, this command is split into two parts in the same checkpoint.
    In the first, the linker is pulled by itself. The linker is then parsed on the fly to create
    a subset of files to pull in the second lftp command. This should substantially reduce
    the number of transferred files in most cases.
    """
    input:
        trackers=lambda wildcards: ctf.get_ftp_tracking_files(config, "results"),
    output:
        tsv="results/stratification-sets/{genome_build}/stratification_regions.tsv",
        query=temp("results/stratification-sets/{genome_build}/stratification_regions_query.tsv"),
    params:
        outdir="results/stratification-sets/{genome_build}",
        ftpsite=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["ftp"],
        ftpdir=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["dir"],
        linker_fn=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["all-stratifications"],
        config_query=lambda wildcards: "|".join(
            [
                "^{}".format(x["name"])
                for x in filter(
                    lambda y: y["name"] != "*",
                    config["genomes"][wildcards.genome_build]["stratification-regions"][
                "region-definitions"
                    ],
                )
            ]
        ),
    benchmark:
        "results/performance_benchmarks/get_stratification_files/{genome_build}/results.tsv"
    conda:
        "../envs/lftp.yaml"
    priority: 1
    threads: 1
    resources:
        qname="small",
        mem_mb=2000,
    shell:
        "mkdir -p {params.outdir} && "
        "lftp -c 'set ftp:list-options -a; "
        'open "anonymous:@{params.ftpsite}"; '
        "mirror --verbose -p --include {params.linker_fn} {params.ftpdir} {params.outdir}' && "
        "mv {params.outdir}/{params.linker_fn} {output.tsv} && "
        "grep -E \"{params.config_query}\" {output.tsv} | cut -f2 | sed 's/\\r//g' > {output.query} && "
        "lftp -c 'set ftp:list-options -a; "
        'open "anonymous:@{params.ftpsite}"; '
        "mirror --verbose -p --include-rx-from={output.query} {params.ftpdir} {params.outdir}' && "
        "find {params.outdir} -type d -empty -delete"


rule acquire_confident_regions:
    """
    Get a confident region bedfile from somewhere
    """
    output:
        final="results/confident-regions/{region}.bed",
        tmp=temp("results/confident-regions/.{region}.bed.tmp"),
    params:
        source=lambda wildcards: config["genomes"][reference_build]["confident-regions"][
            wildcards.region
        ]["bed"],
    threads: 1
    resources:
        qname="small",
        mem_mb=2000,
    shell:
        "if [[ {params.source} = s3://* ]] ; then "
        "aws s3 cp {input} {output.tmp} ; "
        "elif [[ {params.source} = ftp://* ]] || [[ {params.source} = https://* ]] || [[ {params.source} = http://* ]] ; then "
        "wget -O {output.tmp} {params.source} ; "
        "else cp {params.source} {output.tmp} ; fi && "
        'if [[ "{params.source}" = *".gz" ]] ; then gunzip -c {output.tmp} > {output.final} ; else cp {output.tmp} {output.final} ; fi'


use rule acquire_confident_regions as acquire_fasta with:
    output:
        final="results/{genome}/ref.fasta",
        tmp=temp("results/{genome}/.ref.fasta.tmp"),
    params:
        source=lambda wildcards: config["genomes"][wildcards.genome]["fasta"],


rule create_fai:
    """
    From a fasta file, create an fai index
    """
    input:
        "{prefix}.fasta",
    output:
        "{prefix}.fasta.fai",
    benchmark:
        "results/performance_benchmarks/create_fai/{prefix}.fasta.fai.tsv"
    conda:
        "../envs/samtools.yaml"
    threads: 1
    resources:
        mem_mb=4000,
        qname="small",
    shell:
        "samtools faidx {input}"


rule create_sdf:
    """
    Convert a fasta to an sdf format *folder* for rtg tools' particularities
    """
    input:
        "results/{genome}/ref.fasta",
    output:
        directory("results/{genome}/ref.fasta.sdf"),
    benchmark:
        "results/performance_benchmarks/create_sdf/{genome}.tsv"
    conda:
        "../envs/vcfeval.yaml"
    threads: 1
    resources:
        qname="small",
        mem_mb=16000,
    shell:
        "rtg RTG_MEM=12G format -f fasta -o {output} {input}"
