rule happy_run:
    """
    Use Illumina's hap.py to compare "gold standard" vcf to experimental calls.

    hap.py is a chunky memory hog. Nevertheless, it does do exactly what you want it
    to, after a fashion.

    Eventually, most of these output files will be temp() or merged into single outputs.
    """
    input:
        experimental="results/experimentals/{experimental}.vcf.gz",
        reference="results/references/{reference}.vcf.gz",
        fa="results/{}/ref.fasta".format(reference_build),
        fai="results/{}/ref.fasta.fai".format(reference_build),
        sdf="results/{}/ref.fasta.sdf".format(reference_build),
        bed=lambda wildcards: tc.get_happy_region_by_index(wildcards, config, checkpoints),
        rtg_wrapper="workflow/scripts/rtg.bash",
    output:
        expand(
            "results/happy/{{experimental}}/{{reference}}/{{region_set}}/results.{suffix}",
            suffix=[
                "extended.csv",
                "metrics.json.gz",
                "roc.all.csv.gz",
                "roc.Locations.INDEL.csv.gz",
                "roc.Locations.INDEL.PASS.csv.gz",
                "roc.Locations.SNP.csv.gz",
                "roc.Locations.SNP.PASS.csv.gz",
                "runinfo.json",
                "summary.csv",
                "vcf.gz",
                "vcf.gz.tbi",
            ],
        ),
    params:
        outprefix="results/happy/{experimental}/{reference}/{region_set}/results",
        tmpdir="temp/happy/{experimental}/{reference}/{region_set}",
    benchmark:
        "results/performance_benchmarks/happy_run/{experimental}/{reference}/{region_set}/results.tsv"
    conda:
        "../envs/happy.yaml"
    threads: 4
    resources:
        qname="small",
        mem_mb="64000",
        tmpdir=lambda wildcards: "temp/happy/{}/{}/{}".format(
            wildcards.experimental, wildcards.reference, wildcards.region_set
        ),
    shell:
        "mkdir -p {params.tmpdir} && "
        "RTG_MEM=12G HGREF={input.fa} hap.py {input.reference} {input.experimental} -f {input.bed} -o {params.outprefix} "
        "-V --engine=vcfeval --engine-vcfeval-path={input.rtg_wrapper} --engine-vcfeval-template={input.sdf} "
        "--threads {threads} --scratch-prefix {params.tmpdir}"


localrules:
    happy_add_region_name,
    happy_combine_results,


rule happy_add_region_name:
    """
    To prepare for merging files from separate regions, prefix the lines
    with the name of the region.
    """
    input:
        "results/happy/{experimental}/{reference}/{region_set}/results.summary.csv",
    output:
        temp("results/happy/{experimental}/{reference}/{region_set}/results.summary.annotated.csv"),
    params:
        name=lambda wildcards: tc.get_happy_region_name_by_index(wildcards, config, checkpoints),
    threads: 1
    shell:
        "cat {input} | "
        "awk -v prefix={params.name} -v ex={wildcards.experimental} -v ref={wildcards.reference} "
        '\'NR == 1 {{print "Experimental,Reference,Region,"$0}} ; NR > 1 {{print ex","ref","prefix","$0}}\' > {output}'


rule happy_combine_results:
    """
    Combine annotated summary results from Illumina's hap.py utility run against different sets of stratification regions.
    """
    input:
        lambda wildcards: expand(
            "results/happy/{{experimental}}/{{reference}}/{region_set}/results.summary.annotated.csv",
            region_set=tc.get_happy_region_set_indices(wildcards, config, checkpoints),
        ),
    output:
        "results/happy/{experimental}/{reference}/results.summary.csv",
    benchmark:
        "results/performance_benchmarks/happy_combine_results/{experimental}/{reference}/results.tsv"
    conda:
        "../envs/bcftools.yaml"
    threads: 1
    shell:
        "cat {input} | awk 'NR == 1 || ! /^Experimental,Reference,Region,Type,Filter,TRUTH.TOTAL/' > {output}"
