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
        sdf="results/{}/ref.fasta.sdf".format(reference_build),
        bed=lambda wildcards: tc.get_happy_region_by_index(wildcards, config, checkpoints),
    output:
        vcf="results/happy/{experimental}/{reference}/{region_set}/results.vcf.gz",
    params:
        outprefix="results/happy/{experimental}/{reference}/region_set}/results",
    benchmark:
        "results/performance_benchmarks/happy_run/{experimental}/{reference}/{region_set}/results.tsv"
    conda:
        "../envs/happy.yaml"
    threads: 8
    resources:
        qname="small",
        mem_mb="16000",
    shell:
        "hap.py {input.reference} {input.experimental} -f {input.bed} -r {input.fa} -o {params.outprefix} "
        "-V --engine=vcfeval --engine-vcfeval-template={input.fa}"


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
