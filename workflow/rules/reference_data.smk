checkpoint get_stratification_bedfiles:
    """
    Get remote directory of NIST/Zook stratification regions.

    The idea here is: there is a set type of ftp directory that contains a top level set
    of annotations and a bunch of subdirectories with compressed bedfiles containing stratification regions.
    The bedfiles need to be downloaded, and then the top-level file linking between a pretty(ish) name and
    the relative path to the bedfile needs to be placed in a place that Snakemake can see it.
    """
    output:
        "results/regions/{genome_build}/stratification_regions.tsv",
    params:
        outdir="results/regions/{genome_build}",
        ftpsite=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["ftp"],
        ftpdir=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["dir"],
    benchmark:
        "results/performance_benchmarks/get_stratification_bedfiles/{genome_build}/results.tsv"
    conda:
        "../envs/lftp.yaml"
    threads: 1
    resources:
        qname="small",
        mem_mb="2000",
    shell:
        "mkdir -p {params.outdir} && "
        "lftp -c 'set ftp:list-options -a; "
        'open "anonymous:@{params.ftpsite}"; '
        "mirror --verbose -p --exclude-glob .DS_Store {params.ftpdir} {params.outdir}' && "
        'find {params.outdir} -maxdepth 1 -name "*-all-stratifications.tsv" -exec '
        "cp {{}} {output} \\;"


rule acquire_fasta:
    """
    Get a reference genome fasta from a remote source
    """
    input:
        lambda wildcards: tc.wrap_remote_file(config["genomes"][wildcards.genome]["fasta"]),
    output:
        "results/{genome}/ref.fasta",
    threads: 1
    resources:
        qname="small",
        mem_mb="2000",
    shell:
        "cp {input} {output}"


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
        mem_mb="4000",
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
        mem_mb="16000",
    shell:
        "rtg RTG_MEM=12G format -f fasta -o {output} {input}"
