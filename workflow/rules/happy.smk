rule happy_run:
    """
    Use Illumina's hap.py to compare "gold standard" vcf to experimental calls.

    hap.py is a chunky memory hog. Nevertheless, it does do exactly what you want it
    to, after a fashion.
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
        vcf="results/happy/{experimental}/{reference}/{region_set}/results.vcf.gz",
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


rule happy_combine_results:
    """
    Combine results from Illumina's hap.py utility run against different sets of stratification regions.
    """
    input:
        lambda wildcards: expand(
            "results/happy/{{experimental}}/{{reference}}/{region_set}/results.vcf.gz",
            region_set=tc.get_happy_region_set_indices(wildcards, config, checkpoints),
        ),
    output:
        "results/happy/{experimental}/{reference}/results.vcf.gz",
    benchmark:
        "results/performance_benchmarks/happy_combine_results/{experimental}/{reference}/results.tsv"
    conda:
        "../envs/bcftools.yaml"
    threads: 2
    resources:
        qname="small",
        mem_mb="4000",
    shell:
        "touch {output}"
